# Prompt Claude Code — Punho v0.0.4

## Update check e banner independentes do gate de auth

**Repo:** `punho`
**Base:** branch `chore/estabilizacao-v0.0.3` (assumindo mergeada; se não, sai da mais recente estável)
**Branch nova:** `feat/update-global`

---

## Problema (por leitura + confirmado com Cesar)

Utilizadores com o Punho instalado ficam sem receber notificação de update em três cenários hoje muito prováveis (a maioria dos utilizadores está num deles):

1. **Bloqueado no ecrã de login** — nunca ganham sessão, `PunhoUpdateService.check()` sai imediatamente com `if (session == null) return null;`.
2. **Sessão válida mas pedido pendente** — o `AcessoGate` mostra "Pedido em análise" e nunca chegam ao `dashboard_page.dart`, onde o `UpdateBanner` está montado.
3. **Sessão válida mas acesso recusado/revogado** — idem, ecrã "Acesso indisponível".

Consequência prática: hoje só um utilizador com adesão activa em `punho_membros` que abra o dashboard recebe update. Como (a) a app está em fase inicial com muitos utilizadores por aprovar e (b) uma versão futura pode reintroduzir gates diferentes, o modelo actual é frágil.

**Diagnóstico confirmado por leitura de:**
- `lib/core/updates/update_service.dart:12-14` (guarda `session == null`)
- `lib/features/updates/presentation/update_banner.dart` (widget)
- Único call site do banner: `lib/features/dashboard/presentation/dashboard_page.dart`
- Punho não tem FCM (`firebase_messaging` não em `pubspec.yaml`)

---

## Objectivo

Quando publicar v0.0.4 (ou qualquer versão posterior) no GitHub Releases + `versoes_apps` do Supabase, **todos os utilizadores instalados** — mesmo bloqueados no `AcessoGate` — recebem banner de update assim que abrem a app, com botão para descarregar.

---

## Regras não negociáveis

1. **Zero regressão no gate de acesso.** Continua a bloquear utilizadores não aprovados; o banner é ortogonal, não bypass.
2. **Zero mudança na Edge Function `versao-mais-recente`.** Já é chamada com anon key pelo Control e funciona.
3. **Zero código de FCM nesta sprint** (ver secção "Fora do âmbito").
4. **Update obrigatório continua obrigatório.** Se `obrigatoria == true`, banner é bloqueante em qualquer ecrã (gate ou shell). O gestor não pode dispensar; o utilizador bloqueado não pode continuar até actualizar.

---

## Alterações

### 1. `PunhoUpdateService.check()` — deixar de exigir sessão

**Ficheiro:** `lib/core/updates/update_service.dart`

- Remover a guarda `if (session == null) return null;`.
- Se não houver sessão, chamar `functions.invoke` **sem** header `Authorization` explícito — o `supabase_flutter` envia automaticamente a chave pública do projecto, que é aceite pelo gateway das Edge Functions com `verify_jwt` (comportamento verificado empiricamente para o Control em Julho 2026 — ver `LICENCIAMENTO.md` do Punho, secção "Porque é que funciona sem sessão").
- Se houver sessão, continua a usar o `accessToken` como hoje (para a Edge Function poder logar quem pediu, se um dia isso for útil).
- Manter o `try/catch (_)` — falha silenciosa continua a ser o comportamento correcto.

### 2. Provider global de update

**Ficheiro novo ou providers existentes:** um `StateNotifierProvider<PunhoUpdateInfo?>` que:

- Corre `check()` **uma vez** logo após `Supabase.initialize` no `main.dart`, independentemente do estado de auth.
- Corre `check()` outra vez sempre que o `authStateChanges` transita para sessão nova (ganho de login).
- Timer periódico opcional (24h, alinhado com o padrão do Control) — se for over-engineering para agora, saltar e ficar só nos dois disparos acima.

### 3. Wrapper global do `UpdateBanner`

**Ficheiro novo:** `lib/features/updates/presentation/update_banner_wrapper.dart`

Widget que envolve os 3 shells possíveis:
- `AcessoGate` (com estado "Pedido em análise" ou "Acesso indisponível")
- `AppShell` (gestor)
- `CollaboratorShell` (colaborador)

**Implementação recomendada:** o wrapper substitui o widget-raiz mostrado pelo router após `Supabase.initialize`. Cada shell/gate continua a existir e a renderizar-se como hoje — o wrapper é uma `Column` ou `Stack` que mostra o banner **por cima** do conteúdo se `PunhoUpdateInfo != null`. Se `obrigatoria == true`, o banner cobre a app inteira (modal).

**Remover:** o `UpdateBanner` do `dashboard_page.dart` — agora vive no wrapper e não é preciso em ecrã específico.

### 4. Testes widget

**Directório:** `test/features/updates/`

- `update_banner_wrapper_test.dart`:
  - Banner aparece em `AcessoGate` (pedido pendente) quando `updateProvider` tem `PunhoUpdateInfo`.
  - Banner aparece em `AcessoGate` (recusado/revogado) idem.
  - Banner aparece em `AppShell` idem.
  - Banner aparece em `CollaboratorShell` idem.
  - Banner **não** aparece quando `updateProvider` é `null`.
  - Banner bloqueia interacção com o resto quando `obrigatoria == true`.
- `update_service_test.dart` (novo ou actualizar existente):
  - `check()` **sem** sessão devolve `PunhoUpdateInfo` quando servidor diz que há update (mock da Edge Function).
  - `check()` **sem** sessão devolve `null` quando servidor diz que não há.
  - `check()` **sem** sessão devolve `null` quando servidor retorna erro (silencioso).

### 5. Doc

- `docs/design/punho_v004_update_global.md` com: motivação (o buraco actual), decisões (por que Column vs Stack, por que sem FCM agora), diagrama simples do fluxo de disparo.
- Actualizar `docs/ESTADO_ATUAL_DA_APP.md` — mover "auto-update" de "Já preparado" para "Já utilizável" (com nota que agora é global).

---

## Gate

1. `flutter test` — verde, zero regressões. Reporta contagem antes/depois.
2. `flutter analyze` — limpo.
3. Widget tests do wrapper cobrem os 3 shells + os 2 estados de update.
4. Manualmente (podes documentar como "por fazer" para o Cesar): simular publicar `versoes_apps` com build superior ao actual, arrancar app sem login, verificar banner aparece.
5. **`pubspec.yaml` — NÃO bumpar.** Fica em `0.0.3+X` (a que estiver). Este é o primeiro sprint da v0.0.4 mas a v0.0.4 fica aberta para acumular mais fixes que o Cesar vai descobrir ao testar a v0.0.3 no telemóvel. Quem bumpa é o Cesar quando decidir fechar o release.

## Fora do âmbito (registar em BACKLOG_v0.1.0.md)

- **FCM push** — avaliação custo/benefício: adicionar `firebase_messaging`, projecto Firebase, service account, código de registo de token, tratamento em foreground/background. Só vale a pena quando houver utilizadores reais e for aceitável o custo Firebase Spark plan (grátis para volumes baixos). Registar como task para v0.1.0 com nota "só se justificar".
- Reintroduzir o `UpdateBanner` embutido em ecrãs específicos com contexto extra (ex: dashboard mostrar "actualização inclui novo painel financeiro") — over-engineering para agora.

## Entrega

- Branch `feat/update-global`, N commits locais, sem push.
- Doc de design escrito.
- `pubspec.yaml` intacto (o Cesar bumpa quando fechar o release).
- Aviso no fim do sumário: **este código só passa a valer depois de o Cesar tagar e publicar a próxima versão. A v0.0.3 instalada por USB no Redmi continua sem update automático — só a próxima é que passa a ter.**
