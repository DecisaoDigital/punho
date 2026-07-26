# Prompt Claude Code — Punho v0.0.3 (release consolidada)

## Objectivo

Fechar a v0.0.3 com **tudo** incluído — sprint de estabilização (já feito na branch `chore/estabilizacao-v0.0.3`) **+ update check/banner global** (previamente pensado para v0.0.4, agora antecipado para v0.0.3). Terminar com **APK release compilado**, pronto a instalar por USB no Redmi.

**Repo:** `D:\Punho`
**Base:** branch `chore/estabilizacao-v0.0.3`
**Branch novo:** `release/v0.0.3` (a partir de `chore/estabilizacao-v0.0.3`)

Este prompt substitui `punho_v004_update_banner_global.md` — as ideias desse ficheiro passam a estar aqui, agora dirigidas à v0.0.3.

---

## Contexto

- v0.0.2 está instalada no telemóvel do Cesar. Não passa do ecrã de login porque o `AcessoGate` bloqueia (esquema Punho aplicado em prod mas `punho_membros` vazia).
- v0.0.2 também **não** tem auto-update em ecrãs pré-login (banner só está em `dashboard_page.dart`, e o check exige sessão).
- Portanto a v0.0.3 tem que ir por USB. **Depois de a v0.0.3 estar instalada com o update global, próximas versões vão por auto-update.**
- O Cesar quer testar tudo junto neste próximo APK.

---

## Regras não negociáveis

1. **Zero regressão** nos fixes do sprint de estabilização (3 P0 + 8 P1, 162 → 220+ testes). A base é `chore/estabilizacao-v0.0.3` — nada é revertido.
2. **Zero regressão** no `AcessoGate` — continua a bloquear utilizadores não aprovados. O banner é ortogonal, não bypass.
3. **Zero mudança na Edge Function `versao-mais-recente`** — já testada com anon key pelo Control.
4. **Zero código de FCM.** Adia para v0.1.0 quando houver justificação.
5. **Update obrigatório continua obrigatório:** se `obrigatoria == true`, banner é bloqueante em qualquer ecrã (gate ou shell).

---

## Alterações

### 1. `PunhoUpdateService.check()` — deixar de exigir sessão

**Ficheiro:** `lib/core/updates/update_service.dart` (linhas 12-14)

- Remover `if (session == null) return null;`.
- Se não houver sessão, chamar `functions.invoke` **sem** header `Authorization` explícito — o `supabase_flutter` envia automaticamente a chave pública, aceite pelo gateway das Edge Functions com `verify_jwt` (padrão empiricamente verificado no Control em Julho 2026 — ver `docs/LICENCIAMENTO.md` do Punho, secção "Porque é que funciona sem sessão").
- Se houver sessão, continua a passar o `accessToken` como header.
- Manter o `try/catch (_)` — falha silenciosa é o comportamento correcto.

### 2. Provider global de update

Criar um `StateNotifierProvider<PunhoUpdateInfo?>` (ou equivalente Riverpod que vá bem com a arquitectura actual) que:

- Corre `check()` **uma vez** logo após `Supabase.initialize` em `main.dart`, independentemente do estado de auth.
- Corre `check()` outra vez em cada transição de `authStateChanges` para sessão nova.
- (Opcional, se der pouco esforço) Timer periódico de 24h, alinhado com o padrão do Control. Se der esforço, saltar.

### 3. Wrapper global do `UpdateBanner`

**Ficheiro novo:** `lib/features/updates/presentation/update_banner_wrapper.dart`

Widget que envolve os 3 shells possíveis:
- `AcessoGate` (com estado "Pedido em análise" ou "Acesso indisponível")
- `AppShell` (gestor)
- `CollaboratorShell` (colaborador)

**Implementação:** substitui o widget-raiz mostrado pelo router após `Supabase.initialize`. Cada shell/gate continua a existir como hoje — o wrapper é `Column` ou `Stack` que mostra o banner **por cima** do conteúdo se `PunhoUpdateInfo != null`. Se `obrigatoria == true`, banner cobre a app inteira (modal).

**Remover:** o `UpdateBanner` do `dashboard_page.dart` — passa a viver no wrapper.

### 4. Testes widget

**Directório:** `test/features/updates/`

- `update_banner_wrapper_test.dart`:
  - Banner aparece em `AcessoGate` (pedido pendente) quando `updateProvider` tem `PunhoUpdateInfo`.
  - Banner aparece em `AcessoGate` (recusado/revogado) idem.
  - Banner aparece em `AppShell` idem.
  - Banner aparece em `CollaboratorShell` idem.
  - Banner **não** aparece quando `updateProvider` é `null`.
  - Banner cobre a app inteira quando `obrigatoria == true`.
- `update_service_test.dart` (novo ou actualizar existente):
  - `check()` **sem** sessão devolve `PunhoUpdateInfo` quando servidor diz que há update.
  - `check()` **sem** sessão devolve `null` quando não há.
  - `check()` **sem** sessão devolve `null` em erro (silencioso).

### 5. Doc

- `docs/design/punho_v003_update_global.md` com: motivação (o buraco actual), decisões (Column vs Stack, sem FCM agora), diagrama do fluxo de disparo, aviso "a v0.0.3 é a primeira com update global — v0.0.2 instalada não tem".
- Actualizar `docs/ESTADO_ATUAL_DA_APP.md` — mover auto-update de "Já preparado" para "Já utilizável".
- Actualizar `docs/AUDITORIA_BUGS_v0.0.3.md` — se houver entradas P2 do sprint anterior que agora deixam de fazer sentido, marcar.

### 6. Bump `pubspec.yaml`

- **Sim, bumpar.** `version: 0.0.2+2` → `version: 0.0.3+3`.
- É o release. O Cesar quer o APK pronto para instalar.

---

## Gate

1. `flutter test` — verde, zero regressões. Reporta contagem antes/depois.
2. `flutter analyze` — limpo (aceita warnings pré-existentes conhecidos).
3. Widget tests do wrapper cobrem os 3 shells + 2 estados de update.
4. `flutter build apk --release` corre sem erros. APK sai em `D:\Punho\build\app\outputs\flutter-apk\app-release.apk`.
5. Reporta tamanho final do APK e checksum SHA-256.

---

## Entrega

- Branch `release/v0.0.3`, N commits locais, sem push.
- Doc de design escrito.
- `pubspec.yaml` em `0.0.3+3`.
- APK compilado.
- **NÃO tagar nem publicar GitHub Release** — o Cesar decide quando fazer isso (quer testar o APK primeiro no Redmi por USB).

## Fora do âmbito (registar em `docs/BACKLOG_v0.0.4.md`)

- **FCM push** — avaliação custo/benefício para v0.1.0.
- Persistência do último check para não repetir a cada arranque a frio.
- Melhorias UX no banner (colapsar/expandir, notas de release inline).
- Tratamento fino de "obrigatória" (contagem regressiva, mensagens localizadas).

## Aviso ao Cesar (colocar no sumário final)

> A v0.0.3 é a primeira versão do Punho com update global. A v0.0.2 instalada no Redmi **não** sabe verificar updates fora do dashboard, portanto **tens de instalar a v0.0.3 por USB** — não vai chegar por auto-update. Depois disto, próximas versões chegam sozinhas assim que fores publicando `versoes_apps` no Supabase.
