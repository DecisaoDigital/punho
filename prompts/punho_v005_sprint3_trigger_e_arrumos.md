# Punho v0.0.5 — sprint 3 (trigger push + veículos + página de métricas + estado/arquivar de máquinas)

> **Continua na branch `feat/v005-dashboard-alavancas`**. Ainda 0.0.5 ongoing:
> sem push da branch, sem bump de versão, sem APK.

Sete frentes independentes (a A ficou entregue à parte antes do resto do
sprint arrancar). Não há dependências entre elas — commit por frente, e se
uma bloquear as outras seguem.

---

## Frente A — Trigger DB: push ao Cesar quando entra um novo pedido Punho ✅ FEITO

**Aplicado a 27/07/2026, 02:26 UTC.** Ver secção `## Verificação` no fim de
`prompts/punho_notificar_novo_pedido.md`. Duas migrations aplicadas
(`20260727022420_punho_notificar_novo_pedido` +
`20260727022613_punho_notificar_novo_pedido_payload_edge_v8`) — a primeira
com o payload PT deste prompt caiu com 400 porque a `enviar-push` v8 exige
`title`/`body`/`data` em inglês e prefixa `[PUNHO]` no servidor. Segunda
migration corrigiu.

**Não voltar a mexer.** Salta esta frente e vai à B.

---

## Frente B — Bug bundle: `_vehicleDialog` tem os mesmos bugs que
`_collaboratorDialog` já teve

O Cesar apanhou o bug do diálogo "Novo colaborador" no smoke da 0.0.4
(`title` enganador, sem validação, `barrierDismissible` a fechar por acidente,
sem `autofocus`). Foi corrigido em `workforce_pages.dart` no
`_collaboratorDialog`. **O `_vehicleDialog` no mesmo ficheiro tem os mesmos
problemas** — corrigi-lo agora, antes do próximo smoke.

### O que mudar em `lib/features/workforce/presentation/workforce_pages.dart`

Dentro do `showDialog` do `_vehicleDialog` (linha ~239):

- `barrierDismissible: false` (evita fechar por engano sobre o teclado
  virtual).
- Título: `'Adicionar veículo'` (não "Novo veículo" — a Cesar leu isto como
  "veículo criado" nos colaboradores).
- No `TextField` da matrícula: `autofocus: true`,
  `textCapitalization: TextCapitalization.characters` (matrículas em maiúsculas).
- Validação antes de `Navigator.pop`:
  ```dart
  final matricula = plate.text.trim();
  if (matricula.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Indica a matrícula do veículo.')),
    );
    return;
  }
  ```
  Não valides formato AA-11-BB — pode ser matrícula estrangeira ou histórica.
  Só verificar não-vazio.

### Teste

Widget test em `test/features/workforce/vehicle_dialog_test.dart`:

- Tentar guardar sem matrícula → snackbar aparece, `saveVehicle` não é
  chamado.
- Guardar com matrícula preenchida → `Navigator.pop` acontece, `saveVehicle`
  é chamado com o valor.

---

## Frente C — `TodasMetricasPage` deixa de ser placeholder

Na sprint 1 ficou com `Placeholder()`. O doc promete "lista completa continua
a existir em TodasMetricasPage". Cumprir agora.

### Escopo

- Rebuild da página `lib/features/dashboard/presentation/todas_metricas_page.dart`
  com **as 17 métricas antigas** (dinheiro, pipeline, máquinas, custos,
  semana) + a comparação homóloga + a frase-da-semana — todas as que estavam
  no `Wrap` original.
- Layout: `ListView` com secções (`Dinheiro`, `Pipeline`, `Máquinas`,
  `Custos`, `Semana`, `Comparação com mês homólogo`). Cada métrica é uma
  linha compacta (título à esquerda, valor à direita, sub-linha se aplicável).
- **Não é o dashboard.** É a página que existe para o gestor consultar
  quando precisa do detalhe. Sem cores dramáticas, sem gráficos, sem
  carrossel. Sóbria e densa.
- Fonte dos dados: os mesmos KPIs puros já criados na sprint 1 — nunca
  duplicar cálculo.
- Se algum KPI devolve `null` → mostrar `Por apurar` em cinza (mesmo padrão
  do Slide 1).
- Link "Ver todas as métricas →" no fundo do Slide 4 fica funcional.
- Retorno da página com botão "Voltar" no `AppBar`.

### Testes

- Widget test: página lista as 17 métricas + as extras, mostra "Por apurar"
  quando os KPIs devolvem null, secções em ordem.
- Screenshot em `docs/design/screenshots/v005/todas_metricas.png`.

---

## Frente D — Máquinas: um só controlo de estado + arquivar seguro

Dois bugs de UX apanhados pelo Cesar no smoke da 0.0.5 na `MachinesPage`
(linha ~880 de `lib/features/operations/presentation/operational_pages.dart`).

### D1 — Chip é o único controlo de estado; "Parada" desaparece do menu

> "Criei uma máquina, ficou com botão Disponível ponto verde, à frente
> tem seta esquerda e direita. Essa função da seta devia ser do botão
> Disponível. As opções devem ser todas menos Parada. Se está parada e não
> está em manutenção, está disponível automaticamente."

Traduzindo o que ele viu:

- O "botão Disponível com ponto verde" é o `_MachineStatusChip`
  (linha ~919).
- As "setas" são o `PopupMenuButton` com ícone `Icons.swap_horiz`
  (linha ~942). Ele leu o `swap_horiz` como duas setas.
- Quando o estado é `stopped`, aparece um `TextButton.icon "▶ Disponível"`
  (linha ~921) — terceiro caminho para o mesmo fim.

**Três controlos para mudar de estado. Um chega.**

Fazer:

1. Envolver o `_MachineStatusChip` num `InkWell` com ripple.
2. `onTap` abre um `PopupMenu` alinhado ao chip com **quatro opções**:
   `Disponível`, `Reservada`, `Alugada`, `Em manutenção`. Sem `Parada`.
3. Apagar o `PopupMenuButton<MachineStatus>` do `swap_horiz`.
4. Apagar o `TextButton.icon("Disponível")` que aparece quando estado é
   `stopped`. A regra abaixo torna-o desnecessário.

**"Parada" deixa de ser observável para o utilizador:**

- Grep de `MachineStatus.stopped` em `lib/`. Cada site que hoje o *escreve*:
  se o significado era "não está a ser usada e não está em manutenção",
  substituir por `MachineStatus.available`. Se o significado era "arquivada
  / fora de serviço", isso já tem `machine.archived` — usar isso e não o
  enum.
- Projecção defensiva na leitura: `LocalDemoOperationRepository` e
  `PersistentOperationRepository` — ao ler máquinas, se `status == stopped`
  e a máquina não está em manutenção, projectar como `available` na leitura,
  e na próxima escrita corrigir na base.
- **Enum `MachineStatus` fica com `stopped` como membro** para não partir
  serialização legacy. `machineStatusLabel(stopped)` passa a devolver
  `'Disponível'` (mesmo label). Comentar no `domain/models/operations.dart`:
  "`stopped` está deprecated — mapear para `available` em qualquer
  interpretação nova".

Ajustar KPIs afectados: `maquinasParadasHaMaisDe(dias)` e similares — se
dependiam de `status == stopped`, passam a depender de `available &&
diasDesdeUltimoAluguer > N`. A regra do Cesar não desligou "está sem alugar
há X dias" (isso continua a ser sinal útil no Slide 3); só desligou o
*estado explícito* Parada. Grep também `MachineStatus.stopped` em `test/`
e actualizar fixtures.

### D2 — Arquivar máquina: confirmação + undo 6s + só gestor

> "Depois tens um ficheiro com seta para baixo, julguei que era para
> movimentar de sítio, afinal apagou a máquina. Não pode acontecer. Para
> apagar uma máquina tem de perguntar se quer mesmo apagar a máquina e
> ainda se disser ok são 6 segundos de espera para reverter a eliminação.
> Apenas admin pode eliminar máquinas."

O botão que ele descreve é o `IconButton(icon: Icons.archive_outlined)`
(linha ~971), que hoje chama `archiveMachine(m.id)` **directamente, sem
confirmação**. Está mal.

Fazer:

1. **Só gestor pode arquivar.** Ler `EstadoAcesso.eGestor` (já existe em
   `lib/features/auth/domain/estado_acesso.dart`) do provider adequado. Se
   `!eGestor`, o `IconButton` de arquivar **não aparece** na linha da
   máquina. No modo demo local (sem sessão Supabase), assumir gestor —
   senão o único perfil disponível fica sem acesso a nada.
2. **Trocar o ícone para caixote do lixo.** O Cesar leu o
   `Icons.archive_outlined` como "seta para baixo" e por isso tocou
   pensando que movia a máquina de sítio. Substituir por
   `Icons.delete_outline` (caixote do lixo aberto) com
   `tooltip: 'Eliminar máquina'`. O comportamento interno continua a ser
   soft-delete (chama `archiveMachine` — a máquina não é apagada da base,
   só marcada como `archived`), mas o utilizador vê e lê **"Eliminar"**
   em todo o lado (ícone, tooltip, título do diálogo, botão do diálogo,
   snackbar). "Arquivar" fica só como termo técnico interno.
3. **Diálogo de confirmação** antes de eliminar:
   ```
   Título: Eliminar máquina?
   Corpo:  "{nome}" vai desaparecer da lista. Podes reverter durante 6
           segundos depois de confirmares.
   Acções: [Cancelar] [Eliminar]
   ```
   `barrierDismissible: false`. Botão "Eliminar" com cor destrutiva
   (`FilledButton` sobre `colorScheme.error`, texto branco), claramente
   diferenciado do "Cancelar".
4. **Undo 6 segundos.** Depois de confirmar:
   - Executar `archiveMachine(m.id)` imediatamente (a máquina desaparece
     da lista, feedback instantâneo). Nota: o método interno mantém-se
     `archiveMachine` — é soft-delete, só a UI diz "Eliminar".
   - Mostrar `SnackBar` `'Máquina eliminada.'` com
     `duration: Duration(seconds: 6)` e acção `'Anular'`. Ao clicar
     "Anular", chamar `unarchiveMachine(m.id)` (adicionar ao controller)
     e mostrar novo snack curto `'Máquina restaurada.'`.
   - Se os 6 segundos passarem sem clique, a eliminação fica consolidada
     — nada mais a fazer.
5. **Novo método no controller:** `unarchiveMachine(String id)` — põe
   `archived = false`. Se o modelo não tiver a distinção entre "acabou de
   ser arquivada" e "estava arquivada há dias", tudo bem: o `unarchive` é
   idempotente e restaurar qualquer máquina arquivada é aceitável.

### Testes da Frente D

- Widget test da `MachinesPage`:
  - Ao carregar, chip é `InkWell` e o `swap_horiz` **não existe** na árvore.
  - Tap no chip abre popup com 4 opções (verifica que "Parada" **não**
    consta).
  - Selecção de "Em manutenção" chama `updateMachineStatus` com esse valor.
  - Perfil não-gestor: `IconButton` do caixote não existe na árvore.
  - Perfil gestor: tocar no caixote abre `AlertDialog` "Eliminar máquina?".
    Cancelar não chama `archiveMachine`.
  - Confirmar → `archiveMachine` chamado + `SnackBar` "Máquina eliminada."
    presente com acção "Anular". Tocar em "Anular" chama `unarchiveMachine`.
  - Verifica também que o `IconButton` usa `Icons.delete_outline` e tem
    tooltip "Eliminar máquina".
- Test do `_MachineStatusChip`: com `status: stopped`, o label rendido é
  `Disponível` e a cor é a verde.
- Test do repositório: carregar máquina persistida como `stopped` sem
  manutenção → depois de `load()`, `machine.status == available`.

---

---

## Frente E — Criar placeholders de máquinas a partir do onboarding

Se o gestor diz no onboarding "tenho 20 máquinas", a app **cria as 20
imediatamente** como placeholders editáveis, em vez de as deixar como um
contador abstracto. O gestor abre a Máquinas e vê 20 linhas prontas para
serem baptizadas aos poucos — a filosofia do próprio Cesar ("um gestor
com 200 máquinas não vai lá numerar e fotografar todas ao mesmo tempo").

### O que muda no modelo

- Novo campo booleano `Machine.placeholder` (default `false`, não-nullable
  na serialização — em máquinas antigas fica `false`).
- Uma máquina `placeholder: true` é uma máquina normal — pode ser alugada,
  reservada, tudo — mas assinala que ainda não foi editada pelo gestor.
- Assim que o gestor edita o nome (ou a categoria, ou a referência), o
  `saveMachine` **desliga** o flag: `placeholder = false`. Regra: qualquer
  escrita explícita pelo utilizador em `_machineDialog` põe
  `placeholder: false`, independentemente do que tenha mudado.

### Onde criar

- Novo método no controller:
  `criarPlaceholdersDeMaquinas({required int quantidade, int inicio = 1})`.
  Cria `quantidade` linhas com `name: 'Máquina {inicio + i}'`,
  `category: 'Por identificar'`, `reference: ''`,
  `status: MachineStatus.available`, `archived: false`, `placeholder: true`.
- `completeOnboarding` chama esse método com
  `quantidade = totalMachinesDeclared` **se e só se**
  `state.machines.isEmpty` (para não duplicar em re-onboardings). Isto
  substitui o antigo `insertMachinesNow` (que Code já hardcoded como
  `false`) no fluxo do arranque. O nome do parâmetro fica, mas passa a ser
  ignorado com uma nota "kept for API stability, superseded by placeholder
  auto-creation".
- No ecrã de Definições da Empresa (`company_settings_page.dart`), quando
  o gestor **aumenta** `totalMachinesDeclared` (por ex. de 20 para 25),
  chamar `criarPlaceholdersDeMaquinas(quantidade: 5, inicio: 21)`. Se
  **diminui**, **não apagar nada** — só actualizar o contador declarado
  e mostrar no snackbar: "Contador actualizado. As 20 máquinas
  existentes continuam disponíveis. Para eliminar máquinas, usa o
  caixote na lista de máquinas."

### O que muda na Máquinas (`MachinesPage`)

- Uma linha `placeholder: true` mostra o nome (`Máquina 7`) em cinza mais
  claro (tema secundário) e um pequeno chip `Por identificar` ao lado do
  `_MachineStatusChip`.
- Ordenar a lista com **placeholders no fim** — quem já identificou pelo
  menos algumas máquinas quer vê-las primeiro.
- Empty state actual do ecrã (se `machines.isEmpty`) fica na mesma,
  só que agora só aparece se o gestor tiver declarado `0` no onboarding.

### O que muda nas Tarefas

- Refinar a fonte `hasUnidentifiedDeclaredMachines`: agora conta
  `machines.where((m) => !m.archived && m.placeholder).length` em vez do
  delta `totalMachinesDeclared − registeredMachinesCount`. O delta ainda
  fica exposto no controller (útil para reconciliar contador declarado
  vs identificado real na página Definições), mas quem alimenta as
  Tarefas é a contagem de placeholders.
- Texto do item: `"{n} máquinas por identificar"` com CTA "Abrir Máquinas →".

### KPIs — atenção

- `topMaquinasMaisAlugadas`, `maquinasParadasHaMaisDe`, `ocupacaoMaquinasSemana`
  devem incluir placeholders nos cálculos se elas tiverem histórico de
  aluguer — quem alugou "Máquina 7" faturou dinheiro real. Nada a
  filtrar por `placeholder`.
- O único KPI que muda comportamento é o de tarefas por identificar,
  descrito acima.

### Testes

- Unit test do controller:
  - `completeOnboarding(totalMachinesDeclared: 20)` com estado vazio →
    `state.machines.length == 20`, todas com `placeholder: true`, nomes
    `Máquina 1` a `Máquina 20`, todas disponíveis.
  - `completeOnboarding(totalMachinesDeclared: 20)` com estado que já
    tem 3 máquinas → **não** cria placeholders (guard `machines.isEmpty`).
  - `saveMachine` de uma placeholder com nome alterado → resultado tem
    `placeholder: false`.
  - Aumentar `totalMachinesDeclared` de 20 para 25 via
    `updateCompanySettings` → 5 novas linhas com nomes `Máquina 21` a
    `Máquina 25`, `placeholder: true`. Diminuir para 15 → contador muda,
    máquinas ficam intactas.
- Widget test da `MachinesPage`:
  - Lista com 3 identificadas + 2 placeholders → identificadas em cima,
    placeholders no fim; chip `Por identificar` só nas placeholders.
- Widget test da `TarefasPage`:
  - Fixture com 4 placeholders → aparece linha "4 máquinas por identificar"
    e o CTA leva à Máquinas.

### Migração

- Repositório persistente: ao ler máquinas com formato antigo (sem o
  campo), definir `placeholder = false`. Simples e defensivo.

---

## Frente F — `_machineDialog` mais largo e melhor aproveitado

Hoje o diálogo de adicionar/editar máquina é um `AlertDialog` estreito com
seis campos + gestão de fotografias empilhados numa `Column` scrollável.
São muitos campos e o formato apertado torna o preenchimento incómodo,
sobretudo em tablet/PC landscape (o formato principal do Punho).

### O que muda em `_machineDialog` (linha ~1076 de `operational_pages.dart`)

1. **Trocar `AlertDialog` por `Dialog`** com `child: SizedBox`:
   - `width: min(920, MediaQuery.of(context).size.width * 0.85)`.
   - `height: min(640, MediaQuery.of(context).size.height * 0.85)`.
   - Padding interno generoso (`EdgeInsets.all(24)`).
2. **Layout de duas colunas em landscape:**
   - Detectar via `MediaQuery.orientation == Orientation.landscape`.
   - Landscape: `Row` com duas `Expanded` colunas separadas por 24 dp.
     - **Coluna esquerda (metadados):** Nome, Referência, Categoria,
       Preço diário. Cada `TextField` com `filled: true` e mais respiração.
     - **Coluna direita (contexto):** Notas (agora `maxLines: 6`,
       `minLines: 4`, cresce), depois a área de fotografias herdada como
       está — mas as thumbnails passam de 78 dp a 112 dp para se lerem.
   - Portrait (raro, só shell colaborador): mantém `Column` scrollável
     como hoje, mas com o mesmo `Dialog` largo (portrait em telemóvel
     ocupa a largura toda).
3. **Cabeçalho fixo, corpo scrollável, rodapé fixo:**
   - Cabeçalho: título (`'Nova máquina'` ou `'Editar máquina'`) + fecho `×`.
   - Corpo em `Expanded` com `SingleChildScrollView` — as duas colunas
     scrollam juntas.
   - Rodapé com `Cancelar` (`TextButton`) + `Guardar` (`FilledButton`)
     alinhados à direita, sempre visíveis (não são "roubados" pelo
     scroll das fotografias).
4. **`barrierDismissible: false`** — evitar perder os dados por engano.
5. **Validação antes de fechar:**
   - Nome não pode ficar vazio: se estiver, `ScaffoldMessenger` diz
     `'Indica o nome da máquina.'` e o `Navigator.pop` não acontece.
   - Focar automaticamente o `TextField` do nome ao abrir
     (`autofocus: true`), a menos que estejamos a editar uma máquina que
     já tenha nome — nesse caso `autofocus` fica na Categoria.

### Regras de disciplina (Frente F ↔ resto do sprint)

- **Não** adicionar selector de estado ao diálogo. Frente D deixa o estado
  a começar em `available` na criação; o gestor muda pelo chip da lista.
  (Fica para v0.0.6 se se justificar depois de smoke.)
- Se estiveres a editar uma máquina `placeholder: true` (Frente E), o
  botão `Guardar` deve dizer `'Guardar e identificar'` em vez de
  `'Guardar'` — deixa claro ao gestor que aquela edição desliga o
  estado "por identificar" (e assim é: o `saveMachine` põe
  `placeholder: false` sempre que vem do diálogo).

### Testes

- Widget test do diálogo em landscape:
  - Duas `Expanded` colunas visíveis.
  - Botões `Cancelar` e `Guardar` visíveis mesmo sem fazer scroll.
  - Guardar sem nome → snackbar aparece e o diálogo continua aberto.
- Widget test em portrait: uma só coluna, tudo scrollável.
- Widget test editando placeholder → texto do botão é
  `'Guardar e identificar'`. Após guardar, `saveMachine` é chamado com
  `placeholder: false`.
- Screenshot novo:
  `docs/design/screenshots/v005/dialogo_maquina_largo.png` (landscape,
  duas colunas, com uma foto no lado direito).

---

## Frente G — `BookingsPage` (Reservas): aproveitar o ecrã e encurtar rótulos

Hoje a `BookingsPage` empilha, por esta ordem:

1. `_CalendarToolbar` — navegação de período + semana/mês.
2. `SizedBox(12)`.
3. `_MachineReservationSelector` — **faixa horizontal de altura 64 dp**
   com `ChoiceChip`s de 128 dp por máquina; obriga a scroll horizontal
   quando há muitas máquinas.
4. `SizedBox(10)`.
5. Uma linha de texto contextual ("Escolhe uma máquina…", ou o resumo
   da selecção).
6. `SizedBox(10)`.
7. `Expanded` com o calendário.

O calendário — a peça central — só recebe o que sobra depois de tudo isto.
Em tablet/PC landscape (o formato principal) o resultado é o que o Cesar
descreveu: **"a informação ocupa muito mal o espaço"**.

### Rótulos

1. Título da página: `'Marcações / Reservas'` → `'Reservas'`. Reservar já
   é marcar. Grep também `'Reservas'` no sidebar (`app_shell.dart`) para
   garantir consistência.
2. Botão action `FilledButton.icon` (linha ~1620): rótulo passa de
   `'Adicionar reserva'` → `'Reservar'`. Quando há selecção múltipla,
   passa de `'Adicionar (${_selectedSlotStarts.length})'` →
   `'Reservar (${_selectedSlotStarts.length})'`.

### Layout

3. **`_MachineReservationSelector` deixa de ser faixa horizontal.**
   Substituir por um único controlo compacto no topo, integrado na
   toolbar:
   - `DropdownButton<Machine>` (ou `MenuAnchor`/`SearchAnchor` se a
     lista for grande) com o nome + estado da máquina seleccionada.
   - Largura fixa razoável (`SizedBox(width: 240)`), altura da toolbar.
   - Se `machines.isEmpty`: dropdown desactivado com texto "Sem máquinas"
     em vez do actual `Text` de fallback.
4. **Toolbar única de uma linha** (`Row` com `Wrap` responsivo):
   `‹ [Período] › · [Semana|Mês] · [Máquina ▾] · ... · [Reservar]`.
   Nada em segunda linha em landscape; em portrait mantém `Wrap` que
   já existe.
5. **Texto contextual vira chip fino sob a toolbar** (não linha própria
   com `SizedBox` 10 dp em cima e em baixo). Um `Container` com padding
   pequeno e fundo `surfaceContainerHigh`, altura ≤ 32 dp. Se não há
   texto contextual, o chip **não aparece** (nada de `SizedBox` fantasma).
6. **Calendário ganha altura.** Depois destas mudanças, o `Expanded`
   passa a receber todo o espaço restante. Verifica que a semana com
   slots horários tem cada slot legível (não colado ao vizinho); se
   sobrar altura de mais, dar um limite superior de célula (por ex.
   `72 dp`) e distribuir o resto como padding.

### Fora do âmbito

- Não redesenhar o calendário em si (mês/semana view) — só limpar o que
  o rodeia.
- Não mudar o fluxo `_showCalendarBookingConfirmation` — só o rótulo do
  botão que o chama.
- Não mexer no ecrã de reserva do colaborador (`collaborator_shell.dart`).

### Testes

- Widget test da `BookingsPage`:
  - `AppBar` (ou `_PageFrame` title) mostra `'Reservas'`.
  - Botão principal mostra `'Reservar'` sem selecção e
    `'Reservar (2)'` com dois slots seleccionados.
  - `_MachineReservationSelector` (chips 64 dp) **não** existe na árvore.
  - Existe um `DropdownButton` (ou equivalente) com as máquinas.
  - O `Expanded` do calendário ocupa a fatia maior da altura
    disponível (testar com `find.byType(Expanded)` e comparar `size` do
    calendário vs toolbar).
- Screenshot novo:
  `docs/design/screenshots/v005/reservas_landscape.png` — mostra o
  calendário a ocupar >60% do ecrã, toolbar compacta em cima.

---

<!-- Frentes H e I movidas para punho_v005_sprint4_ux_smoke.md.

## Frente H — Onboarding passo 1: sub-texto fora de contexto

Ecrã actual (`_OnboardingPageState`, `helpsFull[0]`):

```
1 de 12
Como te chamas?
O Punho orienta a pessoa responsável por decidir e agir na empresa.
[ Nome ]
[ Continuar ]
```

O Cesar apontou: **"que raio de frase é aquela para quem vai entrar na
empresa e estamos a perguntar o nome?"** — a sub-linha é o pitch do
produto, não é ajuda ao preenchimento do campo. Não pertence aqui.

### O que fazer

1. **Remover o sub-texto do passo 1.** O `TextField` "Nome" já é
   auto-explicativo com a pergunta "Como te chamas?" em cima. Menos texto
   = menos ruído.
2. **Rever os 12 sub-textos** (`helpsFull` e `helpsColab`) com este
   critério: o sub-texto só existe se **ajuda a preencher aquele campo
   concreto**. Se é filosofia, missão do produto ou motivação, sai. Se
   é meta (o que vem a seguir), sai. Se explica o formato esperado
   ("Podes usar iniciais ou nome completo"), fica.
3. **Ao esvaziar o sub-texto**, o widget do frame não pode deixar um
   `SizedBox` fantasma no lugar — colapsar de facto para não abrir buraco.

Casos concretos a rever (com sugestão, o Code pode ajustar):

| Passo | Actual | Proposta |
|---|---|---|
| 1 · Nome | *pitch* | (vazio) |
| 2 · Empresa | ver actual | Se for pitch, remover; senão manter |
| 3 · Cargo | ver actual | Manter se explica escolha; remover se é motivação |
| ... | ... | Aplicar mesmo critério |

Reportar no doc que sub-textos ficaram, com uma frase por cada, para
podermos confirmar. **Não** apagar todos por sistema — só os que não
ajudam ao preenchimento.

### Testes

- Widget test do passo 1: sub-texto **não** existe na árvore; o
  `TextField` "Nome" aparece logo por baixo da pergunta.
- Widget test dos 12 passos: nenhum sub-texto contém as palavras
  "orienta", "responsável", "decidir", "agir", "Punho" (heurística
  simples para apanhar pitch).

---

## Frente I — Diálogos em portrait quando o teclado abre

O Cesar mostrou uma captura da `Novo veículo` em telemóvel portrait: o
teclado tapa quase todo o diálogo, só se vê o título e o botão "Guardar".
**Nenhum campo é visível.** Impossível preencher.

O `AlertDialog` padrão do Flutter não sabe subir automaticamente acima do
teclado — o `insetPadding` fica com o valor `default` e o diálogo continua
centrado no viewport *original*, sem descontar `MediaQuery.viewInsets.bottom`.

### O que fazer

Aplicar a **três diálogos** com muitos campos:
- `_vehicleDialog` (`workforce_pages.dart`)
- `_collaboratorDialog` (`workforce_pages.dart`) — mesmo problema
- `_machineDialog` (`operational_pages.dart`) — já em conversão para
  `Dialog` largo pela Frente F; usar o mesmo insetPadding aqui também

Padrão comum:

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Dialog(
      insetPadding: EdgeInsets.only(
        left: 16, right: 16, top: 24,
        bottom: viewInsets.bottom + 16, // ← sobe acima do teclado
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 920 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height -
                     viewInsets.bottom - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* cabeçalho fixo */,
            Expanded(child: SingleChildScrollView(child: /* campos */)),
            /* rodapé fixo com Cancelar / Guardar */,
          ],
        ),
      ),
    );
  },
);
```

Pontos-chave:
- **`insetPadding.bottom` = `viewInsets.bottom + 16`** — o diálogo sobe
  quando o teclado abre.
- **`maxHeight` desconta `viewInsets.bottom`** — o `Expanded` interior
  não fica atrás do teclado.
- **`SingleChildScrollView` interior** — se o utilizador focar um campo
  que caiu debaixo do teclado, o `Scrollable.ensureVisible` do Flutter
  leva-o à vista.
- **Cabeçalho + rodapé fixos** — Cancelar/Guardar sempre acessíveis; o
  Cesar no telemóvel só via "Guardar" porque o resto tinha caído fora do
  ecrã.

O `_vehicleDialog` já vai receber título "Adicionar veículo", validação e
`autofocus` pela Frente B; esta Frente I sobrepõe-se ao `showDialog` em si
(passa de `AlertDialog` a `Dialog` com o padrão acima). Combinar as duas
mudanças num só commit por diálogo.

### Testes

- Widget test em portrait com teclado simulado (`FakeMediaQuery` com
  `viewInsets.bottom = 320`):
  - `_vehicleDialog`: cabeçalho ("Adicionar veículo") **e** rodapé
    ("Guardar") ficam ambos visíveis; os campos são scrolláveis.
  - `_collaboratorDialog`: idem.
- Widget test em landscape sem teclado: `_machineDialog` continua com o
  layout de duas colunas da Frente F, sem regressão.
- Screenshot novo:
  `docs/design/screenshots/v005/dialogo_veiculo_portrait_teclado.png`
  (portrait, teclado a ocupar metade inferior, diálogo com cabeçalho +
  1-2 campos + botões visíveis).

-->

---

## Não fazer nesta sprint

- Nada de bump ou push da branch.
- Nada de commitar o `pubspec 0.0.4+4` nem o `build.gradle.kts` que ficaram
  da tarefa anterior — continuam à espera de decisão do Cesar.
- Não mexer no Slide 1 (foi refinado na sprint 2 que está a decorrer em
  paralelo; se ela também for entregue antes desta, respeita o que veio de
  lá — só mexe se houver conflito directo).
- Não tentar validar recepção FCM no telemóvel do Cesar — Control 1.8.1
  ainda não está instalada.
- Não remover `stopped` do enum (partiria backups e séries antigas).
- Não mexer em `machine.archived` como conceito — só adicionar `unarchive`.

---

## Gate

1. `flutter test` verde, contagem antes/depois no report.
2. `flutter analyze` limpo.
3. Frente A: `status_code` do `net._http_response` no report.
4. Frente D: `grep -rn 'MachineStatus.stopped' lib/` — reporta as ocorrências
   que ficaram (esperado: só definição do enum, label deprecated, projecção
   defensiva do repositório).
5. Screenshots novos:
   - `docs/design/screenshots/v005/todas_metricas.png`
   - `docs/design/screenshots/v005/maquinas_lista_chip_clicavel.png` (linha
     com o chip verde e o popup aberto com 4 opções).
   - `docs/design/screenshots/v005/maquinas_confirmar_eliminar.png` (diálogo
     "Eliminar máquina?" aberto, com botão vermelho).
6. Frente E: adicionar screenshot
   `docs/design/screenshots/v005/maquinas_com_placeholders.png` (lista com
   identificadas em cima e 5 placeholders no fim com o chip
   "Por identificar").
7. Frente F: adicionar screenshot
   `docs/design/screenshots/v005/dialogo_maquina_largo.png` (diálogo landscape
   em duas colunas com uma foto do lado direito).
8. Frente G: adicionar screenshot
   `docs/design/screenshots/v005/reservas_landscape.png` (calendário
   dominante, toolbar compacta com dropdown de máquina).
9. Doc `docs/design/punho_v005_dashboard.md` — appendar secção "Sprint 3:
   trigger push + veículos + TodasMetricasPage + máquinas (estado, eliminar,
   placeholders do onboarding e diálogo largo) + Reservas (layout e
   rótulos)".

## Entrega

Continua em `feat/v005-dashboard-alavancas`. 7 commits, um por Frente.
Report frente a frente, com o `status_code` da chamada de sonda da A.
