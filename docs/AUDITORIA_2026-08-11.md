# Auditoria de 11 Ago 2026 — estado

Alvos: `punho` (v0.3.72), `punho_operador` (v0.0.2), `washinvoice-control`, base
`oefqbkhioncakojipqyx`. Lentes: código morto · dados (integridade, RGPD,
backup) · runtime · experiência.

Este ficheiro é a lista viva. Actualiza-se à medida que se fecha.

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

## Aberto

### Alta

**4.1 + 4.2 — backup provado.** Cadeia montada e por correr. Falta a senha da
base em `~/.punho/copia.env`. Ver **[COPIAS_DE_SEGURANCA.md](COPIAS_DE_SEGURANCA.md)**.

**6.1 — acessibilidade.** 3 ocorrências de `Semantics`/`semanticLabel` em 33.910
linhas do Punho; **0** no OP e **0** no Control. 11 (punho) + 18 (control)
`GestureDetector`/`InkWell` que um leitor de ecrã não anuncia de todo.

### Média

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
