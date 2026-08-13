# Índices contra planos reais

14 de Agosto de 2026. O último ponto de «Por verificar — nunca foram olhados» da
auditoria de 11/8. Até aqui os índices tinham sido escritos a olhar para as
consultas; isto é o que o `explain (analyze, buffers)` diz com os 26 meses
semeados lá dentro.

**Medido como a app corre, não como o `postgres` corre.** Cada plano foi tirado
duas vezes: uma como dono da base, outra dentro de `set local role authenticated`
com as claims de um utilizador real. Os dois não se parecem, e o segundo é o que
conta — ver [[feedback_testar-o-pedido-nao-so-a-resposta]].

---

## Primeiro, uma coisa que eu não sabia

**Oito das «tabelas» de projecção são vistas.** `punho_clientes`,
`punho_recebimentos`, `punho_despesas`, `punho_maquinas`, `punho_leads`,
`punho_colaboradores`, `punho_veiculos` e `punho_cobrancas` são views sobre o
`punho_operacoes`, montadas com `row_number()` para ficar com a última versão de
cada entidade. Tabelas a sério, só `punho_reservas` e `punho_reserva_maquinas`.

Isso muda onde o problema pode estar: não há oito conjuntos de índices para
afinar, há **um** — o `punho_operacoes_projeccao_idx (entidade, empresa_id,
entidade_id, seq DESC)`, que é quem sustenta as oito. E está a ser usado (5 376
varrimentos registados, o mais usado de todo o esquema).

## Os dois caminhos quentes

| Consulta | Plano | Tempo | Buffers |
| --- | --- | --- | --- |
| Sync: `empresa_id = ? and seq > ? order by seq limit 500` | `Index Scan` em `punho_operacoes_por_empresa` | 9,3 ms | 968 |
| Vista: `punho_recebimentos where empresa_id = ?` (768 linhas) | `Index Scan` em `punho_operacoes_projeccao_idx` | 23,9 ms | 1 135 |
| Reservas do mês + máquinas (19 linhas) | `Index Scan` em `punho_reservas_empresa_fim_idx` + `Index Only Scan` na pkey | 13,4 ms | 187 |

**Nenhuma consulta cai em `Seq Scan`. Nenhum índice em falta.** O `.order('seq')`
e o `.gt('seq', cursor)` do `sincronizacao_entre_dispositivos.dart` batem
exactamente com `(empresa_id, seq)` — a condição inteira entra no `Index Cond`,
sem sobrar filtro nenhum.

## O que o RLS custa, que não aparece na consulta

O mesmo pedido, com e sem política:

| | sem RLS | com RLS |
| --- | --- | --- |
| Sync, 500 linhas | 354 buffers | **968** |
| Vista de recebimentos, 768 linhas | 248 buffers | **1 135** |

A diferença é `punho_perfil_na_empresa(empresa_id)` a ser chamada **uma vez por
linha**. É uma função `stable` sobre `punho_membros`, com índice — cada chamada
custa cerca de um buffer e meio. Multiplicado pelas linhas, dá 3 a 4,5 vezes a
leitura.

Não se corrige com um índice, e por isso fica aqui escrito em vez de mexido: o
que a tiraria do caminho é reescrever a política para `empresa_id in (select
...)`, que o planeador avalia uma vez em vez de por linha. **Isso é mexer numa
política de segurança**, e as políticas destas tabelas foram feitas à mão na
Fase 2 do hardening. Não se troca uma coisa provada por uma mais rápida sem ele
mandar.

O mesmo padrão, mais caro, no `punho_reserva_maquinas`: a política dele faz um
`EXISTS` que **volta a ler a `punho_reservas`** por cada linha — 95 buffers para
19 linhas, a reler reservas que o `join` já tinha trazido.

## O tecto que ninguém vê, e que não é dele

Nenhuma consulta ao `punho_operacoes` consegue ir a paralelo. Provado, não
suposto: com `parallel_setup_cost = 0` e o custo de tuplo a zero — paralelismo à
borla —, o plano como `postgres` abre `Gather` com dois workers, e o plano como
`authenticated` fica em `Seq Scan` serial.

A causa é a função do RLS ser `PARALLEL UNSAFE`. E a razão de ela o ser é que
chama a **`auth.uid()`, que a própria Supabase marca como `PARALLEL UNSAFE`**.

Marcar a `punho_perfil_na_empresa` como segura destravava o planeador — e seria
mentir-lhe, porque ela chama uma função declarada insegura. A etiqueta certa
está do lado da Supabase, não do nosso.

**Hoje isto não custa nada**: a tabela tem 2 244 linhas e nunca ia a paralelo de
qualquer maneira. Fica escrito porque é um tecto que chega calado — quando o log
crescer, os relatórios que hoje demoram 20 ms não vão poder usar mais do que um
núcleo, e nada no plano vai dizer porquê.

## O que se fez

**Um índice largado**, e só um: `punho_alteracoes_contabilista_empresa_idx` era
o mesmo índice que o `..._por_empresa` — `btree (empresa_id, alterado_em DESC)`
nos dois. Foi o único duplicado exacto em todo o esquema `punho_*`, procurado
por `indkey`/`indisunique`/`indpred` e não por parecença de nome. Migração
`largar_indice_duplicado_alteracoes_contabilista`.

## O que fica escrito e não se mexeu

**`punho_reservas_empresa_estado_idx` é redundante** — `(empresa_id, estado)` é
prefixo do `punho_reservas_janela_idx (empresa_id, estado, inicio, fim)`, e
qualquer consulta que use um pode usar o outro. Não se largou porque tem 264
usos registados e o que se pouparia são 40 kB de escrita numa tabela de 841
linhas. Largar um índice usado para poupar 40 kB é trocar uma certeza por nada.

**Um utilizador só pode pertencer a uma empresa.** O
`punho_membros_user_empresa_unico` é `UNIQUE (user_id)` sem `where` — não é
`(empresa_id, user_id)`, é o `user_id` sozinho. É por isso que a segunda empresa
de ensaio precisou de um email com `+punhoteste`: o mesmo email a entrar noutra
empresa esbarra numa violação de unicidade, e a app não tem frase nenhuma para
isso. Não é um problema de índice, é uma regra de negócio escondida dentro de
um. Se algum dia um contabilista, um gestor de duas casas ou ele próprio
precisar das duas, é aqui que rebenta.
