# Handover — próxima sessão Cowork · Punho

**Data do handover:** 27 de Julho de 2026
**Última branch activa:** `feat/v006-boas-vindas` (Punho) — sprint 2 v0.0.6 a fechar
**Skill de contexto a invocar primeiro:** nenhuma para Punho ainda (o repo tem `CLAUDE.md` mas o Punho não tem skill dedicada; para WashInvoice existe `washinvoice`)

---

## Onde estás agora

O Punho está no fecho da v0.0.6. A sprint 1 já entregou:

- Frente A (Boas-vindas + MaisDados)
- Motor fiscal `RegimeFiscal` + `estimarSalarial` + tabelas IRS 2026
- Frente D (KPI "Custo real com pessoal")
- Follow-up Decisão 12 (`CustosMes.totalCents` sensível ao regime · commit `babb2b5`)
- Follow-up Decisão 13 (`OrientacaoDoContexto` · commit `ffe917d`)

Está em curso a **sprint 2 v0.0.6** (`prompts/punho_v006_sprint2_fecho_e_release.md`) — o Code está a executar. Ordem de execução ratificada com o Cesar:

**4 (C-UI Ficha Fiscal) → 2 (hit target) → 5 (Perfil popup) → 6 (doc) → 7 (release)**

Razão: contexto do motor fiscal fresco no Code, C-UI primeiro poupa recarga; hit target a seguir apanha os botões novos numa só passagem.

---

## O que falta na v0.0.6 (Prioridade 1 do checklist)

Depois de eu ter marcado os follow-ups 12 e 13 como concluídos, ficam **cinco itens**:

1. **Passo 4 · Frente C UI** — `FichaFiscalColaboradorForm`, `SegmentedButton`, chips NISS/NIF em falta. O widget deve nascer **parametrizado com lista de campos** (decisão nova desta sessão) — a sprint 2 do colaborador vai acrescentar IBAN, morada pessoal, data de nascimento. Nasce com o superset em mente.
2. **Passo 2 · Auditoria hit target** de sete grupos de botões (task #206). Padrão `Material + InkWell` com mesmo bounding box.
3. **Passo 5 · Popup Perfil minimalista** (Frente B).
4. **Passo 6 · Doc** `docs/design/punho_v006_sprint1.md`.
5. **Passo 7 · Release** — sub-passos 7.1 → 7.8. **Passo 7.8 é novo** (catalogar em `versoes_apps`, ver secção seguinte). O 7.6 escolheu Opção A (CI screenshot exclusion): validado como correcção certa, não workaround, porque os goldens dependem das fontes do Windows.

Task #205 (Decisão 13) já foi marcada como completed nesta sessão. Task #207 criada para o Passo 7.8.

---

## Descoberta desta sessão · Auto-update Punho

Verificaste comigo se a v0.0.5 no Redmi vai chamar a v0.0.6 assim que sair. Diagnóstico:

- **Arquitectura correcta**: `PunhoUpdateBannerWrapper` está enrolado à raiz da app em `lib/main.dart:68`, portanto o banner aparece em qualquer ecrã (login incluído). `PunhoUpdateService.check()` funciona sem sessão iniciada (anon key).
- **Ponto de falha silenciosa**: a Edge Function `versao-mais-recente` (projecto Supabase `oefqbkhioncakojipqyx`, mesmo do Control) lê da tabela `public.versoes_apps`. Se ninguém inserir a linha da v0.0.6, a EF devolve `actualizacao_disponivel: false` para toda a gente.

Estado real da tabela (verificado por MCP nesta sessão):

- Constraint `check (app in ('pos', 'control', 'punho'))` — já aceita 'punho'.
- Constraint `check (plataforma in ('all', 'windows', 'android', 'ios'))`.
- Único índice: `unique (app, build_number, plataforma)`.
- Linhas actuais de 'punho': apenas v0.0.1 (build 1) e v0.0.2 (build 2), duas por versão (windows + android), todas `activa=true`.
- v0.0.3, v0.0.4, v0.0.5 **nunca foram catalogadas** — é a razão de o Cesar nunca ter recebido banner nas versões anteriores. Efeito colateral bom: como o Redmi tem build 5 e a tabela topa em build 2, a EF já devolve `false`. Assim que a v0.0.6 entrar com build 6, banner aparece na hora do próximo check (arranque ou 24h).

**Preparado nesta sessão para o Passo 7.8:**

- `D:\Punho\prompts\punho_v006_7_8_catalogar_versao.sql` — template com placeholders `<URL_APK>` e `<NOTAS>` e query de verificação idêntica à da EF.
- `D:\Punho\prompts\punho_v006_sprint2_fecho_e_release.md` — Passo 7.8 acrescentado com instruções e nota de que na 0.0.7 este INSERT deve passar a ser feito automaticamente pelo workflow do GitHub Actions (task no backlog).
- `D:\WashInvoiceControl\washinvoice_control\supabase\versoes_apps.sql` — actualizado para bater com a realidade do BD (constraint com 'punho', coluna `plataforma`, `alter table` aditivos idempotentes).

**Execução prevista:** quando o Code publicar o APK e enviar o URL final, executas em segundos via MCP Supabase. Zero interrupção do Code.

---

## Prompt da sprint 1 v0.0.7 (já preparado, não arrancado)

`D:\Punho\prompts\punho_v007_sprint1_arquitectura_sidebar.md` — arquitectura da sidebar (Decisão 2). 7 passos com commits atómicos explícitos. Branch nova a partir de main quando a v0.0.6 fechar: `feat/v007-sidebar-empresa`.

**Não arrancar antes de a v0.0.6 estar fechada e taggeada.**

---

## Riscos abertos para o release 7.6 (workflow GitHub Actions)

Não confirmei — vale a pena o Code fazer *dry-run* antes de gastar a tag:

1. **Assinatura do APK no workflow.** A v0.0.5 saiu à mão; o job de release do CI nunca completou. Secrets do keystore (`KEYSTORE_BASE64`, etc.) podem estar em falta ou trocados no repo Punho.
2. **Task #197 · NDK 27.0.12077973** ainda pendente. Se o `build.gradle.kts` continuar em NDK antigo, `flutter build apk --release` no Ubuntu do CI pode partir com erro de toolchain. 5 minutos de bump. Vale a pena fazê-lo antes do 7.6.

---

## Ficheiros críticos para carregar

Prioridade alta para retomar contexto:

- `D:\Punho\CLAUDE.md` — aponta para skill washinvoice (não confundir; Punho não tem skill dedicada, o ficheiro é reciclado)
- `D:\Punho\docs\GUIAO_DE_PERCURSO_PRIMEIRO_EMPRESARIO.md` — as 13 decisões de produto
- `D:\Punho\docs\CHECKLIST_v006_ATE_FIM.md` — 8 prioridades até v2.x
- `D:\Punho\prompts\punho_v006_sprint2_fecho_e_release.md` — sprint em execução (com Passo 7.8 novo)
- `D:\Punho\prompts\punho_v006_7_8_catalogar_versao.sql` — template pronto
- `D:\Punho\prompts\punho_v007_sprint1_arquitectura_sidebar.md` — sprint seguinte

Prioridade média:

- `D:\Punho\docs\BIBLIOTECA_DE_ALAVANCAS.md` — princípios editoriais das recomendações
- `D:\Punho\docs\AUDITORIA_KPIS_EMPRESA.md`, `AUDITORIA_APP_ENSINO_GESTAO.md`, `AUDITORIA_FORA_DA_CAIXA.md`

---

## Regras que Cesar reforçou nesta sessão

- **"Termina, não hesites."** Menos perguntas de autorização, mais decisões próprias dentro do quadro.
- **"Verde ≠ certo"** — teste que passa mas testa comportamento errado é dívida, não segurança. Reinverter, não ajustar.
- **Duas mãos a fazer a mesma coisa = bug garantido para voltar.** Quando um mecanismo é refactorizado e o antigo fica sem chamadores, apaga.
- **Widgets que vão ser reusados com superset de campos nascem parametrizados.** Custo marginal agora, sanidade depois.
- **Goldens dependem de rendering platform-specific** — `@Tags(['screenshot'])` + `--exclude-tags` é política, não workaround. Aplica sempre.

---

## Estado dos push notifications (contexto rápido)

Trigger `notificar_novo_pedido_punho` foi corrigido nesta janela (v8 da EF `enviar-push` exige `title/body/data` em inglês, não `titulo/corpo/dados`). Prompt `D:\Punho\prompts\punho_notificar_novo_pedido.md` tem `## Verificação` no fim com o postmortem. Task #196 fechada.

Task #188 ainda pendente (Control 1.8.1 no Redmi) — sem isso os push não têm dispositivo alvo.

---

## Passo imediato ao retomar

1. Perguntar ao Cesar em que ponto está o Code (Passo 4? 2? Já no 7?).
2. Se estiver a chegar ao 7.6, verificar #197 (NDK) e riscos de secrets do workflow.
3. Assim que o release estiver publicado, executar `punho_v006_7_8_catalogar_versao.sql` via MCP Supabase (substituir URL e notas).
4. Fechar task #207.
