# Punho — auditoria como aplicação de ensino prático de gestão

> Auditoria de produto, 27 de Julho de 2026.
> Compara o estado real do Punho (docs + código, v0.0.5 em curso) com a
> promessa declarada: "ensinar gestão empresarial na prática, através do
> trabalho diário".
> Investigação externa em Julho de 2026 com FreshBooks, Xero, QuickBooks,
> YNAB, Copilot Money, Profit First/Relay, EOS/Ninety, Weekdone/Perdoo,
> Point of Rental, Booqable, EZRentOut, Quipli, Rentman e Duolingo.

## 1. Sumário executivo

O Punho, tal como está hoje, é uma aplicação de **operação com ambição
pedagógica declarada**, não uma aplicação de ensino. A ambição está
articulada nos documentos com um nível de exigência que quase ninguém no
mercado tem — a Biblioteca de Alavancas, a regra "por apurar" em vez de
"0 €", a distinção entre resultado provisório e lucro contabilístico, a
separação entre alavanca/evidência/leitura/ação/resultado — mas o **código
transporta hoje uma fração dessa ambição**. O gestor vê números
melhor arrumados do que na concorrência, e recomendações determinísticas
pontuais, mas não é levado por um caminho de aprendizagem, não é
convidado a reflectir, não vê o "porquê" de cada indicador ligado ao
princípio que o justifica, e não pode explorar cenários.

A distância principal não é técnica — é editorial e pedagógica: a
Biblioteca de Alavancas existe como ficheiro (`docs/BIBLIOTECA_DE_ALAVANCAS.md`)
mas **não existe dentro da app**. Um gestor a usar o Punho hoje não sabe
que existe. Fechar essa distância é o passo mais barato e mais
diferenciador possível, e é onde o Punho tem vantagem competitiva real —
nenhuma app de aluguer o faz, nenhuma app financeira PT o faz nesta
combinação, e as apps que ensinam bem (YNAB, Profit First) não são de
gestão operacional.

## 2. O que o Punho já faz bem

**Linguagem editorial de KPIs.** A regra "zero por falta de dados devolve
`null`", implementada de forma consistente em `lib/core/operations/kpis.dart:15-18`
e em cada slide do dashboard (`docs/design/punho_v005_dashboard.md`, secção
"Grelha 2×2 que enche o ecrã"), é rara no mercado. FreshBooks, Xero e
mesmo Copilot Money apresentam 0 € quando não há dados; o Punho mostra
"Por apurar — ainda não registaste nenhuma despesa". Isto é ensino
implícito de qualidade de dados.

**Estrutura de recomendação com contrato explícito.**
`Recommendation` em `lib/core/guidance/guidance_engine.dart:35-55` obriga
a `title`, `explanation`, `impact`, `quality`, `action` e `measure`. O
formato é o que a `BIBLIOTECA_DE_ALAVANCAS.md` promete: alavanca,
evidência, leitura, próxima ação, resultado a acompanhar. É um contrato
pedagógico embutido no tipo.

**Painel organizado por pergunta de gestão, não por tema.** Os cinco
slides do `DashboardPage` (`lib/features/dashboard/presentation/dashboard_page.dart:41-47`)
respondem cada um a uma pergunta ("estou a facturar o esperado?",
"tenho negócio à porta?", etc.). Isto está mais próximo do que um
scorecard EOS faz semanalmente do que qualquer dashboard de KPIs de
concorrentes de aluguer (Point of Rental, Booqable, EZRentOut, Quipli),
que se limitam a mostrar rubricas.

**Distinção entre resultado provisório e lucro.** O `resultadoMesConservador`
(`lib/core/operations/kpis.dart:91-95`) devolve `null` sem movimentos e
o slide dinheiro afirma "provisório: faltam as contas por pagar,
portanto não é lucro" (`design/punho_v005_dashboard.md`, secção Slide 1).
Esta pedagogia — "dinheiro não é lucro" — é o **princípio 6 da
auditoria** (`AUDITORIA_E_PLANO_DO_PRODUTO.md:42`) traduzido em UI.

**Recomendação única com gravidade e histórico de adiamento.** Em vez de
listar tudo (o defeito do Mint), a `recomendacaoDaSemana`
(`lib/core/operations/kpis.dart:600-623`) devolve **uma** — a mais grave —
com bordo colorido por gravidade. O botão "Adiar 7 dias" respeita a
autonomia do gestor. Este é um padrão superior ao de todas as apps
financeiras que consultei.

**Alavancas nomeadas e coerentes.** `GuidanceLever` (`guidance_engine.dart:6-15`)
tem exactamente os cinco eixos da Biblioteca. A app tem o vocabulário
certo, mesmo que ainda não o esteja a mostrar.

## 3. Onde está fraco enquanto app de ensino

Distingo "fraco em gestão" (a app não capta bem uma rubrica) de "fraco
em ensino" (a app não explica, não conduz, não fecha o loop). Aqui foco o
segundo.

**A Biblioteca de Alavancas não vive dentro da app.** Está em Markdown
para o Cesar e para quem lê o repositório. O gestor a usar o Punho hoje
não vê Taylor, Follett, Pareto, Schumpeter, nem os princípios. Vê
números melhor arrumados, mas sem o texto por trás. A `WeeklyManagementNote`
existe (`guidance_engine.dart:83-123`) mas o `design/punho_v005_dashboard.md`
diz explicitamente que passou para "Ver todas as métricas" — foi
enterrada, não elevada.

**Sem currículo nem progresso visível.** Duolingo funciona porque tem
uma árvore. YNAB funciona porque tem quatro regras numeradas. Profit
First funciona porque tem cinco contas. O Punho tem cinco alavancas +
nove princípios + cinco slides — sem mapa. Um gestor no dia 60 não sabe
o que já aprendeu ou o que devia aprender a seguir. Não há "streak",
não há "níveis", não há "primeiros 30 dias".

**Motor determinístico com três regras hardcoded.** O `GuidanceEngine.evaluate`
(`guidance_engine.dart:165-257`) tem exactamente três regras: `pending`,
`wednesday`, `meals`. Não cobre custos vs receita, ocupação de máquinas,
funil de leads, ticket médio, tempo até primeiro contacto, cauções,
concentração de clientes ou dias sem regressar — apesar de os KPIs
existirem em `kpis.dart`. A `RecomendacaoDoDia`
(`docs/design/punho_v005_dashboard.md`, sprint 2) acrescenta 5 regras
adicionais no `_dinheiro_slide`, mas continua a ser um catálogo curto
comparado com a superfície de alavancas prometida. O motor está a usar
uma fracção dos dados que a app já tem.

**Cada KPI abre uma lista, não uma explicação.** Uma "ocupação de 40%"
tem contexto no slide (Top e Paradas ao lado), mas não abre nenhum ecrã
que explique o que é ocupação, porque interessa, como se calcula, como
se mexe. `TodasMetricasPage` é o catálogo, não é o professor.

**Sem retrospectiva.** Weekdone construiu-se sobre PPP semanal
(Progress, Plans, Problems). EOS construiu-se sobre scorecard semanal
de 5-15 measurables. YNAB obriga a "reconciliar". O Punho tem
`weeklyGoalFromRecommendations` (`guidance_engine.dart:131-147`) que
propõe um objectivo mas **não pergunta no fim da semana o que aconteceu**.
Sem fecho, o gestor não aprende do próprio ciclo.

**Sem "e se". Sem simulação.** Uma máquina que renda 25 € por dia,
alugada 12 dias por mês, dá 300 €/mês; se subir preço 10% e perder 1 dia
de aluguer, dá 302,50 €. Isto é gestão prática e o Punho tem todos os
dados para o fazer. Mas não permite mexer nos números para ver o
impacto. Copilot Money faz-o em finanças pessoais ("se cortares Ubers
em 20% poupas 45 €/mês"). Nenhum concorrente de aluguer faz isto.

**Sem objectivo do próprio negócio.** O Punho pergunta ao gestor uma
lista longa de dados de onboarding (`DECISOES_E_ROADMAP_VIVO.md`,
secção 4.1) mas não lhe pergunta o que quer da empresa: crescer, ganhar
tempo, vender daqui a três anos, estabilizar. Sem isso, toda a
recomendação é a mesma para todos os gestores — e o EOS mostrou que a
mesma recomendação para dois gestores diferentes é ruído.

**A relação gestor-colaborador não fecha o loop pedagógico.** A
Biblioteca cita explicitamente Mary Parker Follett — "resolver problemas
com a equipa" (`BIBLIOTECA_DE_ALAVANCAS.md`, tabela) — mas no código o
colaborador **regista** e o gestor **decide**. Não há canal do gestor
para o colaborador ("obrigado, o que registaste ajudou a decidir X").
O princípio está enunciado mas não é vivido.

**Sem ficha individual de cliente com narrativa.** Já registado como
P2-8 no `AUDITORIA_BUGS_v0.0.3.md` e mencionado no `BACKLOG_v0.0.4.md`
(secção "Editar cliente"). Sem esta ficha, a lição "o cliente é o
activo mais importante" não pode ser vivida na app.

**Rentabilidade real por reserva/máquina/cliente não existe.** A
prioridade 3 de `DECISOES_E_ROADMAP_VIVO.md` menciona-a; o código
não a implementa. É provavelmente a lição de gestão mais importante que
falta.

## 4. O que faltam as apps concorrentes — janela de oportunidade

Impressão minha (baseada nas páginas de marketing e comparativos, não em
testes hands-on de cada uma):

**Apps de aluguer (Point of Rental, Booqable, EZRentOut, Quipli, Rentman)
ensinam o software, não o negócio.** A formação existe — Point of Rental
tem "self-paced learning paths" com vídeos e docs — mas é toda sobre
"como carregar uma máquina", "como fazer um contrato", "como emitir uma
fatura". Nenhuma delas tem sequer um princípio de gestão nomeado. É um
vácuo evidente. Um gestor de PME que compra Booqable aprende Booqable;
não aprende a gerir.

**Apps de contabilidade (FreshBooks, Xero, QuickBooks) têm centros de
ajuda excelentes fora da app, mas dentro da app são reactivas.** O
"FreshBooks for Education" é para escolas usarem FreshBooks como recurso
didáctico com alunos, não para o empresário aprender a gerir enquanto
usa. Xero Central e QuickBooks Support são bibliotecas de artigos que
respondem a "como faço X" — não te levam a "qual é o próximo X que
devias aprender".

**Apps que ensinam método (YNAB, Profit First/Relay) prendem-se a UM
método.** YNAB são as Quatro Regras. Profit First são as cinco contas
bancárias. Isto tem virtudes (clareza, aderência) mas fecha o produto
a uma metodologia; quem não a compra, sai. O Punho, com cinco alavancas
e recomendações contextuais, poderia ter clareza de método SEM se
prender a UMA doutrina. Ninguém no mercado ocupa esta posição.

**Software EOS (Ninety, Strety, Traction Tools) é para equipas grandes
com facilitador humano.** Custa dinheiro por lugar, precisa de um
"integrator" formado para funcionar. O EOS resolve muito bem a
disciplina semanal (scorecard, rocks, IDS) mas está fora do alcance de
uma PME de aluguer com três pessoas. Trazer o **espírito do scorecard
semanal** para uma app de €X/mês sem facilitador é uma oportunidade.

**Copilot Money mostra o que é um "assistente que conhece os teus
dados"**, mas está circunscrito a finanças pessoais. O padrão — pergunta
em linguagem natural sobre os teus próprios dados, resposta específica
e não genérica — é directamente aplicável a gestão de PME e nenhum
concorrente de aluguer o faz. O Cesar já sinalizou que IA é opcional
para depois, mas convém saber que a janela existe e não é abstracta.

**Duolingo é a referência de aprender fazendo, com progresso visível.**
O Punho tem o "fazer" (regista, decide, mede); falta a estrutura visível
de progresso — a árvore, o streak, o "novo esta semana". Trazer estes
elementos sem os tornar infantis é um problema de design, não de
funcionalidade.

**Vácuo grande:** um produto de gestão operacional de PME em português
europeu, com currículo explícito de gestão embutido, com recomendações
contextuais em vez de artigos de biblioteca, e com um ciclo semanal de
reflexão. Este posicionamento está livre. O Punho é o candidato mais
próximo.

## 5. As sete lacunas mais importantes vs "melhor app de ensino"

Ordenadas por relação custo/impacto (as primeiras têm alto impacto
pedagógico a baixo custo).

| # | Lacuna | Sinal no código/docs | Custo | Impacto pedagógico |
|---|--------|----------------------|-------|--------------------|
| 1 | **Biblioteca de Alavancas não vive na app.** O gestor não vê os princípios que orientam as recomendações. | `docs/BIBLIOTECA_DE_ALAVANCAS.md` existe; `guidance_engine.dart:83-129` só usa 5 notas rotativas. `TodasMetricasPage` esconde a nota semanal. | Baixo | Muito alto |
| 2 | **Sem "porquê" nem "como se mexe" ligado a cada KPI.** Cada card abre uma lista, não abre uma peça editorial curta. | `dashboard_page.dart:69-77`: cada slide compõe cards, nenhum leva a um ecrã de explicação. | Baixo | Muito alto |
| 3 | **Sem retrospectiva semanal estruturada.** O gestor recebe objectivos mas nunca é obrigado a fechá-los. | `guidance_engine.dart:131-147` propõe objectivo; não há tabela `retrospectivas` nem rota "Sexta-feira". | Médio | Muito alto |
| 4 | **Motor de recomendação demasiado pobre.** Três regras hardcoded para dezenas de KPIs disponíveis. | `guidance_engine.dart:165-257` cobre `pending`, `wednesday`, `meals`. `recomendacao_do_dia.dart` acrescenta 5 regras no slide dinheiro. | Médio | Alto |
| 5 | **Sem objectivo do próprio negócio.** A app não sabe o que o gestor quer. | `AUDITORIA_E_PLANO_DO_PRODUTO.md:222-236` (mapa inicial) recolhe dados fiscais/operacionais, nada de intenção. | Baixo | Alto |
| 6 | **Sem simulação "e se…".** Impossível aprender causalidade sem mexer nas variáveis. | Nenhum ecrã, nenhum provider, nenhuma referência em `kpis.dart`. | Alto | Alto |
| 7 | **Rentabilidade real por reserva/máquina/cliente não existe.** A lição central do aluguer não é possível. | `DECISOES_E_ROADMAP_VIVO.md:270-274` diz "planeado"; `kpis.dart:422-434` só tem `ticketMedioReserva`. | Alto | Muito alto |

Nota sobre custos: "baixo" significa uma sprint de 1-2 semanas; "médio",
2-4 semanas; "alto", uma versão inteira. Assumo o ritmo actual de
sprints do Cesar visto em `DECISOES_E_ROADMAP_VIVO.md:66-106`.

## 6. Propostas concretas para as próximas três versões

### v0.0.7 — Currículo do Punho

**O quê:** Trazer a Biblioteca de Alavancas para dentro da app.
Cada KPI ganha um ecrã "O que é / Porque interessa / Como o mexes /
Qual o princípio que sustenta". Barra lateral tem novo destino
**Aprender** com árvore visível: cinco alavancas → cada alavanca lista
os indicadores/decisões que a app já cobre, com marca de "visto" quando
o gestor abriu a peça pelo menos uma vez. As notas semanais deixam de
estar enterradas em "Ver todas as métricas" e sobem para o slide 5 ou
para o topo do destino Aprender.

**Porquê:** É a lacuna 1+2 fechada. É o passo mais barato e mais
diferenciador. Nenhum concorrente PT tem isto; Duolingo, YNAB e Notion
Academy provaram o padrão em domínios adjacentes.

**Como se mede o sucesso pedagógico:** percentagem de gestores que
abriram pelo menos 5 peças nos primeiros 30 dias. Baseline zero. Meta
inicial 40%. Segunda métrica: número de peças abertas a partir de um
KPI vs. abertas directamente do menu Aprender — mede se o gestor está a
aprender no momento da dúvida (bom) ou apenas quando explora
deliberadamente (menos bom).

### v0.0.8 — Revisão de Sexta-feira

**O quê:** Ecrã semanal com três perguntas: "o que registaste esta
semana", "o que aprendeste com os números", "o que vais fazer na
próxima". Duas primeiras auto-preenchidas com dados (recebidos,
reservas, recomendações mostradas) e o gestor confirma ou corrige. A
resposta livre fica guardada em `retrospectivas`. O Punho passa a
mostrar, no início da semana seguinte, "há uma semana disseste isto —
aconteceu?". Notificação Windows/Android à sexta às 17h; opcional,
adiável.

**Porquê:** Fecha o loop pedagógico — sem fecho, não há aprendizagem.
É o que EOS/Weekdone provaram funcionar em empresas maiores, adaptado
para uma pessoa numa PME. A `weeklyGoalFromRecommendations` já existe;
falta o par do fim de semana.

**Como se mede o sucesso pedagógico:** taxa de fecho de retrospectiva
(semanas em que o gestor completou / semanas activas). Meta 30% no
primeiro trimestre. Segunda métrica: contagem de "conclui a acção
proposta" nas semanas com retrospectiva completa vs sem — mede se a
retrospectiva altera comportamento.

### v0.0.9 — Rentabilidade por Unidade + Simulação "E se…"

**O quê:** Duas peças ligadas.
Primeira: `margemPorMaquina(state, periodo)` — receita atribuída (soma
de recebimentos ligados a reservas dessa máquina) menos custo atribuído
(manutenção paga da máquina + fatia proporcional de custos fixos +
prestação/leasing se for caso disso). Slide 3 ganha novo card "Rende
mais" e "Rende menos". Segunda: modo "E se…" acessível de qualquer KPI:
sliders para preço, ocupação, custo, dias/mês. Mostra impacto no
resultado provisório do mês. Determinístico, sem IA.

**Porquê:** Rentabilidade por activo é a lição central do aluguer;
"e se" é o único modo de aprender causalidade sem mexer no negócio real.
Nenhum concorrente de aluguer faz isto; nenhum concorrente de PME em PT
faz isto.

**Como se mede o sucesso pedagógico:** número de simulações feitas por
gestor por mês; percentagem de simulações que precedem uma alteração
real (preço, arquivo de máquina, novo aluguer). O objectivo é
correlação, não causalidade: gestores que simulam devem ter melhor
resultado por máquina do que os que não simulam.

## 7. Cinco perguntas que o Cesar tem de responder

1. **Determinístico até quando?** O motor determinístico de três regras
   é honesto mas pobre — a superfície de KPIs já é maior. Aceitar
   probabilístico (heurística com pesos calibrados por empresa,
   eventualmente IA local ou remota que responde a perguntas sobre os
   dados do gestor) é o próximo salto, e é o que Copilot Money fez em
   finanças pessoais. Se a resposta for "determinístico para sempre", é
   preciso investir a sério nas regras — hoje são poucas para a
   ambição.

2. **Aprofundar aluguer ou expandir vertical?** Cada minuto gasto em
   reclamações, cauções, rentabilidade por máquina e ficha individual
   de cliente é minuto que não vai para lavandaria/outros verticais. Os
   docs (`DECISOES_E_ROADMAP_VIVO.md:8-11`) dizem "arquitectura permite
   adaptar" — mas cada lição prática de gestão que se ensina bem exige
   ficar profundo no vertical.

3. **Colaborador é utilizador da app ou informador do gestor?** Hoje
   é informador — regista, não decide, não recebe feedback pedagógico.
   Para o Punho ser "app de ensino de gestão", tem de decidir se o
   colaborador também aprende (o que exige uma segunda camada
   pedagógica) ou se apenas serve o gestor. A citação de Follett na
   Biblioteca sugere a primeira; o código actual pratica a segunda.

4. **Currículo estruturado ou catálogo por procura?** Duolingo é
   currículo (a árvore obriga a ordem). Xero Central é catálogo
   (procura o que precisas). YNAB é os dois (4 regras + biblioteca). O
   Punho tem hoje o esqueleto de catálogo (a Biblioteca em Markdown);
   se o próximo passo é "trazer para dentro da app", tem de decidir se
   é catálogo pesquisável ou currículo com ordem sugerida.

5. **A app cobra por conta, por colaborador, ou por resultado
   pedagógico?** A cobrança actual (Main + pacotes de 3 colaboradores,
   `AUDITORIA_E_PLANO_DO_PRODUTO.md:408-415`) é por acesso. Uma app que
   se posiciona como "ensina o teu negócio a crescer" pode justificar
   uma componente por resultado — desconto se o gestor completou o
   currículo, se cumpriu o objectivo, se o negócio cresceu. Nenhum
   concorrente cobra assim; pode ser vantagem ou risco.

## Fontes externas consultadas

Web search, Julho 2026:

- FreshBooks — [educação e recursos](https://www.freshbooks.com/en-gb/education), [FreshBooks for Education](https://www.freshbooks.com/en-za/education)
- YNAB — [Four Rules](https://www.ynab.com/blog/ynab-four-rules-less-stress)
- Copilot Money — [Money Assistant](https://www.copilot.money/dispatch/beta-introducing-your-money-assistant)
- Profit First / Relay — [método e integração](https://relayfi.com/blog/profit-first-method/), [Relay by Mike Michalowicz](https://mikemichalowicz.com/relay/)
- EOS — [Scorecard e Traction](https://www.eosworldwide.com/blog/entrepreneurial-operating-system-explained-how-eos-helps-businesses-gain-traction)
- Weekdone / Perdoo — [comparativo](https://mooncamp.com/blog/perdoo-vs-weekdone)
- Point of Rental — [training](https://www.point-of-rental.com/customer/training/)
- Booqable / EZRentOut / Quipli / Rentman — [comparativo Quipli](https://quipli.com/point-of-rental-vs-booqable-vs-quipli/), [comparativo EZO](https://ezo.io/ezrentout/blog/quipli-vs-booqable-vs-ezrentout/)
- Duolingo — [onboarding UX](https://userguiding.com/blog/duolingo-onboarding-ux), [masterclass](https://www.junoschool.org/article/duolingo-onboarding-experience/)
