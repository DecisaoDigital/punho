# Punho v0.0.5 — sprint 2 (Dinheiro + convites em Tarefas)

> **Continua na branch `feat/v005-dashboard-alavancas`**. Ainda não é APK,
> ainda não é bump, ainda não é push. Mais uma ronda de refinamento em cima do
> que entregaste na sprint 1.

Fecha os itens da tabela em baixo. Se algum bater com o que o Cesar tinha
posto explicitamente "para 0.0.6" no colector `punho_v005_dashboard_redesign.md`,
ignora o colector — este ficheiro tem precedência.

---

## 1. Slide 1 (Dinheiro) — trocar 4º KPI por "Recomendação do dia"

**Racional:** o "Resultado provisório" repete informação (Recebido − Pago já
está visível em duas células) e é a que menos ajuda a decidir *hoje*. O
Cesar quer, no Slide 1, três KPIs de dinheiro + uma acção sugerida.

### O que muda em `dinheiro_slide.dart`

- Ficam: **Recebido este mês** (célula 1-1, hero), **Por receber** (1-2),
  **Pago este mês** (2-1).
- Substituir: **Resultado provisório** (2-2) → **Recomendação do dia**.
- O card "Recomendação do dia" tem exactamente o mesmo bordo-por-gravidade da
  Recomendação da Semana (Slide 5): `border-left 4 dp` verde/laranja/vermelho
  consoante `Recomendacao.gravidade`. Fallback cinza se `null`.

### Como escolher a Recomendação do dia (função pura no controller)

Preferência por ordem — devolver a primeira que se aplica, ou `null`:

1. **Vermelho (urgente):** cliente com dívida > 30 dias e valor ≥ 100 €.
   Texto: `"Cobrar {nome} — {n} dias em atraso, {valor} €"`. CTA "Abrir ficha
   →" para a ficha do cliente.
2. **Vermelho:** % custos vs receita ≥ 80 % este mês.
   Texto: `"Custos a comer a receita — {%} do que entrou já saiu"`. CTA
   "Rever custos →" para Slide 4.
3. **Laranja (atenção):** cliente com dívida entre 15 e 30 dias.
   Texto: `"{nome} — {dias} dias sem pagar"`. CTA "Abrir ficha →".
4. **Laranja:** recebido do mês < 60 % do recebido do mês homólogo (só se
   o mês homólogo tiver ≥ 500 €). Texto: `"A facturar {%} do que fizeste em
   {mês}"`. CTA "Ver homóloga →" para `TodasMetricasPage`.
5. **Verde (oportunidade):** taxa de conversão de leads 30 d ≥ 40 %.
   Texto: `"Conversão a 30 d em {%} — pede referências aos últimos clientes"`.
   CTA "Ver conversão →" para Slide 2.
6. `null` → esconde o card, célula 2-2 fica com "Sem sugestão para hoje" em
   cinza claro.

Aloja o cálculo em `lib/features/dashboard/kpis/recomendacao_do_dia.dart` (função
pura, `DateTime now` injectado — o mesmo padrão dos outros KPIs). Nunca no
widget.

### Testes

- Um `recomendacaoDoDiaTest` para cada uma das 6 regras (5 positivas + 1 null).
- Widget test do slide: com fixture do caso vermelho aparece bordo vermelho +
  texto; com fixture null aparece o placeholder.
- Screenshot em `docs/design/screenshots/v005/slide_dinheiro_recomendacao.png`.

---

## 2. Setas ‹ › mês nos outros 3 KPIs de Dinheiro

Na sprint 1 só o "Recebido este mês" leva as setas. Estender:

- **Por receber:** navegar entre meses mostra o valor a receber **como estava
  no fim daquele mês** (histórico de dívida). Se o modelo não guardar snapshot
  histórico de dívida, escrever no card "Só o mês actual" em vez das setas
  (não inventar). Deixa registado no doc final se foi este caso.
- **Pago este mês:** setas sempre disponíveis, os pagamentos têm data.

Estado do mês seleccionado — **partilhado entre os três KPIs do slide**, não
um por card. Um `ValueNotifier<DateTime>` no `_DinheiroSlideState`; o card
"Recomendação do dia" usa sempre o mês actual (não faz sentido recomendar
sobre um mês passado).

Setas de cada card ficam desactivadas quando o KPI não tem dados para essa
direcção; a Recomendação continua no mês actual visualmente.

Testes de widget: navegar 3 meses atrás no "Pago" e confirmar que o número
muda e que a Recomendação não muda.

---

## 3. Tarefas — trazer convites Punho por responder

Na sprint 1 ficou de fora com "exige sessão Supabase + lista de convites".
Agora sim.

- `tarefas_service.dart` passa a incluir uma quinta/sexta fonte:
  `convitesPunhoPendentes()` que lê `punho_convites` (RPC ou select
  directo, o que já existir) e devolve convites com `usado = false` e
  `expira_em > now`.
- Item aparece em **⚠️ Urgente** se expira em ≤ 48 h, senão em **📝 A
  completar**.
- CTA: "Abrir convite →" abre `convites_screen` (já existe) com o convite
  seleccionado.
- **Se não houver sessão Supabase** (modo demo local), a fonte silenciosamente
  não contribui — nada de erros na Tarefas.

Widget test: fixture com 1 convite a expirar em 12 h + 1 a expirar em 5 d →
duas linhas, uma em Urgente, outra em A completar.

---

## 4. Shell colaborador — deixar como está

Confirmar por escrito no doc: shell do colaborador **fica em portrait** (6
botões grandes, telemóvel na mão). O bloqueio landscape do `main.dart` já é
`preferred`, não `only`, portanto não force nada aqui. Se estiveste tentado a
mudar, resiste — a decisão é do Cesar e é *ficar como está*.

---

## Não fazer nesta sprint

- Não tocar em `pubspec.yaml`.
- Não fazer push.
- Não gerar APK.
- Não commitar o `android/app/build.gradle.kts` nem o `pubspec 0.0.4+4` que
  ficaram pendentes da tarefa anterior — o Cesar decide.
- Não mexer no dashboard actual dos outros 4 slides (só refinamentos ao 1 e à
  Tarefas).
- Não inventar campo de "snapshot histórico de dívida" — se não existe,
  escreve "Só o mês actual" no card "Por receber" e segue.

---

## Gate

1. `flutter test` — verde, reporta contagem antes/depois (esperado 284 → ~300).
2. `flutter analyze` — limpo.
3. Screenshots novos:
   - `slide_dinheiro_recomendacao_vermelho.png`
   - `slide_dinheiro_recomendacao_verde.png`
   - `slide_dinheiro_recomendacao_null.png`
   - `slide_dinheiro_mes_passado.png` (setas ‹ activas)
   - `tarefas_com_convite_urgente.png`
4. Doc `docs/design/punho_v005_dashboard.md` — appendar secção "Sprint 2:
   Dinheiro + Convites em Tarefas" com o que mudou, screenshots referenciados,
   e a nota da decisão do shell colaborador.

## Entrega

Continua na `feat/v005-dashboard-alavancas`. N commits atómicos (um por item:
recomendação, setas, convites, doc). Report em cima disto.
