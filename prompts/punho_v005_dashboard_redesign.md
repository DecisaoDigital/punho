# Prompt Claude Code — Punho v0.0.5 (redesign do Dashboard + sidebar + Tarefas)

> ⚠️ **WIP — não executar ainda.** Este ficheiro é o colector do que vai entrar
> na 0.0.5. O Cesar continua a acrescentar refinamentos; só arranca no Code
> quando ele disser explicitamente "faz APK" ou "podes arrancar a 0.0.5". Até
> lá, ler mas não implementar.

## Objectivo

Substituir o Dashboard actual (17 KPIs num `Wrap` sem hierarquia) por um **carrossel de 5 slides landscape**, cada slide com **4 KPIs agrupados por decisão a tomar**. Reorganizar sidebar (compactada com labels), adicionar novo destino **Tarefas**.

**Repo:** `punho`
**Branch nova:** `feat/v005-dashboard-alavancas` (a partir do topo actual)

Mockup de referência: `D:\Punho\docs\mockups\dashboard_v2.html` (abrir em browser widescreen).

---

## Problemas do Dashboard actual (contexto)

1. **Overload cognitivo:** 17 `_Metric` num único `Wrap`, sem agrupamento nem hierarquia.
2. **Trai a Biblioteca de Alavancas:** o doc promete organização por alavancas; o código dispersa as métricas ao acaso.
3. **Falsos zeros mentem:** "Recebido hoje: 0€" nos primeiros 20 dias comunica que a operação não facturou.
4. **"Resultado operacional simples" é enganador:** cálculo sem timing dá ilusão de lucro no início do mês.
5. **CTAs enterrados** e recomendações amontoadas.
6. **Formato portrait mobile-first** — errado. O empresário usa tablet/PC em landscape.

---

## Regras não negociáveis

1. **Landscape obrigatório.** Empresário usa tablet/PC preferencialmente; telemóvel só ocasionalmente e mesmo assim em landscape. Bloquear via `SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])` no `main.dart`. Portrait não é suportado.
2. **Cada slide ocupa toda a área útil disponível** — sem espaço morto. O grid 2×2 estica-se com `Expanded` (Flutter) para preencher a altura remanescente após cabeçalho e barra de dots (que têm altura fixa mínima). Cada célula do grid usa `Column` com `Expanded` interno para distribuir espaço (número grande no topo, sub-info a meio, CTA/rodapé no fundo). Se sobrar ar dentro de uma célula, aumentar tamanho do número principal (32-40 sp) — não deixar padding excessivo.
3. **Cada slide = 4 KPIs que se lêem em conjunto** e respondem a **UMA pergunta de gestão**. Nunca um KPI isolado por slide.
4. **Falso zero é proibido.** Se um valor é 0 por falta de dados (não por operação de facto), substituir por "Por apurar" ou esconder card.
5. **Correcção conceptual:** "Frota = veículos" (carros/carrinhas, com custos); "Máquinas = as que aluga a clientes" (com ocupação). São coisas distintas.
6. **Recomendação da semana é 1 só** (não pilha).

---

## Sidebar (revisada)

Largura **~88 dp** (não os 72 anteriores) para caber **labels debaixo dos ícones**. Item activo com border-left laranja + fundo escuro.

Rótulos:
- `Gestão` (`Icons.space_dashboard_outlined`)
- `Máquinas` (`Icons.build_outlined`)
- `Clientes` (`Icons.people_outline`)
- `Reservas` (`Icons.calendar_month_outlined`)
- `Finanças` (`Icons.credit_card_outlined`)
- `Frota` (`Icons.local_shipping_outlined`) — só se `vehicles > 0`
- **`Tarefas`** (`Icons.checklist_outlined`) — novo (ver secção próxima); com badge vermelho pequeno no topo direito quando `contagemPendentes > 0`

Avatar do utilizador no fundo (contexto de sessão), com tooltip "Sessão activa" ou "Demonstração local".

---

## Novo destino: Tarefas

Nova página `TarefasPage` acessível pela sidebar. Centraliza pendências que hoje estão dispersas em alertas condicionais do Dashboard actual. Lista com CTAs directas em cada item.

**Fontes que a página junta:**
- `initialDataTasks` (dados por completar — já existe no OperationsState)
- Cobranças com atraso > 15 dias (pagamentos pendentes por cliente)
- Máquinas por identificar (`hasUnidentifiedDeclaredMachines`)
- Colaboradores incompletos (sem custo ou sem horário)
- Frota declarada sem veículos identificados (`hasFleet && vehicles.isEmpty`)
- Convites Punho por responder (só se aplicável quando Supabase ligado)
- Recomendações da semana anteriores adiadas (novo state: adiar recomendação para semana seguinte)

**Layout:**
- Cabeçalho: contagem total ("4 tarefas pendentes")
- Lista agrupada por severidade: `⚠️ Urgente` (cobranças, dados fiscais) / `📝 A completar` (dados operacionais, morada) / `💡 Sugestão` (recomendações adiadas)
- Cada item com CTA directa (ex: "Preencher NIF →" abre Definições; "Cobrar João Silva →" abre ficha do cliente)

**Badge da sidebar:** número total de tarefas pendentes; vermelho se contém itens urgentes, cinza escuro se só a completar.

---

## Dashboard — carrossel de 5 slides

**Padrão story-based.** Cada slide ocupa toda a área útil, com um grid **2×2 de 4 KPIs** que se lêem em conjunto. Navegação por:
- **Tablet/touch:** swipe horizontal
- **PC/desktop:** setas ← → nas laterais (ou teclas do teclado)
- **Dots + label** no fundo: `1/5 · Dinheiro`, e à direita as tabs dos restantes slides clicáveis (`→ Pipeline · Máquinas · Custos · Semana`)

Cabeçalho do slide mostra: **ícone + nome + pergunta de decisão** ("💰 Dinheiro do mês — Estou a facturar o esperado?").

### Slide 1 — Dinheiro do mês
**Pergunta:** *Estou a facturar o esperado? Preciso de cobrar?*
Grid 2×2 (célula superior esquerda maior):
- **[grande, cell 1-1, fundo verde-100]** Recebido este mês — número 30px + tendência "↑ 18% vs mês passado" + sparkline diário 30d na base.
  - **Navegação temporal in-place:** o título "Recebido este mês" tem uma seta `‹` à esquerda e `›` à direita (`IconButton` pequenos, 20 dp). Clicar em `‹` mostra o mês anterior *no próprio card* (número, tendência e sparkline recalculam), sem sair do slide. `›` só está activa se não estivermos no mês actual. Estado do mês seleccionado local ao slide (`ValueNotifier<DateTime>`), reinicia para o mês corrente ao sair e voltar ao slide. **Só este KPI tem a navegação nesta versão** — os outros três cards continuam a mostrar o mês actual.
- **[cell 1-2, fundo amber-100]** Por receber — número grande + sub-linha "3 clientes · 1 há > 15 dias" + botão inline "Cobrar →"
- **[cell 2-1, fundo branco + border]** Pago este mês — número + sub-linha "Salários · seguros · manutenção"
- **[cell 2-2, fundo branco + border-left laranja]** Resultado provisório — número (+ ou −) + sub-linha "Recebido − Pago (faltam contas por pagar)"

Se `recebidoMes == 0 && paidMes == 0`, todo o slide mostra estado vazio: "Ainda sem movimentos este mês. Regista o primeiro recebimento →"

### Slide 2 — Pipeline & compromissos
**Pergunta:** *Tenho negócio à porta? Preciso de mais leads?*
- **[grande, cell 1-1]** Reservas confirmadas próximas 2 semanas — nº grande + € previsto + mini-calendário de 14 dias com marcadores
- **[cell 1-2]** Leads por contactar — nº + tempo médio desde criação ("mais antiga há 4 dias")
- **[cell 2-1]** Taxa de conversão 30 dias — % + comparação vs mês anterior
- **[cell 2-2]** Cauções em posse — € + nº de reservas com caução activa

### Slide 3 — Rentabilidade das máquinas
**Pergunta:** *O que está a render? O que está parado sem razão?*
- **[grande, cell 1-1]** Ocupação média % semana actual — anel grande (~120 dp) com % no centro + tendência vs semana anterior
- **[cell 1-2]** Top 3 máquinas mais alugadas — 3 barras horizontais com nome + nº aluguéis
- **[cell 2-1]** Máquinas paradas há > 7 dias — nº + lista compacta das 2-3 mais antigas com ícone de alerta
- **[cell 2-2]** Ticket médio por reserva — € + comparação com mês anterior

### Slide 4 — Custos operacionais
**Pergunta:** *Estou dentro do orçamento? Onde posso cortar?*
- **[grande, cell 1-1]** Custo colaboradores mês — € + nº colaboradores activos + custo médio por colaborador
- **[cell 1-2]** Custo frota mês (só se `vehicles > 0`; senão substitui por "Outros custos operacionais") — € + breakdown "Seguros · Combustível · Prestações · Aluguer"
- **[cell 2-1]** Manutenção paga mês — € + comparação vs média dos 6 meses anteriores
- **[cell 2-2]** **% custos vs receita** — o KPI-resumo. Barra horizontal com % ocupado por custos (verde <60%, amarelo 60-80%, vermelho >80%).

### Slide 5 — A minha semana
**Pergunta:** *O que faço hoje/esta semana?*
- **[grande, cell 1-1]** Recomendação da semana — formato canónico (Alavanca badge + Evidência + Sugestão + botões "Adiar 7 dias" / "Feito").
  - **Bordo colorido por gravidade** (border-left 4 dp): `verde` = oportunidade / sugestão de crescimento, `laranja` = atenção (algo a melhorar sem urgência), `vermelho` = urgente (risco financeiro ou operacional imediato). A cor deriva de `Recomendacao.gravidade` (enum novo: `oportunidade | atencao | urgente`; o controller decide qual atribuir consoante a alavanca e o valor do sinal). Fallback: sem gravidade definida → cinza neutro.
- **[cell 1-2]** Próximas 3 reservas — mini-lista compacta (cliente + máquina + hora)
- **[cell 2-1]** Tarefas pendentes — contagem + CTA "Abrir Tarefas →" (link para o destino Tarefas)
- **[cell 2-2]** Cobranças com atraso > 15 dias — nº + total € + CTA "Cobrar →"

---

## Alterações no código

### Novos ficheiros
- `lib/features/dashboard/presentation/dashboard_page.dart` — reescrever `DashboardPage.build` para renderizar carrossel + cabeçalho + dots.
- `lib/features/dashboard/presentation/slides/dinheiro_slide.dart`
- `lib/features/dashboard/presentation/slides/pipeline_slide.dart`
- `lib/features/dashboard/presentation/slides/rentabilidade_slide.dart`
- `lib/features/dashboard/presentation/slides/custos_slide.dart`
- `lib/features/dashboard/presentation/slides/semana_slide.dart`
- `lib/features/dashboard/presentation/widgets/kpi_grid_2x2.dart` — layout comum
- `lib/features/dashboard/presentation/widgets/slide_header.dart` — ícone + nome + pergunta
- `lib/features/dashboard/presentation/widgets/dots_indicator.dart` — barra do fundo
- `lib/features/tarefas/presentation/tarefas_page.dart` — nova página do destino Tarefas
- `lib/features/tarefas/domain/tarefa.dart` — modelo (id, severidade, título, subtítulo, CTA)
- `lib/features/tarefas/data/tarefas_service.dart` — agrupa fontes existentes

### Alterações
- `lib/features/shell/presentation/app_shell.dart` — sidebar 88dp com labels; item Tarefas com badge; item Frota condicional.
- `lib/core/navigation/app_destination.dart` — novo `tasks` (e o `fleet` já existe, verificar visibilidade).
- `lib/main.dart` — `SystemChrome.setPreferredOrientations([landscape])` após `Supabase.initialize`.

### Widgets a arquivar / mover
- `_Metric` (widget class) e todos os 17 usos actuais — mover para uma página secundária "Ver todas as métricas" acessível via botão no slide 4 ou no destino Tarefas.
- `_GrowthCommandPanel` — substituído pelo Slide 5 (Recomendação).
- `_WeeklyDirectionPanel` — arquivado ou fundido no Slide 5.
- `_HomologousMonthPanel` — os dados dele aparecem distribuídos pelos slides (Dinheiro, Custos).

### Métodos novos no controller
- `resultadoMesConservador()` — `int?` (null se por apurar)
- `funilProcura(int dias)` — `{leads, contactadas, convertidas, taxa}`
- `ocupacaoFrotaSemana()` — `{percent, tendenciaVsAnterior}`
- `topMaquinasMaisAlugadas(int n)` — lista
- `maquinasParadasHaMaisDe(int dias)` — lista
- `ticketMedioReserva()` — cêntimos
- `custosMesAgregados()` — `{colaboradores, frota, manutencao, custosFixos}`
- `recomendacaoDaSemana()` — 1 `Recomendacao` ou null
- `proximasReservas(int n)` — lista
- `contagemTarefasPendentes()` — `int`

---

## Testes

- **Widget tests** para cada slide + para o carrossel (navegação por swipe/tap dots).
- **Widget test** de `TarefasPage`: lista tarefas agrupadas por severidade, cada CTA leva ao destino correcto.
- **Widget test** da sidebar: badge de Tarefas visível quando há pendências; item Frota escondido quando `vehicles == 0`.
- **Test de orientação:** ao arrancar, `SystemChrome.setPreferredOrientations` foi chamado com landscape.
- **Screenshots** dos 5 slides guardados em `docs/design/screenshots/v005/` — comparar com mockup HTML.

## Gate

1. `flutter test` — verde, reporta contagem antes/depois.
2. `flutter analyze` — limpo.
3. `pubspec.yaml` — **não bumpar**. Cesar decide quando fecha a v0.0.5.
4. Screenshots gravados para confronto com o mockup.

## Entrega

- Branch `feat/v005-dashboard-alavancas`, N commits locais, sem push.
- Doc `docs/design/punho_v005_dashboard.md` com:
  - Comparação antes/depois (screenshots)
  - Racional de cada agrupamento de 4 KPIs
  - Lista das 17 métricas antigas e onde foram parar (ou porque foram cortadas)
  - Decisões técnicas (PageView vs carrossel manual, gestão de estado do slide activo)

## Fora do âmbito

- Página "Ver todas as métricas" — só o botão é criado, página em si fica placeholder.
- Sincronização Supabase — v0.1.0.
- Personalização (esconder/mostrar blocos por parte do utilizador) — v0.1.0.
- Dark mode se ainda não existir — segue tema actual.
- Animações elaboradas — transição básica de slide chega.
- **Reformatar Slide 1 como "2-3 KPIs + Recomendação do dia"** — Cesar quer explorar essa variante no próximo ciclo. Para 0.0.5 mantém 4 KPIs conforme especificado. Deixar `dinheiro_slide.dart` estruturado de forma que trocar a 4ª célula por um card de recomendação seja uma edição pontual (não reescrita).
- **Navegação temporal nos outros KPIs** (Pago, Por receber, Resultado) — só o "Recebido este mês" leva o `‹ ›` nesta versão. A extensão fica para 0.0.6.

## Notas de estilo

- `PunhoTheme.orange` é a cor de destaque (CTAs primários, hero border, ícone da mão, dot activo do carrossel).
- Sparklines simples (sem eixos), barras diárias com verde-600, alerta amber ou red conforme contexto.
- Todos os textos em português-PT.
- Ícones Material — nunca emojis no código Flutter. O mockup HTML usa emojis por conveniência mas Flutter usa `Icons.wallet_outlined`, `Icons.build_outlined`, `Icons.emoji_objects_outlined`, etc.
- Grid 2×2 com célula 1-1 (superior esquerda) tipicamente maior (span vertical) para receber o KPI-hero + sparkline. As outras 3 células com tamanhos iguais.
