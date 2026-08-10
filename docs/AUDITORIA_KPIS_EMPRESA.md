# Auditoria de KPIs para a saúde da empresa

**Contexto.** Relatório de investigação para calibrar o painel do **Punho — Agarra
o comando**. Público-alvo: gestor de PME de serviços com formação financeira fraca,
tempo escasso, quer decidir hoje o que faz esta semana. A filosofia do produto é
ensinar gestão na prática: mostrar o número, explicar a causa, propor a acção.

Este documento tem quatro partes:

- **Parte A** — os 3 KPIs que um empresário teria de ver se só pudesse ver três.
- **Parte B** — os 15 KPIs essenciais agrupados em cinco categorias.
- **Parte C** — cruzamento com o painel actual do Punho (v0.0.5).
- **Parte D** — recomendações concretas para as próximas sprints (0.0.7+).

Fontes consultadas listadas no final.

---

## Parte A — Os 3 KPIs mais críticos

O critério não é "qual é o mais falado" nem "qual é o mais bonito no dashboard".
É brutal: **se o gestor só pudesse ver três números por semana, quais preveniriam
mais falências**. A resposta reflecte três perguntas encadeadas — *estou vivo?*,
*cada venda que faço vale a pena?*, *a minha empresa toda transforma esforço em
dinheiro com eficiência?*.

### 1. Saldo de tesouraria disponível e runway em semanas

**Fórmula.** Dinheiro em conta + caixa físico (líquidos), dividido pela média
semanal de saídas dos últimos três meses. Devolve *quantas semanas o negócio
aguenta ao ritmo actual*.

**Porque está no topo.** O dado empírico é impossível de ignorar: cerca de **82%
das PMEs que fecham apontam problemas de tesouraria como causa principal ou
contributiva**, e um inquérito da JPMorgan Chase estima que a PME mediana tem
apenas cerca de 18 dias de almofada. Um estudo da Bluevine indica que 39% das
pequenas empresas não cobrem um mês inteiro de despesas. Não há métrica que
denuncie mais cedo a possibilidade concreta de encerrar portas.

Ram Charan, em *What the CEO Wants You to Know* e em *Execution*, usa a imagem do
oxigénio: uma empresa pode ser rentável nos livros e sufocar por falta de caixa,
por isso "a coisa mais importante é a geração contínua de cash flow, projectada
numa base muito conservadora". Warren Buffett e Charlie Munger reforçam-no com
outra lente: preferem *free cash flow* a EBITDA porque a depreciação, os
recebimentos lentos e o CapEx são custos reais, e o EBITDA finge que a fada dos
dentes paga os camiões (a expressão é de Buffett; Munger classificou o EBITDA
como "horror ao quadrado").

**O que denuncia mais cedo.** Uma queda no runway sinaliza, semanas antes das
demonstrações trimestrais, três coisas em simultâneo: recebimentos a abrandar,
custos fixos a subir, ou capital estagnado em stocks e clientes por cobrar. É o
único KPI que dá margem para reagir *antes* da crise, não durante.

**Armadilha que evita.** A pior armadilha da PME portuguesa é achar que **lucro
provisório = tesouraria**. Não é: o subsídio de férias (Junho) e o de Natal
(Novembro) são saídas de milhares de euros que não aparecem no resultado do mês
corrente porque foram sendo devidas ao longo do ano. Um runway em semanas obriga
o gestor a olhar para o próximo pico de pagamento, não para o próximo mês médio.

**Nota.** Runway sozinho não chega — precisa de contexto sazonal. Para o Punho,
isto sugere que a projecção deve absorver os padrões conhecidos: aluguer com pico
no Verão, TSU mensal em dia útil fixo, subsídios em duas datas do ano.

### 2. Margem bruta e a sua trajectória

**Fórmula.** (Receita − custos directamente ligados à receita) ÷ Receita, medido
por mês e comparado com os três a doze meses anteriores. Custos directos incluem
tudo o que sobe quando a receita sobe: consumíveis, mão-de-obra directa, taxas
por transacção, combustível quando a frota é o produto.

**Porque está no topo.** É o único KPI que responde à pergunta *cada venda vale
a pena?*. Uma empresa pode ter mais receita e menos margem bruta e estar a piorar
enquanto acha que cresce. Vários analistas de PMEs de serviços defendem um
**limiar prático de 60% de margem bruta** como sinal de saúde — abaixo disso, o
negócio não gera folga suficiente para cobrir estrutura, marketing e reinvestimento
sem se esticar; acima, há oxigénio para decidir. Não é uma regra universal (varia
com o sector), mas é uma boa vara para agitar o gestor médio quando a margem cai.

Peter Drucker, em *Management: Tasks, Responsibilities, Practices*, defendeu que
o trabalho implica *responsabilidade, prazo e medição dos resultados* — o
feedback do resultado sobre o trabalho é o que permite ajustar. A frase popular
"o que se mede gere-se", que muitas vezes lhe atribuem, não é dele (é do
sociólogo V. F. Ridgway, 1956) e o próprio Drucker avisou que nem tudo o que
importa se consegue medir. Ainda assim, a margem bruta é dos poucos indicadores
que quase todos os autores concordam ser um imperativo mensal.

**O que denuncia mais cedo.** Erosão de preço, aumento invisível de custo
directo, mistura de produtos a mudar para menos rentáveis, ou concessão excessiva
de descontos que a equipa comercial faz "para fechar". Uma queda de 2 pontos
percentuais na margem bruta durante três meses seguidos costuma preceder o
sofrimento na tesouraria por 60 a 90 dias.

**Armadilha que evita.** Confundir *problema de margem* com *problema de custos
fixos*. Se a margem bruta está saudável mas o resultado final é magro, o
problema é overhead — cortar rendas ou reorganizar; se a margem bruta é magra, o
problema é preço ou custo directo — mexer na tabela ou renegociar fornecedores.
Sem separar as duas coisas, o gestor tende a cortar do lado errado.

### 3. Cash Conversion Cycle (CCC) — ciclo de conversão de tesouraria

**Fórmula.** DIO + DSO − DPO, em dias. Isto é: dias em que o dinheiro está preso
em stock, mais dias em que está preso em clientes por cobrar, menos dias em que
o negócio ainda não pagou aos fornecedores. Para uma PME de aluguer, DIO
substitui-se por *dias médios de imobilizado inactivo entre alugueres* — a
mesma lógica: dinheiro parado.

**Porque está no topo.** Verne Harnish em *Scaling Up* faz do CCC uma das
"quatro decisões" (Pessoas, Estratégia, Execução, **Caixa**) e defende que se
deve dividir em quatro etapas — venda, entrega, facturação/cobrança, e
produção/inventário — para trabalhar cada uma. É a métrica que traduz em dias o
que os autores contabilísticos traduzem em euros, e por isso é a mais didáctica
das três: o gestor percebe que se cobrar 15 dias mais cedo, tem mais 15 dias de
oxigénio de graça, sem precisar de nova venda nem de novo empréstimo. Harnish
chama-lhe "Power of One" — quanto vale mudar em um dia ou um por cento cada
alavanca.

**O que denuncia mais cedo.** Perda de disciplina na cobrança (DSO a subir),
imobilizado a envelhecer sem ser reposto (DIO a subir), ou perda de leverage
com fornecedores que estão a exigir pagamento mais rápido (DPO a cair). Cada
uma destas mudanças é invisível no P&L mensal, mas aparece no CCC.

**Armadilha que evita.** Crescer para a falência. É contra-intuitivo mas
comprovado: uma empresa a crescer 20% ao ano com CCC de 60 dias precisa,
todos os meses, de mais caixa do que a que teve no mês anterior — porque o
capital circulante tem de crescer à mesma velocidade. Se o CCC não se reduz
enquanto a receita cresce, o negócio é uma máquina de queimar dinheiro
disfarçada de sucesso.

**Nota sobre debates.** Há quem prefira medir isto em euros (working capital
absoluto) e não em dias. A vantagem dos dias é pedagógica: o gestor médio
entende "os meus clientes pagam-me em 47 dias e eu pago aos meus em 30" muito
mais depressa do que entende variações no fundo de maneio.

---

## Parte B — Os 15 KPIs essenciais

Organizados em cinco categorias. A ordem dentro de cada categoria vai do mais
básico para o mais avançado.

### Dinheiro e Liquidez

Esta categoria responde a *estou vivo?*. Sem estes números, nenhum dos outros
importa.

**1. Saldo de tesouraria disponível (cash on hand).**
*Fórmula:* dinheiro em conta + caixa físico, líquidos.
*Na cabeça do gestor:* "quanto dinheiro tenho agora se tudo parasse hoje?".
*Referência:* consenso de todos os autores; para uma PME, ter 3 a 6 meses de
despesas fixas cobertas é o alvo (Bookkeeping Express, AdaptCFO). Realidade
observada: 39% das PMEs têm menos de um mês (Bluevine).
*Sinal de alerta:* qualquer descida abaixo de 2 meses; qualquer semana em que o
saldo cai e não é um pagamento pontual reconhecido.
*Fonte teórica:* Ram Charan, *Execution*; Warren Buffett e Charlie Munger sobre
free cash flow.

**2. Runway em semanas (autonomia).**
*Fórmula:* saldo disponível ÷ média semanal de saídas (últimos 90 dias),
ajustada por saídas conhecidas nas próximas 8 semanas (subsídio de férias, TSU,
IVA, IRC, rendas semestrais).
*Na cabeça do gestor:* "quantas semanas aguento sem precisar de vender mais um
euro".
*Referência:* mínimo confortável de 12 semanas; ideal 24+; alerta abaixo de 8.
*Sinal de alerta:* runway a diminuir três semanas seguidas mesmo com receita
constante — significa que os custos estão a crescer sem que o gestor tenha
notado.
*Fonte teórica:* prática consensual de CFOs de PME.

**3. Cash Conversion Cycle (CCC).**
*Fórmula:* dias médios em stock + dias médios de cobrança − dias médios de
pagamento a fornecedores.
*Na cabeça do gestor:* "quantos dias o meu dinheiro está a trabalhar em vez de
estar comigo".
*Referência:* varia com o sector; para PME de serviços/aluguer, 15 a 30 dias é
saudável; acima de 60 exige atenção.
*Sinal de alerta:* trajectória a subir mesmo com margem bruta estável.
*Fonte teórica:* Verne Harnish, *Scaling Up* (uma das "quatro decisões").

**4. DSO — Dias médios de cobrança.**
*Fórmula:* (contas a receber ÷ receita a crédito no período) × dias do período.
*Na cabeça do gestor:* "os meus clientes demoram quantos dias, em média, a
pagar-me".
*Referência:* 30 a 45 dias é bom em muitos sectores; em Portugal, com cultura de
30/60 dias, 45 é o realista, 60 é o limiar de dor.
*Sinal de alerta:* subida de 10 dias em três meses; concentração acima de 90 dias
num único cliente.
*Fonte teórica:* consenso de gestão de tesouraria (Salesforce, Stax Payments,
Upflow).

### Rentabilidade

Esta categoria responde a *o que faço vale a pena?*. Sem margem, o crescimento
acelera a falência.

**5. Margem bruta % e a sua tendência.**
*Fórmula:* (receita − custos directos) ÷ receita, medido mês a mês.
*Na cabeça do gestor:* "quanto sobra de cada euro que facturo, antes de contas
fixas".
*Referência:* para serviços, 60% é a vara curta usada por vários CFOs
(Bennett Financials, Eagle Rock CFO); abaixo é sinal de "estás a sangrar sem
notar".
*Sinal de alerta:* três meses de descida consecutiva, mesmo que pequena.
*Fonte teórica:* Peter Drucker (imperativo de medir para gerir); consenso
contabilístico.

**6. Margem operacional / EBIT.**
*Fórmula:* (receita − custos directos − custos operacionais fixos) ÷ receita.
*Na cabeça do gestor:* "quanto sobra depois de pagar toda a estrutura do
negócio, antes de impostos e juros".
*Referência:* PME de serviços saudável 10–20%; abaixo de 5% é frágil.
*Sinal de alerta:* margem operacional a divergir da margem bruta — significa
que a estrutura (rendas, salários fixos, seguros) cresceu mais depressa do que a
receita.
*Fonte teórica:* análise financeira clássica.

**7. Free Cash Flow (fluxo de caixa livre).**
*Fórmula:* cash flow operacional − CapEx (investimento em imobilizado, reposição
de máquinas).
*Na cabeça do gestor:* "o que sobra em dinheiro real depois de pagar contas e
repor o que se estragou".
*Referência:* deve ser positivo em anos normais; negativo só se justifica em
anos de expansão declarada.
*Sinal de alerta:* FCF negativo dois trimestres seguidos sem plano de expansão
formal.
*Fonte teórica:* Warren Buffett e Charlie Munger (preferem FCF a EBITDA
precisamente porque incorpora reposição de activos).
*Debate registado:* alguns defendem EBITDA como proxy útil por ser mais rápido
de calcular (não exige rastrear CapEx). O consenso em ambientes de PME é que
EBITDA sem CapEx explícito é enganador em negócios de aluguer, onde o desgaste
das máquinas é o custo principal disfarçado.

### Operação e Uso da Capacidade

Esta categoria responde a *o que tenho está a render?*. Para negócios de
aluguer, é onde se ganha ou perde a guerra.

**8. Taxa de ocupação / utilização.**
*Fórmula:* horas (ou dias) que o activo esteve alugado ÷ horas (ou dias)
disponíveis, num período.
*Na cabeça do gestor:* "as minhas máquinas trabalham ou dormem?".
*Referência:* na indústria de aluguer de equipamento, média ronda 55%; líderes
alcançam 65–75%; abaixo de 50% há excesso de frota (Targit, Quipli, Construction
Executive).
*Sinal de alerta:* activos individuais abaixo de 30% durante mais de 60 dias.
*Fonte teórica:* Jim Collins, *Good to Great* — o "denominador económico"
(profit per X). Para um negócio de aluguer, o X natural é *lucro por
máquina-dia*, que é a versão fina desta métrica.

**9. Receita média por transacção (ticket médio) e trajectória.**
*Fórmula:* receita total ÷ número de transacções (ou alugueres), no mesmo
período.
*Na cabeça do gestor:* "quanto vale, em média, cada vez que fecho um negócio".
*Referência:* medir por trimestre; a evolução importa mais que o valor absoluto.
*Sinal de alerta:* ticket a cair mais depressa que o número de transacções a
subir — significa desconto silencioso ou mistura para produtos mais baratos.
*Fonte teórica:* Verne Harnish (a "Power of One" — quanto muda o resultado se o
preço subir 1%).

**10. Ratio custos operacionais / receita.**
*Fórmula:* custos operacionais totais do mês ÷ receita do mês.
*Na cabeça do gestor:* "de cada euro que entrou, quanto foi para pagar a máquina
a funcionar".
*Referência:* verde < 60%, amarelo 60–80%, vermelho > 80% — que é exactamente o
semáforo já usado no Punho.
*Sinal de alerta:* dois meses consecutivos no vermelho.
*Fonte teórica:* consenso de gestão operacional.

### Comercial e Aquisição

Esta categoria responde a *tenho procura suficiente para manter o negócio?*.

**11. Leads gerados e taxa de conversão.**
*Fórmula:* número de contactos qualificados no período; conversão = negócios
fechados ÷ leads no mesmo período.
*Na cabeça do gestor:* "quantas oportunidades entram, e de cada dez quantas
fecho".
*Referência:* varia muito com o canal; para PME de serviços, conversão de 20–40%
em leads inbound é normal.
*Sinal de alerta:* leads a subir com conversão a cair — significa qualidade de
lead pior ou processo comercial saturado.
*Fonte teórica:* consenso de gestão comercial; Kaplan e Norton (perspectiva do
cliente no *Balanced Scorecard*).

**12. Custo de aquisição de cliente (CAC).**
*Fórmula:* custo total de marketing e vendas no período ÷ novos clientes
adquiridos no mesmo período.
*Na cabeça do gestor:* "quanto me custa, em média, pôr um cliente novo a dentro
da porta".
*Referência:* só faz sentido em relação ao LTV (ver KPI 14); rácio LTV:CAC de
pelo menos 3:1 é o piso de Bill Aulet (*Disciplined Entrepreneurship*) e David
Skok. Cuidado: 3:1 foi originalmente um chão para SaaS maduro, não um alvo
universal.
*Sinal de alerta:* CAC a subir mais depressa que o ticket médio.
*Fonte teórica:* Bill Aulet, *Disciplined Entrepreneurship*; David Skok
(For Entrepreneurs).
*Debate registado:* alguns defendem que **payback period do CAC** (quantos meses
até recuperar o custo de aquisição) é mais operacional para PME que rácio
LTV:CAC, porque o LTV depende de uma projecção incerta. O próprio Skok recomenda
gerir os dois em conjunto — payback no curto prazo, LTV:CAC no longo.

**13. Pipeline coverage (cobertura do funil).**
*Fórmula:* valor de reservas e leads confirmadas para os próximos 2 a 4
semanas ÷ receita objectivo do mesmo período.
*Na cabeça do gestor:* "o negócio que já tenho à porta cobre o que preciso de
facturar?".
*Referência:* cobertura de 1,5–2× é confortável para PME de serviços; abaixo de
1× é aviso.
*Sinal de alerta:* cobertura a cair semana a semana; concentração num único
cliente grande.
*Fonte teórica:* prática consensual de gestão de vendas.

### Cliente e Retenção

Esta categoria responde a *estou a construir base ou apenas a rodar clientes?*.
É onde os autores modernos mais insistem — e onde a maior parte das PMEs mede
menos.

**14. Percentagem de receita de clientes recorrentes (repeat revenue).**
*Fórmula:* receita gerada por clientes que já compraram antes ÷ receita total do
período.
*Na cabeça do gestor:* "quanto do que ganho este mês vem de clientes que já
conhecem a casa".
*Referência:* estudos mostram que para cerca de 61% das PMEs, mais de metade da
receita vem de clientes recorrentes. Um aumento de 5% na retenção pode aumentar
os lucros entre 25% e 95% (dados citados por Fred Reichheld a partir da
investigação da Bain & Company).
*Sinal de alerta:* percentagem abaixo de 40% em negócios de serviços recorrentes;
descida trimestral consecutiva.
*Fonte teórica:* Fred Reichheld, *The Ultimate Question* — a lealdade é
económica, não sentimental.

**15. NPS ou proxy de satisfação.**
*Fórmula:* % de promotores (nota 9–10) − % de detractores (nota 0–6) numa escala
de 0 a 10, à pergunta "recomendaria este serviço a um amigo?".
*Na cabeça do gestor:* "os meus clientes falariam bem de mim?".
*Referência:* NPS positivo é o mínimo; acima de 50 é excelente para PME de
serviços.
*Sinal de alerta:* NPS a cair, ou concentração de detractores num tipo de
serviço específico.
*Fonte teórica:* Fred Reichheld (Bain & Company), *The Ultimate Question*,
*Harvard Business Review*, 2003.
*Nota prática:* para PME muito pequena, um proxy pragmático (uma pergunta por
SMS ou WhatsApp após cada aluguer, "de 1 a 5, correu bem?") tem valor
equivalente sem a fricção do NPS formal.

---

## Parte C — Cruzamento com o painel actual do Punho (v0.0.5)

Avaliação fria: **coberto** significa que o número existe hoje e responde à
pergunta na cabeça do gestor; **parcial** significa que existe algo próximo mas
com lacunas materiais; **não coberto** é o que falta por completo.

| KPI recomendado | Estado no Punho hoje |
|---|---|
| 1. Saldo de tesouraria disponível | Não coberto — o painel mostra fluxos (recebido, pago) mas não o saldo acumulado em conta e caixa. |
| 2. Runway em semanas | Não coberto — não há projecção de saídas nem cálculo de autonomia. |
| 3. Cash Conversion Cycle | Não coberto. |
| 4. DSO — dias médios de cobrança | Parcial — há "cobranças em atraso" e "por receber", mas não há dias médios agregados nem trajectória. |
| 5. Margem bruta % e tendência | Não coberto — o painel não distingue custos directos de custos de estrutura. |
| 6. Margem operacional / EBIT | Parcial — "resultado provisório" é uma aproximação assumidamente incompleta (não inclui contas por pagar). |
| 7. Free Cash Flow | Não coberto — não há CapEx nem reposição de máquinas separada. |
| 8. Taxa de ocupação / utilização | Coberto — "ocupação máquinas semana" mais "sem alugar há mais de 7 dias". |
| 9. Ticket médio e trajectória | Parcial — "valor médio por reserva" existe; a trajectória e a comparação temporal não estão explícitas no slide de máquinas. |
| 10. Ratio custos operacionais / receita | Coberto — com semáforo verde/amarelo/vermelho no slide 4. |
| 11. Leads e conversão | Coberto — "leads por contactar" + "taxa conversão 30d". |
| 12. CAC | Não coberto. |
| 13. Pipeline coverage | Parcial — "reservas confirmadas 2 semanas" existe, mas sem rácio contra objectivo mensal ou média histórica. |
| 14. % receita de clientes recorrentes | Não coberto. |
| 15. NPS ou proxy de satisfação | Não coberto. |

**Balanço.** Dos 15 KPIs, o Punho tem hoje **3 cobertos**, **4 parciais** e **8
não cobertos**. A força actual está na *operação* e na *entrada do funil
comercial* — que é natural para um vertical de aluguer e para uma app que começou
como registo operacional. A fraqueza é dupla: **tesouraria verdadeira** (saldo,
runway, CCC) e **cliente ao longo do tempo** (retenção, satisfação). O painel
mostra o mês em curso, mas não mostra se o negócio sobrevive ao próximo
trimestre nem se está a construir base de clientes.

---

## Parte D — Recomendações para as próximas sprints (0.0.7+)

Cinco lacunas que valem sprint dedicada, por ordem de urgência para a saúde do
negócio e não por facilidade técnica.

### 1. Saldo de tesouraria + runway em semanas (Slide 1, célula nova)

Substituir ou complementar uma das quatro células do slide "Dinheiro do mês" por
uma célula com **saldo actual** e **semanas de autonomia projectadas** (com o
próximo pico de saída conhecido — subsídio de férias, TSU, IVA). Sem isto, a
pergunta *estou vivo?* fica sem resposta. O trabalho envolve modelar entradas e
saídas como stock, não só como fluxo, e mostrar o subsídio de férias e IRC como
saídas futuras já devidas.

### 2. Margem bruta separada de estrutura

O actual "% custos vs receita" é útil mas junta tudo. Separar em dois números —
**margem bruta** (receita menos custos que variam com a receita) e **peso da
estrutura** (custos fixos sobre receita) — permite ao gestor perceber onde
mexer. Se a margem cai, é preço ou custo directo; se a estrutura pesa mais, é
overhead. Esta separação exige uma classificação nova nas despesas (fixa vs
variável) que pode ser feita com uma flag e um valor padrão inteligente por
categoria já existente.

### 3. Percentagem de receita de clientes recorrentes (repeat rate)

O Punho já tem clientes, reservas e recebimentos — os dados existem, falta só o
cruzamento. Um número no slide 2 ou 3 do tipo "**68% da receita deste mês veio
de clientes que já tinham alugado antes**" ensina imediatamente ao gestor onde
está o seu ouro. A investigação de Fred Reichheld e da Bain é clara: cada 5%
de aumento em retenção pode representar 25 a 95% de aumento de lucro. Nenhum
KPI comercial pago em publicidade tem este *leverage* natural.

### 4. Cash Conversion Cycle simplificado (DSO + dias de imobilizado inactivo − DPO)

Uma célula pedagógica: "**o teu dinheiro está preso 47 dias em média**", com o
detalhe abaixo em três parcelas (cobrança, imobilizado parado, pagamento a
fornecedores). Pode viver no slide 1 ou num slide novo "Saúde do circulante".
Esta é a métrica com maior valor didáctico da lista — traduz em dias uma
realidade que os gestores só entendem depois de um susto de tesouraria. O
Punho pode ensinar sem susto.

### 5. NPS / proxy de satisfação e ligação à "Recomendação do dia"

Uma pergunta única após cada aluguer devolvido — "correu bem? 1 a 5" via
WhatsApp ou dentro da app do colaborador — alimenta um número no slide 5 e
gera uma nova regra na "Recomendação do dia": "*cliente X deixou uma nota
baixa há 2 dias — vale um telefonema*". Isto fecha o ciclo entre observação e
acção, que é a promessa do produto, e é barato: os canais (WhatsApp) e o
ecrã do colaborador já existem.

---

## Notas metodológicas

- Nenhuma citação foi inventada. Onde a fonte é consensual de gestão sem autor
  específico, foi apresentada como consenso.
- A frase "o que se mede gere-se" é frequentemente atribuída a Peter Drucker,
  mas não é dele; a origem plausível é V. F. Ridgway (1956), que a usou como
  crítica ao excesso de medição. O verdadeiro Drucker é mais cauteloso e
  distingue entre o que é medível e o que só se consegue julgar.
- Debates registados: EBITDA vs Free Cash Flow (Buffett/Munger vs escolas de
  M&A); LTV:CAC vs Payback do CAC (Aulet e Skok reconhecem que o segundo é mais
  operacional para PME); rácio 3:1 em LTV:CAC (originalmente um piso, não um
  alvo — muito mal-interpretado).
- Contexto português assumido: cobranças a 30/60 dias, TSU 23,75% patronal,
  subsídios de férias e Natal como saídas semestrais, IVA trimestral ou mensal
  conforme volume. Estes ciclos entram no cálculo do runway e na projecção de
  tesouraria.

## Fontes

- **Verne Harnish, Scaling Up.** [Book Summary and Review — Virtual Assistant Reviewer](https://virtualassistantreviewer.com/book-summary-and-review-scaling-up-by-verne-harnish/); [The Four Decisions: Cash — Hayley Erner](https://www.hayleyerner.com/scaling-up/cash/); [Scaling Up Cash — A Player Advantage](https://aplayeradvantage.com/scaling-up-cash-why-your-revenue-to-cash-cycle-starts-with-your-sales-team-how-to-make-your-sellers-more-effective/).
- **Jim Collins, Good to Great.** [Articles — Jim Collins](https://www.jimcollins.com/article_topics/articles/good-to-great.html); [The Hedgehog Concept — Jim Collins](https://www.jimcollins.com/concepts/the-hedgehog-concept.html); [Find Your Economic Denominator — Positioning Systems](https://strategicdiscipline.positioningsystems.com/bid/96328/Find-Your-Economic-Denominator-Profit-per-X).
- **Kaplan and Norton, Balanced Scorecard.** [The Four Perspectives — Balanced Scorecard Institute](https://balancedscorecard.org/bsc-basics/articles-videos/the-four-perspectives-of-the-balanced-scorecard/); [Balanced Scorecard — Tutor2u](https://www.tutor2u.net/business/reference/balanced-scorecard-introduction-overview).
- **Ram Charan, Execution / What the CEO Wants You to Know.** [Book Summary — Shortform](https://www.shortform.com/pdf/what-the-ceo-wants-you-to-know-pdf-ram-charan); [Cash, Strategy and Crisis — StrategicCFO360](https://strategiccfo360.com/ceos-cash-and-covid-what-every-company-must-do-asap/); [What the CEO Wants You to Know — Bestbookbits](https://bestbookbits.com/what-the-ceo-wants-you-to-know-by-ram-charan-book-summary/).
- **Peter Drucker — origem da frase "what gets measured gets managed".** [It's wrong and Drucker never said it — Centre for Public Impact](https://medium.com/centre-for-public-impact/what-gets-measured-gets-managed-its-wrong-and-drucker-never-said-it-fe95886d3df6); [The fallacy of what gets measured — Ness Labs](https://nesslabs.com/what-gets-measured-gets-managed).
- **Fred Reichheld, The Ultimate Question / Net Promoter Score.** [The Ultimate Question 2.0 — Amazon page](https://www.amazon.com/Ultimate-Question-2-0-Companies-Customer-Driven/dp/1596597623); [Winning on Purpose — Medallia](https://www.medallia.com/blog/lessons-from-customer-loyalty-guru-fred-reichheld/); [Fred Reichheld — Bain & Company](https://www.bain.com/our-team/fred-reichheld/).
- **Bill Aulet, Disciplined Entrepreneurship.** [Cost of Customer Acquisition — d-eship.com](https://www.d-eship.com/step19/); [Calculate the LTV of an Acquired Customer — O'Reilly](https://www.oreilly.com/library/view/disciplined-entrepreneurship-24/9781118692288/26_chap17.html); [Book Review — Startup Musings](https://startupmusings.wordpress.com/2013/08/19/disciplinedentrepeurship-24steps/).
- **David Skok — LTV:CAC debate.** [LTV:CAC Ratio Benchmarks 2026 — PM Toolkit](https://pmtoolkit.ai/benchmarks/ltv-cac-ratio-benchmarks); [LTV:CAC Ratio Trap — Marketing Case Bootcamp](https://www.marketingcasebootcamp.com/post/the-ltv-cac-ratio-trap-why-3x-is-the-wrong-benchmark-for-most-startups); [LTV-CAC vs Payback Period — Monetizely](https://www.getmonetizely.com/articles/ltv-cac-vs-payback-period-which-one-should-you-prioritize).
- **Warren Buffett & Charlie Munger sobre EBITDA vs FCF.** [Warren Buffett Hates EBITDA — Inc. Magazine](https://www.inc.com/jim-schleckser/warren-buffet-hates-ebitda-you-should-too.html); [Munger's "horror squared" — Yahoo Finance](https://finance.yahoo.com/news/charlie-munger-explains-called-popular-earnings-measure-horror-squared-164228068.html); [Why Charlie Munger Despised EBITDA — brk-b.com](https://brk-b.com/why-charlie-munger-despised-ebitda_240201.html).
- **Cash flow como causa de falência em PME.** [82% of Small Businesses Fail from Cash Flow — SMBcompass](https://www.smbcompass.com/small-businesses-fail-cash-flow-data/); [Cash Flow Reasons — Preferred CFO](https://preferredcfo.com/insights/cash-flow-reasons-small-businesses-fail-2026); [Why Profitable Small Businesses Still Fail — Frequency Accounting](https://frequencyaccounting.com/why-most-small-businesses-fail-due-to-cash-flow/).
- **DSO — benchmarks e boas práticas.** [DSO Formula — Stax Payments](https://staxpayments.com/blog/days-sales-outstanding-formula/); [DSO Complete Guide — Salesforce](https://www.salesforce.com/sales/revenue-lifecycle-management/days-sales-outstanding-dso/); [DSO Formula — Upflow](https://upflow.io/blog/reduce-dso/dso-calculation-formula).
- **Cash runway — benchmarks PME.** [How to Calculate Cash Runway — Bookkeeping Express](https://bookkeepingexpress.com/how-to-calculate-cash-runway-small-business/); [39% of SMBs Have Less Than a Month — Bluevine](https://www.bluevine.com/blog/cash-flow-management-survey); [Truth About Cash Runway — AdaptCFO](https://www.adaptcfo.com/post/the-truth-about-cash-runway-a-founders-guide-to-staying-alive).
- **Margem bruta — benchmark para serviços.** [The 60% Gross Margin Benchmark — Bennett Financials](https://bennettfinancials.com/service-business-gross-margin-the-60-benchmark-and-why-your-business-is-bleeding-out/); [Gross Margin Benchmarks 2025-2026 — Eagle Rock CFO](https://www.eaglerockcfo.com/blog/profitability-guide/gross-margin-benchmarks); [Profit Margins by Industry — Holdings](https://getholdings.com/resources/blog/profit-margins-by-industry-benchmarks).
- **Utilização — indústria de aluguer de equipamento.** [Best KPIs for the Equipment Rental Industry — Targit](https://www.targit.com/en/blog/best-kpis-for-the-equipment-rental-industry); [Equipment Rental KPIs — Quipli](https://quipli.com/resources/top-kpis-for-a-rental-business/); [Six KPIs for the Equipment Rental Elite — Construction Executive](https://constructionexec.com/article/six-kpis-for-the-equipment-rental-elite/).
- **Retenção de clientes — impacto no lucro.** [Customer Retention — Zendesk](https://www.zendesk.com/blog/customer-experience/retention/customer-retention/); [Customer Retention Statistics — Flowlu](https://www.flowlu.com/blog/crm/customer-retention-statistics/); [Retention Rate by Industry — Focus Digital](https://focus-digital.co/average-customer-retention-rate-by-industry/).
- **Contexto português — subsídio de férias.** [Subsídio de férias em Portugal — Factorial](https://factorialhr.pt/blog/subsidio-ferias-portugal/); [Duodécimos ou por inteiro — Xfin](https://www.xfin.pt/blog/subsidio-de-ferias-duodecimos-ou-por-inteiro).

---

## Parte E — Estado a 10 de Agosto de 2026

**Os oito não cobertos deixaram de o estar.** Entraram no catálogo
(`lib/features/dashboard/presentation/kpi_catalogo.dart`) e as contas vivem em
`lib/core/operations/kpis_de_saude.dart`, todas puras em `(estado, agora)` e
todas com teste em `test/features/dashboard/kpis_de_saude_test.dart`.

| Da auditoria | Entrada do catálogo | Fonte, e o que ela não é |
|---|---|---|
| 1+2. Saldo de tesouraria e runway | `saldo-e-autonomia` | recebimentos − despesas **pagas**, desde o primeiro movimento registado. **Não é o saldo bancário** — a app não fala com o banco, e a célula di-lo com a data desde quando conta |
| 3. Cash Conversion Cycle | `ciclo-de-tesouraria` | a versão simplificada da Parte D: DSO + dias de máquina parada − DPO, em 90 dias. O DPO sai das despesas marcadas por pagar, que é o mais perto de contas a pagar que há |
| 5. Margem bruta e tendência | `margem-bruta` | receita do mês menos os custos **directos**, com a variação em pontos face ao mês passado |
| 7. Free Cash Flow | `fluxo-de-caixa-livre` | operacional do mês menos as máquinas com `acquiredOn` neste mês |
| 12. CAC | `custo-de-aquisicao` | despesas de **Publicidade** em 90 dias ÷ clientes novos. É um **piso**: quem paga angariação por outra via não a tem aqui |
| 14. % receita de clientes recorrentes | `receita-recorrente` | fatia dos recebimentos do mês de quem já tinha reserva antes dele |
| 15. NPS / satisfação | `satisfacao-cliente` | **nenhuma** — fica em «Por definir» a dizer que falta o inquérito no fim da recolha. Escondê-lo era fingir a lista completa |

**A linha entre custo directo e custo de estrutura é uma decisão declarada**, e
está numa constante com nome (`custosDirectosDoAluguer`): manutenção de máquina,
combustível, manutenção de viatura e consumíveis. Renda, electricidade, água,
limpeza, salários, seguros e publicidade são estrutura — pagam-se com a máquina
parada. Nada nos dados traça esta linha sozinho; quem discordar discorda da
constante, e não de um número que apareceu do nada.

**Mais quatro, que não vinham desta auditoria:**

- `leads-frias` e `alertas-operacionais` — as duas peças que se perderam quando
  o painel deixou de ser slides. Os números equivalentes tinham ficado; a prosa
  que dizia o que fazer com eles, não;
- `gastos-previstos-mes` e `saldo-previsto-mes` — a futurologia: como o mês
  fecha se a tendência se mantiver. A base de cálculo (`previsaoDoMes`) já
  existia e ninguém a lia.

## Parte F — O crivo, 10 de Agosto de 2026

O César mandou verificar as contas e promover as que estivessem certas.
**Passaram 13; ficaram 2 de fora.** Ler cada fórmula contra o que a célula
promete deu **seis defeitos**, todos corrigidos antes de promover:

| Defeito | Onde | Porque é que mentia |
|---|---|---|
| A queima incluía o mês em curso | `saldoEAutonomia` | a 10 de Agosto o mês tem 10 dias de despesas; dividir por 3 meses baixava a média e **aumentava** a autonomia anunciada. Numa medida de risco é o erro que dói. Passou a usar meses **completos**, e só os que têm registo |
| O custo fixo contado duas vezes | `saldoEAutonomia` | sem rubricas, somava o total redondo do onboarding **e** a renda lançada como despesa. Agora, sem rubricas, fica a maior das duas |
| Margem de caixa contra custo lançado | `margemBruta` | a receita era o recebido e o custo era o lançado: atrasar um pagamento mudava a margem de dois meses. Passou a caixa dos dois lados |
| Máquina parada antes de existir | `cicloDeTesouraria` | a comprada ontem arrastava os 89 dias em que ainda não era da empresa — o ciclo **piorava por se ter investido** |
| «Gastou-se e não veio ninguém» sem haver reservas | `custoDeAquisicao` | pintava vermelho quando o que se passava era não haver como contar. Agora pede reservas |
| «0 por contactar» sem uma única lead | `kpiLeadsPipeline` | fonte vazia a passar por zero verdadeiro. Só apareceu **porque** foi promovido: pôs uma empresa acabada de abrir com um «pronto» a fingir |

Mais duas correcções de texto, que não são contas mas eram afirmações falsas:
os **gastos previstos** diziam «mais o que já foi lançado» quando são a média
das variáveis dos meses com registo; as **leads a arrefecer** diziam «parada há
N dias» quando a lead só guarda quando **entrou**, não quando foi tocada. E as
«leads em pipeline» passaram a dizer no subtexto quantas estão **em aberto** —
um gestor com dez leads todas contactadas lia «0» debaixo do rótulo «pipeline».

**Os dois que não passam, e porquê:**

- **`recomendacao-dia`** — não é uma conta, é prosa tirada dos sinais dos outros
  KPIs. Assinar isto era assinar por tabela tudo o que ela lê;
- **`satisfacao-cliente`** — não há fonte nenhuma. Fica em «Por definir» a dizer
  que falta o inquérito, que é o seu trabalho.
