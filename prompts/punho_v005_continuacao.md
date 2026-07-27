# Punho v0.0.5 — continuação (funde o resto da sprint 3 + toda a sprint 4)

> **Substitui as instruções em aberto de `punho_v005_sprint3_trigger_e_arrumos.md`
> (Frentes E, F, G) e de `punho_v005_sprint4_ux_smoke.md` (Frentes A–E).**
> O que já entregaste na sprint 3 (Frentes A, B, C, D — 338 testes verdes)
> fica como está.
>
> Continua em `feat/v005-dashboard-alavancas`. 0.0.5 ainda ongoing.

Aceite a tua proposta de ordem. Executa por esta sequência — cada passo
é um commit atómico (ou dois quando indicado). Não avanças para o passo
seguinte sem `flutter test` + `flutter analyze` limpos no anterior.

---

## 1 · 3-E · Placeholders de máquinas a partir do onboarding

Ver secção "Frente E" original em
`punho_v005_sprint3_trigger_e_arrumos.md`. Independente das outras
frentes, sem sobreposições. Segue como estava.

## 2 · 4-B · Onboarding: sub-texto do passo 1 + revisão dos 12

Ver secção "Frente B" original em `punho_v005_sprint4_ux_smoke.md`.
Independente, rápido.

## 3 · Diálogos consolidados (3-F + 4-C fundidas)

Um único trabalho sobre três diálogos com muitos campos:

- `_vehicleDialog` (`workforce_pages.dart`)
- `_collaboratorDialog` (`workforce_pages.dart`)
- `_machineDialog` (`operational_pages.dart`)

Aplicar aos três **ao mesmo tempo** um único padrão que resolve as duas
frentes originais em conjunto:

- **`Dialog` com `SizedBox`/`ConstrainedBox`** — não `AlertDialog`.
- **`insetPadding.bottom = viewInsets.bottom + 16`** — sobe acima do
  teclado em portrait.
- **`maxHeight` desconta `viewInsets.bottom`** — o `Expanded` interior
  não fica atrás do teclado.
- **Landscape**: `_machineDialog` fica com duas colunas
  (esquerda=metadados, direita=notas + fotos maiores) como o 3-F original
  descrevia. Os outros dois ficam em coluna única, é suficiente.
- **Portrait**: os três em coluna única com `SingleChildScrollView` no
  `Expanded`.
- **Cabeçalho fixo + rodapé fixo** com `Cancelar` (à esquerda) e
  `Guardar` (à direita). O rodapé nunca é roubado pelo scroll — foi
  isto que fez o Cesar ver só "Guardar" no telemóvel.
- **`barrierDismissible: false`**.
- **`autofocus` no primeiro campo** (nome / matrícula / nome).
- **Validação de nome/matrícula não-vazio** com `ScaffoldMessenger` —
  já entregue no `_vehicleDialog`, faz igual nos outros dois.
- Se `_machineDialog` recebe uma máquina com `placeholder: true` (do
  passo 1 acima), o botão "Guardar" passa a `'Guardar e identificar'`.

**Três commits** — um por diálogo, na ordem `_machineDialog` →
`_vehicleDialog` → `_collaboratorDialog`. Testes de widget cobrem os
dois modos (portrait com teclado / landscape sem teclado) para os três.
Screenshots: `dialogo_maquina_largo.png`,
`dialogo_veiculo_portrait_teclado.png`,
`dialogo_colaborador_portrait_teclado.png`.

## 4 · Reservas consolidadas (3-G + 4-A fundidas)

Um único refactor de `BookingsPage`:

**Rótulos** (do 3-G):
- Título `'Marcações / Reservas'` → `'Reservas'` (grep também
  `app_shell.dart`).
- Botão `'Adicionar reserva'` → `'Reservar'`; com selecção
  `'Reservar (N)'`.

**Toolbar de uma linha** (do 3-G): `‹ [Período] › · [Semana|Mês] ·
[Máquina ▾] · [Reservar]`. `_MachineReservationSelector` (faixa 64 dp
com chips) desaparece — substituído por `DropdownButton<Machine>`
compacto na toolbar, `width: 240`.

**Chip contextual fino** por baixo da toolbar (do 3-G), sem `SizedBox`
fantasma quando não há texto.

**Calendário absorve o resto sem scroll** (do 4-A):
- 7 colunas visíveis (Seg → Dom) simultaneamente, sem scroll horizontal.
- Manhã e Tarde ambas visíveis, cada uma com 50% da altura via
  `Expanded`.
- `_WeekBookingsCalendar` sem scroll vertical em nenhum viewport
  landscape.
- Cabeçalho de coluna ≤ 48 dp, uma linha ("Seg 27/7").
- Célula = `Center` com `+` de 24 dp, bordas discretas (raio ≤ 8 dp),
  `AspectRatio` livre.

**Um só commit**. Screenshots: `reservas_landscape.png` +
`reservas_semana_sem_scroll.png`.

## 5 · 4-D · Funcionários: editar, eliminar, vendas do mês

Ver secção "Frente D" original em `punho_v005_sprint4_ux_smoke.md`.
Independente. O padrão de eliminar (caixote + confirmação + undo 6 s +
só gestor) já existe da 3-D — reusar sem redescobrir.

## 6 · Docs e screenshots

Actualizar `docs/design/punho_v005_dashboard.md` com uma secção que
cobre tudo o que veio depois das Frentes A-D da sprint 3, honesta sobre
a fusão (é história, mereces registá-la).

---

## O que **não** fazes nesta continuação

- **Não** avanças para "release" (bump, merge em main, tag, push, APK).
  Reportas o estado final e eu decido em seguida. Motivos:
  - O push desta branch é a primeira vez que sai do PC — vai com o meu
    sinal verde, não sem.
  - Quero olhar para o resultado da fusão diálogos+Reservas antes de
    cortar a versão.
- **Não** limpes o `at_invoice_qr_test.dart` que caiu por engano no
  commit da 3-D — deixa como está, arrumo eu na altura do release.
- **Não** commites `test/features/dashboard/failures/*.png` (já os
  removeste e puseste no `.gitignore` — mantém).

## Autorização geral

- **Commitar WIP das outras frentes** (comprovativos, QR AT, o resto
  do `pubspec` da outra sessão): **sim, autorizado**, agrupado por tema
  em commits separados. Se aparecerem chaves, tokens ou backups —
  pára e reporta antes de commitar.
- **Push da branch, merge em main, tag v0.0.5, APK, GitHub Release**:
  **não autorizado nesta continuação**. Nova instrução minha depois de
  ver o report.

## Gate

1. `flutter test` verde — reportar contagem antes/depois (esperado
   ~338 → ~380).
2. `flutter analyze` limpo.
3. Screenshots todos (dos passos 3, 4, 5).
4. Doc actualizado.

## Entrega

Continua em `feat/v005-dashboard-alavancas`. Um report frente-a-frente
como fizeste na sprint 3. Sem push.
