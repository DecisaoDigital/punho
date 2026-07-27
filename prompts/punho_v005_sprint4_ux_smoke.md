# Punho v0.0.5 — sprint 4 (UX bugs do smoke + fecho da 0.0.5)

> **Continua na branch `feat/v005-dashboard-alavancas`**. **Esta é a sprint
> de fecho da 0.0.5:** depois das Frentes A–D, faz Frente E (release).
> Bump, push, tag e APK.

Quatro frentes de UX (bugs apanhados pelo Cesar a usar a app depois da
sprint 2) + uma frente de release para fechar a 0.0.5. Frentes A-D
independentes — commit por frente. Frente E vem sempre no fim.

Assume que a sprint 3 pode ainda não estar entregue quando o Code chega
aqui. Onde houver sobreposição (Frente A abaixo estende a Frente G da
sprint 3; Frentes B e C tocam nos mesmos diálogos da Frente B/F da sprint
3), **fundir com o que já lá está** em vez de reescrever. Se sprint 3 já
correu, aplicar em cima; se ainda não correu, aplicar isolado e ela
depois faz merge.

---

## Frente A — Reservas: semana visível de relance, sem scroll

**Problema (screenshot do Cesar):** com a "Semana" seleccionada só se
vêem 5 dias e uma linha ("Manhã") + fim de mais uma célula cortada; o
selector de máquinas ocupa faixa horizontal com scroll; a linha
"Ainda não existem máquinas identificadas." + "Escolhe uma máquina para
marcar os períodos livres." rouba mais duas linhas. O gestor não vê a
semana toda de relance.

A **Frente G da sprint 3** já refaz a toolbar (título "Reservas",
botão "Reservar", selector `DropdownButton`, chip contextual fino).
Esta frente **estende essa mudança** com regras específicas para o
`_WeekBookingsCalendar` propriamente dito.

### O que fazer no `_WeekBookingsCalendar`

1. **7 colunas visíveis simultaneamente** (Seg → Dom), sem scroll
   horizontal. Hoje o 7º dia sai da vista.
2. **Duas linhas** (Manhã / Tarde) **ambas visíveis**. Cada linha
   partilha 50% da altura do calendário via `Expanded`. Se no futuro
   isto virar 3 (Manhã/Tarde/Noite) ou N horas, dividir por N — nunca
   deixar cair para altura fixa que force scroll vertical.
3. **`_WeekBookingsCalendar` não pode ter scroll** — a semana tem de
   caber por completo em tablet e telemóvel landscape (o formato
   principal). Se o conteúdo excede o espaço, reduzir densidade visual
   (padding, tamanho de ícone) — não introduzir scroll.
4. Cada célula: `Center` com ícone `+` de 24 dp; bordas discretas
   (raio ≤ 8 dp), sem os "cartões" arredondados gigantes actuais. Se
   sobrar espaço, distribuir como padding — não fazer o ícone crescer
   além do razoável.
5. Cabeçalho da coluna com altura fixa `≤ 48 dp`. Uma linha se possível
   ("Seg 27/7" em vez de "Seg\n27/7").
6. `AspectRatio` da célula fica **livre** — objectivo é caber tudo,
   não manter proporção quadrada.

### Testes

- Widget test em landscape 1280×800 (tablet típico):
  - Todas as 7 colunas (Seg…Dom) presentes na árvore visível — verificar
    via `find.text('Seg')` até `find.text('Dom')`.
  - Ambas as linhas Manhã e Tarde presentes.
  - Nenhum `Scrollable` no subtree do calendário retorna
    `hasClients && position.maxScrollExtent > 0` (i.e., sem scroll
    activo).
- Screenshot novo:
  `docs/design/screenshots/v005/reservas_semana_sem_scroll.png` — semana
  completa de Seg a Dom, Manhã e Tarde, tudo à vista.

---

## Frente B — Onboarding passo 1: sub-texto fora de contexto

**Problema (screenshot do Cesar):**

```
1 de 12
Como te chamas?
O Punho orienta a pessoa responsável por decidir e agir na empresa.
[ Nome ]
[ Continuar ]
```

O Cesar apontou: **"que raio de frase é aquela para quem vai entrar na
empresa e estamos a perguntar o nome?"** A sub-linha é o pitch do
produto, não é ajuda ao preenchimento. Não pertence aqui.

### O que fazer

1. **Remover o sub-texto do passo 1** (`_OnboardingPageState`,
   `helpsFull[0]`). A pergunta "Como te chamas?" já é auto-explicativa.
2. **Rever os 12 sub-textos** (`helpsFull` e `helpsColab`) com este
   critério: o sub-texto só existe se **ajuda a preencher aquele campo
   concreto**. Se é filosofia, missão do produto ou motivação, sai. Se é
   meta ("no próximo ecrã vamos…"), sai. Se explica formato esperado
   ("podes usar iniciais ou nome completo"), fica.
3. **Ao esvaziar um sub-texto**, o `_PageFrame` não pode deixar
   `SizedBox` fantasma no lugar — colapsar de facto para não abrir
   buraco entre a pergunta e o campo.

Reportar no doc que sub-textos ficaram, com a versão final de cada, para
podermos confirmar. **Não** apagar todos por sistema — só os que não
ajudam ao preenchimento.

### Testes

- Widget test do passo 1: sub-texto **não** existe na árvore; o
  `TextField` "Nome" aparece logo por baixo da pergunta.
- Widget test heurístico dos 12 passos: nenhum sub-texto contém as
  palavras "orienta", "responsável", "decidir", "agir", "Punho" (apanha
  pitch a fugir).
- Screenshot novo:
  `docs/design/screenshots/v005/onboarding_passo1_limpo.png`.

---

## Frente C — Diálogos em portrait: teclado tapa quase tudo

**Problema (screenshot do Cesar):** a `_vehicleDialog` em telemóvel
portrait com teclado aberto — só se vê o título "Novo veículo" e o botão
"Guardar". **Zero campos.** Impossível preencher.

O `AlertDialog` do Flutter não sobe automaticamente acima do teclado:
o `insetPadding` fica com o `default` e o diálogo continua centrado no
viewport *original*, sem descontar `MediaQuery.viewInsets.bottom`.

### Diálogos afectados

- `_vehicleDialog` em `lib/features/workforce/presentation/workforce_pages.dart`
- `_collaboratorDialog` no mesmo ficheiro (mesmo problema, com ou sem
  captura)
- `_machineDialog` em `lib/features/operations/presentation/operational_pages.dart`

Se a Frente F da sprint 3 já converteu o `_machineDialog` para `Dialog`
largo, esta frente **reaproveita esse padrão** para os outros dois e
adiciona o `insetPadding` responsivo aos três.

### Padrão comum

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Dialog(
      insetPadding: EdgeInsets.only(
        left: 16, right: 16, top: 24,
        bottom: viewInsets.bottom + 16, // sobe acima do teclado
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
            /* cabeçalho fixo com título + fecho × */,
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

- **`insetPadding.bottom = viewInsets.bottom + 16`** — o diálogo sobe
  quando o teclado abre.
- **`maxHeight` desconta `viewInsets.bottom`** — o `Expanded` interior
  não fica atrás do teclado.
- **`SingleChildScrollView` interior** — se o utilizador focar um campo
  que caiu debaixo do teclado, o `Scrollable.ensureVisible` do Flutter
  leva-o à vista.
- **Cabeçalho + rodapé fixos** — Cancelar/Guardar sempre acessíveis
  (era essa a razão de o Cesar só ter visto "Guardar" na captura).

### Testes

- Widget test em portrait com teclado simulado (`FakeMediaQuery` com
  `viewInsets.bottom = 320`):
  - `_vehicleDialog`: cabeçalho ("Adicionar veículo") **e** rodapé
    ("Guardar") ficam ambos visíveis; os campos são scrolláveis.
  - `_collaboratorDialog`: idem.
  - `_machineDialog`: idem (mesmo em portrait, uma coluna).
- Widget test em landscape sem teclado: os três continuam sem regressão
  em relação à Frente F da sprint 3.
- Screenshot novo:
  `docs/design/screenshots/v005/dialogo_veiculo_portrait_teclado.png`
  (portrait, teclado a ocupar metade inferior, diálogo com cabeçalho +
  1-2 campos visíveis + botões).

---

## Frente D — Funcionários: editar, eliminar e mostrar vendas do mês

O Cesar apanhou dois problemas ao usar a `CollaboratorsPage`
(`lib/features/workforce/presentation/workforce_pages.dart`, linha ~6):

1. **"Criei um funcionário, o ordenado foi a zeros, como é que eu agora
   edito para colocar sobrenome e novo valor de ordenado?"** — o `ListTile`
   de cada colaborador **não tem botão nenhum**. Só existe "Adicionar
   colaborador" no topo. Está partido de raiz: não há forma de corrigir
   um dado errado nem de tirar da lista uma pessoa que já não trabalha lá.
2. **"Ter vendas feitas este mês — não seria também um bom sítio para se
   ver essa info?"** — hoje a linha só mostra estado + custo mensal +
   custo/hora. Falta o rendimento que o colaborador **traz**.

### D1 · Editar colaborador

- Cada linha ganha um `IconButton` `Icons.edit_outlined` com
  `tooltip: 'Editar colaborador'` à direita, antes do caixote.
- Ao tocar, abre o mesmo `_collaboratorDialog` **em modo edição** —
  aceita um `Collaborator? current` (à imagem do que o `_machineDialog`
  já faz) e pré-preenche todos os `TextEditingController`s.
- Título passa a `'Editar colaborador'` quando `current != null`.
- Ao guardar, chama `saveCollaborator` com o **mesmo `id`** para
  actualizar em vez de criar.
- Tocar no `ListTile` (fora dos botões) também abre o diálogo em edição
  — atalho comum e evita que o gestor "descubra" o ícone.

### D2 · Eliminar colaborador (mesmo padrão da Frente D da sprint 3)

- Só gestor vê o botão (`EstadoAcesso.eGestor`).
- Ícone `Icons.delete_outline` com `tooltip: 'Eliminar colaborador'`.
- Diálogo de confirmação:
  ```
  Título: Eliminar colaborador?
  Corpo:  "{nome}" vai desaparecer da lista. As reservas em que ficou
          registado como responsável mantêm o nome (snapshot). Podes
          reverter durante 6 segundos.
  Acções: [Cancelar] [Eliminar]
  ```
  Botão "Eliminar" sobre `colorScheme.error`.
- `barrierDismissible: false`.
- Ao confirmar: chamar `archiveCollaborator(c.id)` (adicionar ao
  controller — soft-delete via `archived = true`) e mostrar `SnackBar`
  `'Colaborador eliminado.'` com acção `'Anular'` (duration 6 s) que
  chama `unarchiveCollaborator(c.id)`.
- A `CollaboratorsPage` filtra `where((c) => !c.archived)`, à imagem do
  que a `MachinesPage` já faz.

Já existe o campo `archived` no `Collaborator` (`workforce.dart`
linha 32); só falta usá-lo aqui e adicionar os dois métodos ao
controller.

### D3 · Vendas deste mês por colaborador

- Novo KPI puro em `lib/core/operations/kpis.dart` (ou ficheiro próprio
  `vendas_por_colaborador.dart` se preferires):
  `vendasDoMesDoColaborador(String colaboradorId, {required DateTime now,
  required List<Booking> bookings})`. Devolve
  `({int contagem, int? valorCents})`:
  - `contagem` = número de bookings deste mês (`startsAt` no mês de
    `now`) com `collaboratorResponsibleId == colaboradorId` e
    `status ∈ {confirmed, completed}` — não contar `cancelled` nem
    `pending`.
  - `valorCents` = soma de `expectedValueCents` das mesmas bookings; se
    todas tiverem `expectedValueCents == null`, devolver `null` e a UI
    mostra apenas a contagem.
- A `CollaboratorsPage` passa a `ConsumerWidget` que já lê
  `state.bookings` e mostra na linha, como sub-linha adicional:
  - `'{contagem} reservas este mês · {valor} €'` se há valor
  - `'{contagem} reservas este mês'` se o valor é `null`
  - `'0 reservas este mês'` para colaboradores sem actividade no mês
- Mantém o `trailing` actual do "Resultado atribuível não é lucro
  contabilístico" — a nova linha vai no `subtitle` (ficando duas linhas).

### Testes

- Unit test `vendasDoMesDoColaborador`:
  - Fixture com 3 bookings do colaborador (2 confirmed, 1 cancelled, 1
    pending) — só as duas confirmed contam. Uma tem valor, outra `null`
    — `valorCents` reflecte só a com valor.
  - Fixture com todos `null` → `valorCents` retorna `null`.
  - Fixture com `startsAt` no mês passado → não conta.
- Widget test da `CollaboratorsPage`:
  - Existe `IconButton` de editar em cada linha; tocar abre diálogo com
    campos pré-preenchidos.
  - Perfil gestor: existe caixote; tocar abre confirmação "Eliminar
    colaborador?"; confirmar chama `archiveCollaborator` + snackbar com
    "Anular"; anular chama `unarchiveCollaborator`.
  - Perfil não-gestor: caixote não existe.
  - Sub-linha mostra `'{n} reservas este mês'` para o colaborador de
    fixture.
- Screenshots novos:
  - `docs/design/screenshots/v005/funcionarios_com_editar_e_vendas.png`
  - `docs/design/screenshots/v005/funcionarios_confirmar_eliminar.png`

### Fora do âmbito

- Não implementar "editar reservas do colaborador" nem "reatribuir
  reservas" quando eliminado — as reservas mantêm o `collaboratorNameSnapshot`
  e o histórico não é reescrito.
- Não substituir o `_collaboratorDialog` por diálogo largo agora — a
  Frente C desta sprint já vai levantá-lo acima do teclado; a
  refactorização para duas colunas fica para 0.0.6 se se justificar.

---

## Frente E — Release 0.0.5

Depois de A-D verdes, é a hora de cortar a 0.0.5. **Só arrancar esta
frente se A-D estiverem entregues, `flutter test` e `flutter analyze`
limpos, e todos os screenshots gerados.**

### E1 · Commitar TUDO o que está por commitar

**O Cesar autorizou: manda commitar todos os ficheiros pendentes,
incluindo o trabalho aberto de outras frentes (captura de comprovativos,
QR AT, etc.).** Nada fica em `git status` no fim.

Passos:

1. `git status` completo — reportar a lista antes de tocar.
2. Agrupar em commits por tema (não é um só commit gigante):
   - `chore(build): consolidar build.gradle.kts + pubspec da 0.0.4`
   - `feat(comprovativos): captura de comprovativos (WIP consolidado)`
   - `feat(at): QR AT (WIP consolidado)`
   - `chore(misc): restantes pendências` — para o que não encaixar
3. Cada commit descreve o que consolidou. Se um bloco WIP não compila ou
   tem `TODO:` óbvios, **isso vai na mensagem do commit** para não se
   perder ("WIP: parseamento de QR ainda incompleto, ver TODO no
   ficheiro X").
4. **Só depois de `git status` estar limpo** avança para E2.

Se durante o `git status` encontrares algo que claramente não devia ser
commitado (chaves, tokens, ficheiros de build, backups locais), parar e
reportar antes de decidir.

### E2 · Bump da versão

- `pubspec.yaml`: `0.0.4+4` → `0.0.5+5`.
- Commit: `chore(release): bump 0.0.5+5`.

### E3 · Merge da branch em main (local)

- `git checkout main`
- `git merge --no-ff feat/v005-dashboard-alavancas` (preservar história
  do trabalho da 0.0.5 sob um único merge commit).
- Mensagem do merge: `release: v0.0.5 — dashboard alavancas`.

### E4 · Tag

- `git tag -a v0.0.5 -m "Punho v0.0.5 — dashboard alavancas + fixes
  smoke"`.

### E5 · Push (branch + main + tag)

- `git push origin feat/v005-dashboard-alavancas`
- `git push origin main`
- `git push origin v0.0.5`

Pede autorização ao Cesar antes deste push — é o primeiro push desta
frente. O resto pode ir sem parar.

### E6 · APK release + GitHub Release

Seguir o fluxo automatizado que já está montado no repo (task Cowork #137
do POS foi o modelo; verificar se o Punho já tem workflow análogo em
`.github/workflows/`):

- Se **há** workflow: a tag `v0.0.5` dispara build + release. Verificar
  no GitHub Actions e reportar link do release.
- Se **não há** workflow: gerar localmente com `flutter build apk
  --release` e criar release manualmente no GitHub (`gh release create
  v0.0.5 build/app/outputs/flutter-apk/app-release.apk --title "Punho
  v0.0.5" --notes-file notas_v005.md`). Registar no doc que o workflow
  fica pendente para uma iteração de higiene técnica.

Preparar `notas_v005.md` (`docs/release_notes/v005.md`) com resumo
condensado do que entrou:

- **Dashboard novo**: carrossel de 5 slides landscape × 4 KPIs, sidebar
  88 dp com labels, novo destino Tarefas.
- **Slide Dinheiro**: hero "Recebido este mês" com sparkline + setas
  ‹ › mês nos KPIs temporais; card "Recomendação do dia" com bordo
  por gravidade.
- **Convites Punho** aparecem em Tarefas.
- **Máquinas**: chip de estado clicável; "Parada" deixa de ser opção;
  botão eliminar (caixote) com confirmação + undo 6 s (só gestor);
  placeholders auto-criados a partir do total declarado no onboarding;
  diálogo largo.
- **Reservas**: layout limpo (título "Reservas", botão "Reservar",
  dropdown de máquina), semana visível de relance sem scroll.
- **Onboarding**: sub-textos limpos de pitch.
- **Funcionários**: editáveis (finalmente), com botão eliminar seguro
  e coluna com vendas do mês.
- **Diálogos em portrait** sobem acima do teclado.
- **Backend**: trigger de push para o Cesar quando entra novo pedido
  Punho (task #196).

### E7 · Verificação pós-release

- APK descarrega do GitHub Release e instala num Android limpo (o Cesar
  faz manualmente no telemóvel dele — não é o Code).
- **O Code marca no doc**: link do release, checksum do APK, tamanho.

### Não fazer na Frente E

- Não bumpar `pubspec` para 0.0.6+X — a próxima sprint decide.
- Não fazer force-push nem rebase de `main`.
- Não apagar a branch `feat/v005-dashboard-alavancas` depois do merge —
  o Cesar pode querer voltar lá.
- Não abrir issues automáticas nem cross-post para o Control.

---

## Não fazer nesta sprint (A-D)

- Não bumpar `pubspec` nem gerar APK antes de A-D estarem verdes
  (Frente E trata disso no fim).
- Não redesenhar o mês do calendário (`_MonthBookingsCalendar`) — só a
  semana.
- Não apagar sub-textos do onboarding por atacado; usar o critério
  descrito.
- Não mexer no `barrierDismissible` do `_showCalendarBookingConfirmation`
  nem em outros diálogos fora dos três listados.
- Se a Frente F/G da sprint 3 estiver por aplicar, **não** duplicar o
  trabalho dela; assumir que vai chegar e escrever o código para
  compor bem quando chegar.

---

## Gate

1. `flutter test` verde. Reportar contagem antes/depois.
2. `flutter analyze` limpo.
3. Screenshots novos (5):
   - `reservas_semana_sem_scroll.png`
   - `onboarding_passo1_limpo.png`
   - `dialogo_veiculo_portrait_teclado.png`
   - `funcionarios_com_editar_e_vendas.png`
   - `funcionarios_confirmar_eliminar.png`
4. Doc `docs/design/punho_v005_dashboard.md` — appendar secção
   "Sprint 4: semana sem scroll + onboarding limpo + diálogos com
   teclado + funcionários editáveis com vendas do mês" com racional e
   screenshots.
5. Frente E: `git log --oneline main | head -5` mostra o merge commit
   `release: v0.0.5`. `git tag --list v0.0.5` retorna. GitHub Release
   com APK anexado, link no report.

## Entrega

- Frentes A-D: 4 commits atómicos na `feat/v005-dashboard-alavancas`,
  um por frente. Report frente a frente.
- Frente E: commits de consolidação/bump + merge no `main` + tag +
  push (pedir autorização antes do push). Release com APK. Report com
  URL do release e checksum.
