# Prompt Claude Code — Punho v0.0.4

## Ecrã "Definições da Empresa" (ler + editar tudo o que o onboarding recolheu)

**Repo:** `punho`
**Branch nova:** `feat/definicoes-empresa` (a partir do topo actual da v0.0.3)

## Problema (o que o utilizador reporta)

1. **Nada mostra os valores introduzidos no onboarding.** O gestor preenche facturação, custos fixos, morada, NIF, colaboradores, veículos, etc., mas depois na app **não consegue ver nem editar** esses valores em lado nenhum. Fica com a sensação de "escrevi para o vazio".
2. **Números fantasma no Dashboard.** O utilizador viu números que "não pertenciam ao que tinha colocado". Provavelmente vêm de `HistoricalMonth` residual ou algum stale state — investigar e corrigir.

## Estado actual (não duplicar)

- `OnboardingData` (em `lib/data/repositories/operation_repository.dart`) tem **todos** os campos: `ownerName`, `companyName`, `legalForm`, `hasFleet`, `collaborators`, `totalMachinesDeclared`, `companyTaxId`, `companyPhone`, `companyEmail`, `companyAddress`, `companyPostalCode`, `companyLocality`, `revenueLastYearCents`, `revenueThisYearCents`, `maintenanceLastYearCents`, `fixedMonthlyCostsCents`.
- `OperationsController.completeOnboarding(...)` já sabe persistir estes campos — o repositório grava via `saveOnboarding()` + `copyWith`.
- O `OnboardingPage` recolhe estes dados **uma única vez** e nunca mais os expõe.
- O modelo tem já uma classe (`CompanySettings` em `lib/domain/models/company_settings.dart`) — verificar se é a mesma coisa ou se se pode fundir.
- O onboarding foi simplificado na v0.0.3 (agora tem 12 passos para gestor, 4 para colaborador, com switch a meio para saltar dados operacionais). **Ver** `_OnboardingPageState` para o layout final.
- Foi adicionada var `role` no state do onboarding (`gestor` | `colaborador`) e var `vehicles` (int, substituiu o bool `fleet`, que agora deriva de `vehicles > 0`). O ecrã Definições deve manter ambas coerentes.

## Regras não negociáveis

1. **Zero regressão** no onboarding — se o utilizador já preencheu, ao voltar ao Definições deve **ver os valores actuais** pré-preenchidos.
2. **Só o gestor** pode aceder ao ecrã de Definições. Colaborador não vê (RLS na app: `AcessoGate` já filtra shell — mas dentro da AppShell também bloquear).
3. **Não criar segunda fonte de verdade.** Se `CompanySettings` (modelo) já cobre parte dos campos, unificar com `OnboardingData` — o utilizador não tem que saber a diferença.
4. **Guardar não pode partir** o resto: se o utilizador limpar o NIF, o gate universal fiscal do POS (se um dia houver) tem que aguentar; se limpar colaboradores para 0, a área "Funcionários" desaparece da sidebar; idem veículos.

## Alterações

### 1. Novo ecrã `CompanySettingsPage`

**Ficheiro:** `lib/features/company/presentation/company_settings_page.dart` (criar pasta `company/` se não existir).

Formulário editável agrupado em 4 secções:

- **Identificação:** nome do responsável, nome da empresa, forma jurídica (dropdown), NIF.
- **Contactos e morada:** telemóvel, email, morada, código-postal, localidade.
- **Equipa e frota:** colaboradores (número), veículos (número, `hasFleet` derivado de `>0`).
- **Referências financeiras:** facturação ano passado, facturação este ano, manutenção ano passado, custos fixos mensais.

Cada secção num `Card` ou `_CardSeccao`, com título e ícone. Botão único **"Guardar"** no fim + botão **"Cancelar"** (descarta alterações e volta).

**Autofocus:** *não* — o utilizador vai directo ao campo que quer editar, não faz sentido forçar foco.

### 2. Método `updateCompanySettings` no controller

**Ficheiro:** `lib/core/operations/operations_controller.dart`

Adicionar método que aceita **todos** os campos como named parameters opcionais e chama `_repo.saveOnboarding(current.copyWith(...))`. Não usar o `completeOnboarding` existente — esse é para o primeiro fluxo (define onboarding do zero); o `updateCompanySettings` é para editar depois.

Signature sugerida:
```dart
void updateCompanySettings({
  String? ownerName,
  String? companyName,
  String? legalForm,
  int? collaborators,
  int? vehicles,   // hasFleet = vehicles > 0
  String? companyTaxId,
  String? companyPhone,
  String? companyEmail,
  String? companyAddress,
  String? companyPostalCode,
  String? companyLocality,
  int? revenueLastYearCents,
  int? revenueThisYearCents,
  int? maintenanceLastYearCents,
  int? fixedMonthlyCostsCents,
}) { ... }
```

### 3. Acesso ao ecrã

**Duas opções — decide qual é mais coerente com a arquitectura actual:**

- **A) Novo `AppDestination.companySettings`** com ícone `Icons.business_outlined` na sidebar. Aparece sempre para gestor. Mais visível mas ocupa mais espaço na sidebar (que agora é 72 dp).
- **B) Botão/tab no ecrã `Gestão` (Dashboard)** — ex: `IconButton(Icons.edit_note)` no topo do dashboard com tooltip "Editar dados da empresa". Menos visível mas mantém sidebar limpa.

**Recomendo B** — a sidebar tem 72 dp e queremos mantê-la fina; um botão discreto no dashboard cobre o caso de uso.

### 4. Bug secundário: números fantasma no Dashboard

Investigar de onde vêm os "números que não pertencem" que o utilizador viu:

- Provável fonte 1: `HistoricalMonth` residual — o utilizador em teste anterior preencheu um mês, ficou gravado; o `MonthlyHistoryPage` (ou o Dashboard) mostra mesmo com dados antigos que não fazem parte deste ciclo.
- Provável fonte 2: valores default hardcoded em algum widget do Dashboard.
- Provável fonte 3: `historicalMonths` no `OperationsState` a ter dados que sobreviveram a "limpar dados" no telemóvel (SharedPreferences vs. state em memória — verificar).

**Fix esperado:** garantir que ao apagar dados no telemóvel (`Storage → Clear data`) o `OperationsController` arranca **zerado** — nenhum `HistoricalMonth`, nenhum valor pré-carregado. Se necessário, adicionar um botão "Repor dados" no ecrã de Definições ou em Sobre para forçar reset explícito.

### 5. Testes

- **Widget test** de `CompanySettingsPage`: monta com um `OperationsState` fake com valores conhecidos, verifica que os campos aparecem pré-preenchidos, altera um campo, tap Guardar, verifica que o método `updateCompanySettings` do controller foi chamado com o novo valor.
- **Unit test** de `updateCompanySettings`: verifica que só actualiza campos que recebe (null preserva o existente), que `hasFleet` é derivado correctamente de `vehicles`.
- **Widget test** do botão de acesso (dashboard): verifica que o botão está presente, que tapping abre a página.
- **Integration/manual:** limpar dados do telemóvel + reinstalar + verificar que Dashboard arranca sem nenhum valor fantasma.

## Gate

1. `flutter test` — verde, zero regressões (deve estar em ~181 antes; espera-se +5-10 novos).
2. `flutter analyze` — limpo.
3. Verificação manual pelo Cesar (após instalar APK novo): entra no Dashboard, vê botão "Editar dados da empresa", abre, vê os valores que introduziu no onboarding pré-preenchidos, edita um, guarda, sai, volta a entrar, valores mantidos.
4. **Não bumpar `pubspec.yaml`** — Cesar decide quando fecha a v0.0.4.

## Entrega

- Branch `feat/definicoes-empresa`, N commits locais, sem push.
- Doc `docs/design/punho_v004_definicoes_empresa.md` com decisões (A ou B para acesso, como o bug de números fantasma foi resolvido).

## Fora do âmbito

- Sincronização com Supabase real (`update_company_settings` server-side) — v0.1.0.
- Ecrã de "Repor tudo" completo — só o botão de reset se for necessário para o bug dos números fantasma.
- Histórico de alterações da empresa — v0.1.0.
