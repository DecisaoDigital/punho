# Auditoria de 11 Ago 2026 — estado

Alvos: `punho` (v0.3.72), `punho_operador` (v0.0.2), `washinvoice-control`, base
`oefqbkhioncakojipqyx`. Lentes: código morto · dados (integridade, RGPD,
backup) · runtime · experiência.

Este ficheiro é a lista viva. Actualiza-se à medida que se fecha.

> **Correcção ao original.** O relatório dizia `flutter analyze` limpo nas três
> apps. Não está: o Control tem 12 avisos `deprecated_member_use` — `value:` em
> campos de formulário e `onChanged` em `Radio`, do SDK ter andado para a
> frente. Confirmado com `git stash`, são anteriores a qualquer coisa feita
> aqui. Punho e OP esses sim, limpos.

## Fechado

| # | Achado | Como fechou |
|---|---|---|
| 3.1 | Não existia apagamento de titular | `punho_apagar_titular` + ecrã em Gestão. Redacção no lugar, porque o log é append-only e os terminais re-hidratam dele. Prova em `punho_apagamentos` |
| 3.2 | Não existia retenção | `punho_expurgar_dados()` no pg_cron, 04:17 diário. Telemetria 30 d, leads 6 meses, auditoria 12 meses. Fiscal e laboral intocados |
| 2.1 | `licencas_audit`: 62 de 113 linhas a apontar para licenças apagadas | Identidade passou para `licenca_machine_id`/`licenca_app`; FK `on delete set null`; trigger escreve null no DELETE. 0 órfãos |
| 2.2 | RLS ligado e 0 políticas em 3 tabelas | Era o contrário do que parecia: a ausência de políticas é deliberada, o errado eram os GRANT. O `anon` tinha INSERT/UPDATE/DELETE em **25** tabelas (`chaves_mestre`, `licencas`, `punho_empresas`, `punho_apagamentos`…). Revogados. Agora 0 |
| 2.3 | Colunas `*_id` sem chave estrangeira | 4 chaves criadas em `punho_alteracoes_contabilista` e `punho_conflitos_pendentes`, com índices. Os 3 `entidade_*_id` **não levam chave** — são ids locais em `text`, apontam para o log, não para uma linha. O achado estava errado |
| 2.4 | `reltuples = -1`, planeador às cegas | `ANALYZE`. 0 tabelas sem estatísticas |
| 1.2 | Ficheiros nunca importados | `access_profile.dart` removido. `graficos.dart` **fica** — ver abaixo |
| 1.4 | `flutter_riverpod` declarado e não usado no OP | Removido do pubspec |
| 1.6 | Assets sem referência | Falso alarme parcial: são originais do gerador de ícones. Não se apagam |
| 3.7 | Políticas do `storage.objects` nunca verificadas | Verificadas: estão bem. Cada empresa só chega à sua pasta, o comprovativo de despesa só é lido pelo autor ou por um gestor, e as fotografias de máquinas exigem membro activo. O que faltava era o `file_size_limit`, a null — qualquer membro podia enviar 900 MB e encher o plano de 1 GB, levando atrás o balde de onde saem os APKs. Posto a 20 MB |
| 5.1 | 26 `ListView(` não-lazy | Convertidas as **duas que crescem com o negócio**: o extracto de despesas/recebimentos e a lista de clientes e leads (esta com `SliverList`, por ter dois títulos pelo meio). As outras — máquinas, colaboradores, veículos — não se converteram de propósito: uma lavandaria tem dez máquinas e cinco empregados, e trocar `children` por `builder` aí é ruído sem ganho |
| 6.1 | Acessibilidade quase inexistente | **Estava mal medido.** Contar `Semantics` é mau indicador: o `InkWell` já anuncia o toque e um filho com texto já traz rótulo. Medido pela lente certa — botões que são *só* um ícone —, o Punho tinha 2 (o contador de mais/menos) e o Control 6, entre eles o olho da palavra-passe repetido em 3 ecrãs. Todos com nome agora. Mais o `Semantics` na linha que se copia no diagnóstico de licença, que só se anunciava por um ícone de 14 px |

## Aberto

### Alta

**4.1 + 4.2 — backup provado.** A cadeia está ensaiada ponta a ponta contra uma
base que faz de produção (`./scripts/ensaio_de_copia.sh`): tira a cópia,
restaura-a, compara o inventário, usa a base restaurada, e recusa tanto um
ficheiro rasurado como uma cópia assinada cuja conta não bate. Falta correr o
mesmo contra a produção, e para isso falta a senha em `~/.punho/copia.env`. Ver
**[COPIAS_DE_SEGURANCA.md](COPIAS_DE_SEGURANCA.md)**.

### Média

**6.1 (resto)** — os 18 `InkWell`/`GestureDetector` do Control não foram
olhados um a um. Os 11 do Punho foram, e estão bem: o teclado do cadeado já
tinha tooltip nas duas teclas de ícone, e os restantes têm texto por baixo. O
que falta do lado do Punho é o estado dos acordeões (aberto/fechado) e uma
passagem pelo OP.

**3.4** — `punho_leads_entrada` guarda dados de terceiros sem consentimento
registado no esquema. O expurgo aos 6 meses já lá está; o consentimento não.

**3.5** — 5 funções `SECURITY DEFINER` executáveis pelo `anon`. Reavaliado ao
fechar o 2.2: **revogar o EXECUTE parte as políticas**, porque 22 delas estão
declaradas `to public` e é o `anon` que as avalia — passaria de «zero linhas»
para «permission denied». O caminho é passar essas políticas de `to public` para
`to authenticated`, e é uma migração por si. Sobra o `punho_validar_convite`,
que é enumerável por quem adivinhe códigos: isso quer limitação de tentativas.

**5.1** — 26 `ListView(` não-lazy contra 1 `ListView.builder`
(`workforce_pages.dart:114,697`, `finance_pages.dart:44`,
`operational_pages.dart:1396,2069`, `pedidos_pendentes_screen.dart:42`).

**5.2** — 10 ficheiros com `.select()` sem `limit`/`range`. Cuidado ao fechar:
pôr limite onde a completude importa é trocar lentidão por perda silenciosa de
linhas, que já aconteceu aqui antes.

**6.3** — Control sem tema nenhum: 0 `Theme.of(context)` e 285 `Colors.*` em 95
ficheiros. **6.4** — nenhuma das 3 apps define `darkTheme`.

**6.5** — 549 `Text(` no Punho para 49 `maxLines`/`overflow`.
**6.6** — 94 alvos de toque abaixo de 48 dp nas três apps.

**Novo, encontrado ao fechar o 3.7 — as fotografias de máquinas não se apagam
nunca.** Sobem para `<empresa>/machines/<carimbo>.<ext>` e não há política de
DELETE que lhes chegue (a que existe só cobre os comprovativos registados em
`punho_documentos`), nem a app tem por onde as apagar. Trocar a fotografia de
uma máquina deixa a antiga lá para sempre, apagar a máquina também, e o
`punho_apagar_titular` não toca no storage. Fechar isto é política + o lado da
app, e é trabalho a sério, não um remendo.

**`allowed_mime_types` continua a null** no `punho-documentos`. Devia aceitar só
imagens e PDF, mas a verificação é feita contra o `content-type` que o cliente
declara: se a inferência falhar num caso qualquer, o envio passa a ser recusado
em produção. Não se mete sem experimentar no aparelho.

### Baixa

**1.3** — 7 tabelas `punho_*_copia_2026_08_09` vivas em produção, todas com 0
linhas, mais 7 políticas RLS por manter. Apagar é destrutivo: fica à decisão.

**1.5** — `~/punho-backend` é uma cópia completa do repo (254 ficheiros dart)
parada no branch `hardening/backend` desde 10/8. Risco de editar o sítio errado.
Apagar é destrutivo: fica à decisão.

**3.6** — *leaked password protection* desligada na autenticação. É um interruptor
(`password_hibp_enabled`). Não se ligou porque rejeita palavras-passe que
apareçam em fugas conhecidas, e isso dá atrito imediato com as contas de ensaio.

### Por verificar — nunca foram olhados

Políticas de `storage.objects` (3.7) · edge functions · índices contra planos
reais · o ecrã de RGPD no Redmi, que está provado na base viva e em testes de
widget mas nunca foi tocado por um dedo.

## O que fica de pé

`graficos.dart` (250 linhas, `SparklineDiaria`, `AnelPercentagem`,
`BarraHorizontal`, `MiniCalendario`) não é importado por ninguém desde que o
carrossel de slides saiu — vem do commit `53c9183`. Não se apagou de propósito:
são exactamente as peças de desenho de que o **ecrã de futurologia** precisa, e
apagá-las agora é garantir que se reescrevem daqui a um mês. Se não for isso que
se quer, `git rm` e o commit guarda-as.
