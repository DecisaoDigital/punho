# Auditoria de bugs — Punho v0.0.3 (sprint de estabilização)

**Branch:** `chore/estabilizacao-v0.0.3` · **Base:** `feat/contas-organizacao`
**Âmbito:** zero features novas. Bug hunt, correcção de P0/P1 e cobertura de
testes do happy path.
**Versão:** fica em `0.0.2+2`. Não foi bumpada.

## Como foi feito o hunt

Não houve exploração manual da app. O hunt foi:

- **`[cod]`** — leitura sistemática do código dos fluxos 1 a 9.
- **`[test]`** — teste automatizado que exercita o fluxo e apanhou o defeito.
- **`[manual]`** — por verificar; precisa de mãos e olhos numa app a correr.

Cada entrada abaixo diz como foi encontrada. As entradas `[manual]` **não foram
eliminadas** — estão listadas na secção "Por verificar à mão".

## Estado

| | P0 | P1 | P2 |
|---|---|---|---|
| FIXED | 3 | 7 | 0 |
| PENDING | 0 | 0 | 8 |

**Nenhuma entrada P0 ou P1 em PENDING.**

Testes: **106 → 162** (+56), todos verdes. `flutter analyze` limpo.

> **PRONTO PARA SMOKE MANUAL.** Os 9 fluxos do happy path estão por confirmar
> numa app a correr — é o passo do Cesar. Enquanto não estiver assinado aqui
> em baixo, isto não vai a lado nenhum.
>
> Smoke manual: `PENDENTE` — data: ____ · build: ____ · resultado: ____

---

## P0 — crash ou erro visível

### P0-1 · Colaborador aprovado recebia a shell de gestor · **FIXED** (`dc5a904`)
`[cod]` — entrada obrigatória da Fase 2.

- **O que acontecia:** com Supabase activo, `AcessoGate` mandava toda a gente
  aprovada para a `AppShell`. `app_shell.dart` só escolhia a `CollaboratorShell`
  quando o Supabase estava **desligado** (`!SupabaseConfig.enabled`).
- **O que devia acontecer:** o `perfil` aprovado em `punho_membros` escolhe a
  shell.
- **Impacto:** um colaborador via custos, salários e lucros globais. Viola
  directamente `AUDITORIA_E_PLANO_DO_PRODUTO.md` §4.2.
- **Causa-raiz:** a decisão de perfil estava no sítio errado — na shell, com uma
  condição de modo de demonstração, em vez de no router que já sabia o perfil.
- **Fix:** `auth_gate.dart` — `DecisaoAcesso.app` passa a despachar
  `acesso.eGestor ? AppShell : CollaboratorShell`. A condição em
  `app_shell.dart` fica, comentada, só para o modo de demonstração local.
- **Teste:** `test/features/shell/shell_por_perfil_test.dart` — gestor →
  `AppShell`, colaborador → `CollaboratorShell`, e a shell do colaborador não
  mostra "Custos", "Salários", "Lucro" nem "Centro de comando".

### P0-2 · `CollaboratorShell` rebentava com null check · **FIXED** (`dc5a904`)
`[test]` — descoberto ao corrigir o P0-1; o fix do P0-1 sozinho crashava.

- **O que acontecia:** `collaborator_shell.dart:15` fazia
  `session.collaboratorId!` sobre a sessão de demonstração, que com Supabase
  ligado é sempre `manager` — cujo `collaboratorId` é `null`.
- **Causa-raiz:** a shell tirava a identidade do colaborador da sessão de
  demonstração, não da conta autenticada.
- **Fix:** `CollaboratorShell` aceita `collaboratorId` e `titulo`; o
  `AcessoGate` passa-lhe o id da conta autenticada
  (`AcessoService.utilizadorId`). Sem id nenhum mostra um estado explícito em
  vez de rebentar.
- **Teste:** mesmo ficheiro, grupo "CollaboratorShell sem colaborador
  associado".

### P0-3 · Calendário semanal de marcações rebentava a montar · **FIXED** (`d0af28a`)
`[test]` — apanhado pelo smoke da Fase 4.

- **O que acontecia:** `_WeekSlotRow` (`operational_pages.dart:1770`) usava
  `CrossAxisAlignment.stretch` dentro de um `SingleChildScrollView` vertical.
  Altura infinita + `stretch` = constraint apertada de altura infinita →
  `BoxConstraints.debugAssertIsValid` falha.
- **O que devia acontecer:** as células da linha ficam todas com a altura da
  mais alta, sem constraints inválidas.
- **Fix:** `IntrinsicHeight` à volta da `Row` — resolve a altura antes do
  `stretch`.
- **Teste:** `test/features/smoke/ecras_happy_path_test.dart`, "Marcações abre
  sem lançar", nos dois tamanhos de ecrã.

---

## P1 — dados errados, botão sem efeito, navegação partida

### P1-1 · Converter lead ignorava a validação de duplicados · **FIXED** (`d0af28a`)
`[cod]` `[test]` — fluxo 3.

- **O que acontecia:** `convertLead()` escrevia directamente no repositório,
  saltando o `addCustomer()` que valida telemóvel e NIF repetidos. Converter uma
  lead cujo telemóvel já era de um cliente criava um cliente duplicado sem uma
  palavra. Dois toques no botão criavam dois clientes.
- **Causa-raiz:** duas portas de entrada para criar cliente, só uma com regras.
- **Fix:** `convertLead()` verifica duplicados e é idempotente — converter a
  mesma lead outra vez devolve o cliente já criado. O botão "Converter" mostra
  a razão em SnackBar.
- **Teste:** `regressoes_v003_test.dart`, grupo P1-1 (3 testes).

### P1-2 · Editar máquina apagava a data de aquisição e desarquivava · **FIXED** (`d0af28a`)
`[cod]` — fluxo 4.

- **O que acontecia:** o diálogo construía um `Machine(...)` novo com o `id` do
  antigo. `acquiredOn` e `archived` não eram passados → ficavam nos valores por
  omissão. Editar uma máquina arquivada ressuscitava-a.
- **Fix:** usa `current.copyWith(...)` a editar; `Machine(...)` só a criar.
- **Teste:** coberto indirectamente pelo smoke; ver "dívida de teste" abaixo.

### P1-3 · Mudar o estado da máquina não tinha efeito · **FIXED** (`d0af28a`)
`[cod]` `[test]` — fluxo 4.

- **O que acontecia:** `updateMachineStatus()` gravava o estado escolhido e a
  seguir chamava `_syncMachineCycle()`, que o recalculava a partir das reservas
  e o punha logo para trás. Pôr em "disponível" uma máquina com reserva futura
  devolvia `true` e não mudava nada no ecrã.
- **Causa-raiz:** o ciclo automático de estados a correr também no caminho
  manual.
- **Fix:** o caminho manual não chama o ciclo. A guarda que impede "disponível"
  durante um aluguer a decorrer mantém-se.
- **Teste:** `regressoes_v003_test.dart`, grupo P1-3 (2 testes, incluindo a
  guarda que tinha de continuar a funcionar).

### P1-4 · Máquina parada ou em manutenção podia ser reservada · **FIXED** (`d0af28a`)
`[cod]` `[test]` — fluxo 5.

- **O que acontecia:** `addBooking()` validava conflitos e máquinas
  identificadas, mas não o estado. Como `_syncMachineCycle` nunca mexe em
  máquinas paradas, ficavam com reserva confirmada **e** marcadas como
  indisponíveis ao mesmo tempo.
- **Fix:** `addBooking()` recusa com `ArgumentError` e diz qual é a máquina e em
  que estado está.
- **Teste:** `regressoes_v003_test.dart`, grupo P1-6 (3 testes).

### P1-5 · Guardar marcação com erro de validação rebentava o ecrã · **FIXED** (`d0af28a`)
`[cod]` — fluxo 5.

- **O que acontecia:** `addBooking()` lança `ArgumentError` (duração mínima,
  máquina por identificar e agora máquina parada) e o `onPressed` do diálogo não
  apanhava nada. Excepção por tratar.
- **Fix:** `try/on ArgumentError` → SnackBar com a mensagem.
- **Teste:** o contrato do controlador está em `regressoes_v003_test.dart`,
  grupo P0-3. O `catch` da UI é `[cod]`, não coberto por teste — ver dívida.

### P1-6 · Guardar despesa/recebimento sem valor: botão morto · **FIXED** (`d0af28a`)
`[cod]` — fluxo 6.

- **O que acontecia:** `if (cents <= 0) return;` em dois sítios. O botão não
  fazia nada e não dizia porquê.
- **Fix:** SnackBar "Indica um valor superior a zero." Mesma coisa no botão de
  guardar máquina sem nome, que fechava o diálogo e deitava fora o que estava
  escrito.

### P1-7 · Botões cortados fora do ecrã em telemóvel · **FIXED** (`d0af28a`)
`[test]` — fluxos 3 e 4, só a 411 dp.

- **O que acontecia:** `_PageFrame` punha o `Wrap` de acções dentro de um `Row`.
  Um `Wrap` dentro de um `Row` recebe largura infinita e **nunca** quebra linha
  — os botões saíam do ecrã (overflow de 521 px em Clientes, 167 px em
  Máquinas).
- **Fix:** o cabeçalho passa a ser um `Wrap`, que dá ao `action` uma largura
  limitada e o deixa quebrar.
- **Bónus da mesma família:** a `CollaboratorShell` tinha seis botões de 76 dp
  numa `Column` fixa — estourava em janelas baixas (Windows, telemóvel em
  paisagem). Passou a `ListView`.
- **Teste:** todo o smoke da Fase 4 corre a 411×900 **e** 1280×800.

### P1-8 · Cartões do painel estouravam com rótulos longos · **FIXED** (`d0af28a`)
`[test]` — fluxo 8.

- **O que acontecia:** `_Metric` tem altura fixa (142) mas o rótulo é livre.
  "Colaboradores ativos / vagas" quebrava para três linhas e transbordava 34 px.
- **Fix:** `spaceBetween` em vez de `Spacer`, valor a uma linha e rótulo a duas,
  ambos com reticências.

---

## P2 — cosmético, fora do âmbito desta sprint

Ficam registados, **PENDING**, para a v0.0.4.

| # | Onde | O quê | Como |
|---|---|---|---|
| P2-1 | `finance_pages.dart` (categoria, método de pagamento), `operational_pages.dart:1188` (estado da lead), `collaborator_shell.dart` (estado da marcação) | Nomes de enum em inglês à vista do utilizador: `other`, `transfer`, `newLead`, `confirmed` | `[cod]` |
| P2-2 | `finance_pages.dart:20-23` | O cabeçalho diz "Este mês: X" mas a lista por baixo mostra tudo desde sempre | `[cod]` |
| P2-3 | `operational_pages.dart` `_leadDialog` | Controllers sem `dispose`; no `_customerDialog` faltam `address`, `postalCode`, `locality` | `[cod]` |
| P2-4 | `operations_controller.dart` `availableMachines` | Condição morta `state.machines.isNotEmpty` dentro do próprio `where` | `[cod]` |
| P2-5 | `Machine.copyWith` | `dailyRateCents ?? this.dailyRateCents` — limpar a diária não a limpa | `[cod]` |
| P2-6 | `collaborator_shell.dart` `_newLead` | Guardar com campos vazios não faz nada nem explica | `[cod]` |
| P2-7 | `collaborator_shell.dart` `_mine` | Lista as marcações sem nome de cliente nem máquina | `[cod]` |
| P2-8 | `operational_pages.dart` `ClientsPage` | Não há forma de **editar** um cliente depois de criado (o fluxo 3 pede) | `[cod]` → passou ao backlog v0.0.4 |

---

## Por verificar à mão — `[manual]`

Nada disto foi testado. Todos os edge cases que a sprint pedia e que precisam de
uma app a correr ficam aqui, por eliminar:

| # | Cenário | Fluxos |
|---|---|---|
| M-1 | Sem rede (modo avião) durante registo, login e sincronização | 1, todos |
| M-2 | Sessão expirada a meio de uma acção | 1, 5, 6 |
| M-3 | Dois cliques rápidos em Guardar (despesa, recebimento, máquina, marcação) — o `Navigator.pop` duplo pode fechar também o ecrã de baixo | 4, 5, 6 |
| M-4 | Rotação portrait ↔ landscape em Android | todos |
| M-5 | Onboarding deixando campos em branco → "Dados por completar" | 2 |
| M-6 | Histórico mensal: preencher um mês antigo e ver a comparação homóloga no painel | 9 |
| M-7 | Ciclo completo da reserva: confirmar → iniciar aluguer → concluir → cancelar | 5 |
| M-8 | Colaborador real (conta Supabase aprovada como `colaborador`) a criar lead e recebimento | 7 |
| M-9 | Os 9 fluxos de ponta a ponta em `flutter run -d windows` | todos |

**M-3 é o que mais me preocupa** dos que ficam: o padrão `Navigator.pop` sem
guarda de reentrância está em vários diálogos e não consegui reproduzi-lo em
teste de forma fiável.

---

## Fase 5 — smoke de RLS

**PENDENTE — por correr.** Escrito e pronto:
`supabase/tests/rls_smoke_isolamento_empresas.sql`.

Cria duas empresas com um utilizador cada, a Alice regista uma máquina e
verifica que o Bruno não a vê nem consegue escrever na empresa dela. Inclui
contraprova (a Alice tem de ver a sua própria máquina, senão um "não vê nada"
por a RLS bloquear tudo passava por sucesso). Corre inteiro dentro de uma
transacção que acaba em `rollback`.

Não foi executado: não há base de dados acessível a partir daqui e não foi
criado nenhum branch Supabase. **Se falhar, é P0 imediato.**

---

## Dívida de teste assumida

Coisas corrigidas cuja verificação é `[cod]` e não `[test]`:

- O `catch` de `ArgumentError` no diálogo de marcação (P1-5) — o contrato do
  controlador está testado, o `catch` da UI não.
- `copyWith` ao editar máquina (P1-2) — o diálogo é uma função de topo com
  muitos controllers; testá-lo a sério pedia refactor, que está fora do âmbito.
- P1-6/P1-7 nas partes que são SnackBar.

## Nota sobre o harness de teste

Duas coisas que **pareciam** bugs e não são:

1. Overflows a 800×600, o tamanho por omissão do `flutter_test`, que não é
   nenhum dos alvos reais. O smoke passou a correr a 411×900 e 1280×800.
2. `ClientsPage`, `MachinesPage` e `BookingsPage` devolvem `SafeArea` e contam
   com o `Scaffold` da shell. Montadas a seco rebentavam com "No Material widget
   found" — artefacto do teste.
