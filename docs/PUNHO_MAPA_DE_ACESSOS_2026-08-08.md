# Mapa de acessos — as tabelas partilhadas com o WashInvoice

Levantamento de 8 de Agosto de 2026, contra `oefqbkhioncakojipqyx`. Serve para
decidir a Tarefa 2 do plano de hardening **antes** de se escrever SQL nenhum.

Nada aqui foi alterado. As provas de escrita correram todas dentro de
transacções terminadas em `rollback`.

---

## Quem existe, ao todo

O projecto inteiro tem **quatro contas**:

| contas | app declarada | já entraram | admin |
|---|---|---|---|
| 3 | `punho` | 3 | 0 |
| 1 | (nenhuma) — `cesarmendes78@gmail.com` | 1 | **1** |

Não há **nenhuma** conta do POS. Isto é o facto central deste documento e
está explicado em «O que não pode partir», mais abaixo.

`is_admin()` é `select exists (select 1 from admins where user_id = auth.uid())`
e tem exactamente uma linha: tu.

---

## O que um colaborador do Punho consegue hoje

Encarnado um membro activo com perfil **`colaborador`** — não gestor, o perfil
mais baixo que existe — dentro do Postgres:

| tabela | o que ele vê | o que ele faz |
|---|---|---|
| `clientes` | **4 linhas**, com NIF e nome real de empresas clientes do WashInvoice | **UPDATE passou nas 4** |
| `pings` | 115 linhas, 4 terminais, **76 com IP público, 90 com GPS** | — |
| `aceites_termos` | 12 linhas (machine_id, NIF, IP, cidade) | — |
| `licencas_audit` | 78 linhas | — |
| `pedidos_renovacao` | 0 linhas (tabela vazia, política aberta na mesma) | — |
| `licencas` | **0 linhas** | — |

Duas notas sobre esta tabela, porque a leitura ingénua engana:

**O `DELETE` em `clientes` foi recusado com `23503`, que é violação de chave
estrangeira — não é falta de permissão.** A RLS deixou apagar; foi a
integridade referencial que travou. Tire-se a referência e o colaborador apaga
a carteira de clientes.

**`licencas` a zero é a contraprova de que isto se sabe fazer.** Foi fechada em
21 de Julho (`fechar_rls_licencas_final`) e é a única do grupo que resiste. As
outras ficaram para trás.

---

## Tabela a tabela

### `clientes` — NIF, nome, email, telemóvel, localidade
```
all_clientes [ALL -> public] using (auth.role() = 'authenticated') check (—)
```
`FOR ALL` sem `with_check`: quando o `with_check` é nulo o Postgres usa o
`using` também para escrever. Qualquer autenticado lê, insere e altera tudo.

**Quem a usa mesmo:** só o **Control**, em
`lib/repositories/clientes_repository.dart` (lê, insere, actualiza). O Punho
não lhe toca — a ocorrência que aparecia numa busca é a palavra «clientes»
como etiqueta de ecrã em `procura_slide.dart`. Não há caminho anónimo.

**Devia ser:** leitura e escrita só com `is_admin()`.

### `pings` — machine_id, NIF, IP público, GPS, cidade, versão
```
insert_pings [INSERT -> public] check (true)
select_pings [SELECT -> public] using (auth.role() = 'authenticated')
```
**Quem a usa mesmo:** o **Punho escreve** (`lib/core/telemetria/pings.dart`) e
o **POS escreve** — os dois sem sessão iniciada, e é por isso que o `INSERT`
está aberto ao anónimo. O **Control lê** (`pings_repository.dart`).

**Devia ser:** `INSERT` fica como está — tirá-lo cega a telemetria dos
terminais, que não fazem login. Leitura só com `is_admin()`.

### `pedidos_renovacao`
```
insert_pedidos [INSERT -> public] check (true)
select_pedidos [SELECT -> public] using (auth.role() = 'authenticated')
update_pedidos [UPDATE -> public] using (auth.role() = 'authenticated')
```
**Quem a usa mesmo:** só o Control (`pedidos_repository.dart`). O `INSERT`
anónimo é o terminal a pedir renovação sem sessão.

**Devia ser:** `INSERT` fica; leitura e `UPDATE` só com `is_admin()`. O
`UPDATE` é o que decide se um pedido foi atendido — hoje qualquer colaborador
do Punho o marca como tratado.

### `aceites_termos`
```
insert_termos [INSERT -> public] check (true)
select_termos [SELECT -> public] using (auth.role() = 'authenticated')
```
Prova de aceitação de termos: machine_id, NIF, IP, cidade, data. É o registo
que se invoca numa discussão contratual.

**Devia ser:** `INSERT` fica; leitura só com `is_admin()`.

### `licencas_audit`, `invoice_signature_logs`, `company_signature_settings`
```
*_admin_read [SELECT -> authenticated] using (true)
```
As três chamam-se `admin_read` e **nenhuma verifica se quem lê é admin**. O
nome guardou a intenção; o `using` nunca foi escrito. `licencas_audit` tem 78
linhas; as outras duas estão vazias, mas `company_signature_settings` guarda
número de série e validade de certificados de assinatura.

**Quem escreve:** `assinar-licenca` e `gerir-licenca`, com **service role**
(linhas 280 e 309) — que ignora RLS. Apertar a leitura não lhes toca.

**Devia ser:** leitura só com `is_admin()`.

---

## O que não pode partir, e porquê

A pergunta que bloqueia esta tarefa é «e se o WashInvoice deixar de facturar?».
A resposta é que **não pode**, e não é opinião:

1. **O POS não tem conta nenhuma.** Zero contas do POS em `auth.users`. Toda a
   proposta acima mexe em predicados de `authenticated`. O POS nunca é
   `authenticated`.
2. **O POS escreve por duas portas, e nenhuma se toca.** Ou por políticas
   `INSERT` abertas ao anónimo (`pings`, `pedidos_renovacao`, `aceites_termos`)
   — que ficam exactamente como estão — ou por Edge Functions com service role,
   que ignoram RLS por definição. Verificado no `registar-terminal`, a porta de
   entrada do POS: corre inteiro com `SERVICE_ROLE` e só toca em `licencas`.
3. **Ler já lhe estava vedado.** As políticas de `SELECT` exigem
   `auth.role() = 'authenticated'`, e o anónimo não é. Nenhum caminho anónimo
   pode estar a depender destas leituras, porque nenhum funciona hoje.
4. **O Control continua igual.** Lê como `authenticated` **e** é admin. Todos
   os predicados propostos passam para ele.

Quem perde acesso é exactamente uma população: as 3 contas do Punho. Que é o
objectivo.

## O que não verifiquei

- **Seis Edge Functions não estão em nenhum repo local** (`validar-licenca`,
  `sincronizar-empresa`, `guardar-credenciais-wse-pos`, `comunicar-serie-pos`,
  `sincronizar-empresa-punho`, `receber-lead`, `enviar-sugestao`). Não li o
  código delas. O argumento 3 acima cobre-as em teoria — nenhuma pode estar a
  ler estas tabelas como anónimo, porque não funcionaria —, mas se alguma lê
  com o JWT de um utilizador do Punho, deixa de ler. Só isso.
- **O POS em si não está nesta máquina.** Tudo o que digo sobre ele vem do que
  está no servidor (contas, políticas, funções), não do código dele.
