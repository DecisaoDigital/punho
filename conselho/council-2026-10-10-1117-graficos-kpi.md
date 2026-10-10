# Council — gráficos de KPIs no Fist (2026-10-10)

## Pergunta do César
Quais os gráficos devemos colocar lá, para quem gosta de medir KPIs por gráfico? E quais devemos comparar entre si?

## Enquadramento
PERGUNTA DO CÉSAR (dono do produto): «Quais os gráficos devemos colocar lá, para quem gosta de medir KPIs por gráfico? E quais devemos comparar entre si?»

CONTEXTO
- «Lá» = o Fist (app Android em Flutter), gestão para pequenas empresas portuguesas que alugam máquinas/serviços (ex.: clínica de depilação laser, lavandarias): reservas, clientes, leads, máquinas, veículos, colaboradores, despesas, recebimentos.
- Hoje o painel mostra KPIs sobretudo como números em células (cartões): Vendas do mês, Lucro do mês, Lucro do mês anterior, Estrutura (custos fixos), Break even do mês, Caixa, Tendência do mês (previsão do fecho), Dinheiros que entraram, Utilização vs Rentabilidade (por máquina), Máquina parada, Encontro de contas, Reservas activas, Entregas hoje, Cobranças a vencer (7d), Em atraso, Clientes novos (30d), Leads em pipeline, Ticket médio, Conversão lead→cliente, Saldo e autonomia, Margem bruta, Ciclo de tesouraria, Contas a pagar, Fluxo de caixa livre, Custo de aquisição, Receita de quem volta, Satisfação do cliente.
- Dados disponíveis: movimentos diários (vendas, recebimentos, despesas por categoria), reservas por máquina e por mês, histórico mensal dos anos anteriores (introduzido pelo contabilista), previsão do fecho do mês, comparação com o mesmo mês do ano passado.
- Utilizadores: gestor/dono de PME (pouco tempo, não é analista), no telemóvel, muitas vezes deitado (ecrã largo e baixo; com o teclado aberto sobram ~190 dp de altura).
- Restrições: o César prefere código próprio a bibliotecas de terceiros; o painel é montado pelo próprio gestor (escolhe que KPIs mostrar); mês a decorrer é acumulado, nunca pro-ratado; «aproximado marcado é melhor que vazio».
- Em jogo: quais gráficos construir primeiro (esforço real), e que pares/conjuntos de métricas ver lado a lado sem enganar o leitor.
- Não informado: o que os clientes actuais pedem; se há gráficos já pedidos por clientes; a preferência concreta do César.

O QUE SE PEDE: recomendar (1) a lista de gráficos, por ordem de prioridade, com o tipo de gráfico; (2) que métricas comparar entre si e como (mesmo eixo, lado a lado, sobrepostos), e quais NÃO comparar.

## Opinião do Claude (escrita antes, não dada aos conselheiros)

Pergunta: que gráficos pôr no Fist para quem gosta de medir KPIs por gráfico, e quais comparar entre si.

Princípio: um gráfico só entra se responder a uma decisão que o gestor toma (comprar/vender máquina, cortar custo, pedir dinheiro, contratar), e só se for lido em 3 segundos num telemóvel deitado.

Gráficos que poria (máx. 5 no painel):
1. Vendas vs despesas por mês, 12 meses (barras agrupadas), com a linha do lucro.
2. Break even do mês em acumulado diário: vendas acumuladas a subir contra a linha horizontal do alvo (mostra o dia em que "paga o mês").
3. Utilização vs rentabilidade por máquina (barras horizontais ou dispersão): ocupação % contra €/hora — decide que máquina comprar, vender ou promover.
4. Caixa: saldo e previsão (linha com banda), com a autonomia em dias.
5. Custos por categoria ao longo do tempo (barras empilhadas, nunca pizza).
Secundários (dentro do KPI, não no painel): funil leads → reservas → cobrado; cobranças por antiguidade (a vencer / em atraso).

O que comparar entre si:
- Este mês vs mês anterior vs mesmo mês do ano passado, no mesmo eixo (o homólogo é o que a app já calcula).
- Vendas vs break even (o gráfico 2).
- Utilização vs rentabilidade, por máquina.
- Entradas vs saídas de caixa (dinheiro), separado de vendas vs despesas (competência) — misturar os dois engana.
- Previsto vs realizado no fecho do mês.
Evitar: pizzas, dois eixos, mais de 12 pontos por série, cor como único sinal.

## Respostas anónimas

## A
Primeiro passo: widget próprio de barras em CustomPainter, 1–2 séries e linha de referência; uma só primitiva serve os gráficos 1–4. Plano de 7 dias: (1) Este mês vs mesmo mês do ano passado (barras lado a lado, mesmo eixo; mês a decorrer acumulado, previsão tracejada «aproximado»); (2) Vendas vs despesas 12 meses; (3) Break even como barra de progresso do lucro acumulado contra a estrutura; (4) Utilização vs rentabilidade por máquina em barras horizontais, cada métrica com escala própria identificada; (5) Despesas por categoria em barras ordenadas. Dia 7: teste no Redmi e catálogo de gráficos escolhível no painel. Comparar no mesmo eixo (€): vendas/despesas/lucro, mês vs ano passado, caixa vs contas a pagar. Lado a lado com eixos separados: utilização(%) vs rentabilidade(€), leads vs conversão. NÃO: € com % ou contagens no mesmo eixo; mês a decorrer com mês fechado sem marcar acumulado; previsão com realizado sem distinguir; margem bruta com ciclo de tesouraria. Bloqueio: histórico só existe onde o contabilista o introduziu. Posição: viável, 5 gráficos próprios sobre uma primitiva em ~1 semana. Confiança média.

## B
Percebi: painel de ~24 cartões com números. Não percebi: termos como break even, autonomia, fluxo de caixa livre, custo de aquisição — o dono sabe o que são?; qual é a pergunta que o dono faz de manhã. Desistia no cartão 8: 24 números sem ordem nem destaque; acrescentar gráficos piora (24 gráficos). Perguntas ingénuas: «Estou a ganhar ou a perder este mês?» (qual cartão responde em 2 s?); «Isto está bom ou mau?» (um número sem referência não diz nada); «O que faço agora?». Resposta: no máximo 4 gráficos, cada um a responder a uma pergunta: linha Vendas vs Custos fixos com break even como linha horizontal mês a mês; barras este mês vs anterior; barras por máquina; linha da Caixa. Comparar só o que partilha unidade e pergunta (euros com euros ao longo do tempo); não comparar % com euros nem contagens com dinheiro. O resto fica em cartões; quem quer mais abre uma segunda página. Posição: confuso — o problema é haver demasiados números sem hierarquia. Confiança média.

## C
Falha fatal: construir «gráficos de KPIs» como espelho dos ~27 cartões — no telemóvel deitado (~190 dp com teclado, ~360 sem) ficam mini-gráficos ilegíveis; quem gosta de medir por gráfico é minoria; o dono quer saber «estou a ganhar ou a perder?»; esforço alto (código próprio: eixos, toque, tooltips, dark mode, deitado) para uso baixo. Outras falhas: comparar escalas diferentes no mesmo eixo (uma achata-se); mês a decorrer (acumulado) ao lado do mês anterior fechado em barras parece «queda» até dia 25 — só curva acumulada dia a dia sobre dia a dia; histórico do contabilista esparso/à mão dá tendências falsas, «aproximado» tem de se ver no próprio gráfico; eixos duplos criam correlação aparente. Pior resultado: meses de trabalho, clientes ignoram, um gráfico enganador faz desligar uma máquina rentável. O decisor não sabe o que os clientes pedem: a pergunta é suposição. Recomendação: só 3 gráficos (1) linha acumulada do mês dia a dia vs mesmo mês do ano passado; (2) barras mensais vendas vs despesas com linha de break even; (3) barras horizontais por máquina, uma métrica só; validar uso real antes de mais. Recusar «um gráfico por KPI» e eixos duplos. Confiança média.

## D
O gráfico é o primeiro ecrã que conta uma história; os dados do Fist (histórico do contabilista, homólogo, previsão, reservas por máquina) são raros numa PME. Um gráfico «este mês acumulado vs mês anterior vs mesmo mês do ano passado, com break even e previsão tracejada» vale mais que quinze cartões. Prioridade (CustomPainter próprio): (1) linha acumulada do mês (vendas e despesas)+break even+previsão tracejada; (2) barras 12 meses vendas vs despesas com lucro como marca; (3) barras empilhadas de despesas por categoria por mês; (4) dispersão/barras por máquina utilização vs rentabilidade; (5) funil leads→clientes; (6) sparkline dentro de cada cartão existente. Comparar: vendas vs despesas no mesmo eixo; mês atual vs homólogo sobrepostos; recebido vs facturado; utilização vs rentabilidade. Não comparar: € com %; mês a decorrer com mês fechado sem marcar «acumulado até ao dia X»; ticket médio com volume. Adjacentes: gráfico partilhável (imagem por WhatsApp), anotações de eventos no eixo, alerta quando cruza o break even. Fazer um componente de série temporal reutilizável (pontos «real»/«aproximado»); ver deitado primeiro. Posição: linha acumulada do mês com break even e previsão primeiro, depois barras 12 meses, sobre um componente próprio. Confiança média.

## E
Problema reformulado: o gestor, em 10 s, quer saber se o negócio vai bem ou mal e porquê; não quer mais números desenhados. Os cartões dão valor atual; falta referência (mês anterior, homólogo, break even). Suposições a verificar: que os clientes querem gráficos (ninguém os pediu); que mais gráficos dão mais decisões. O gráfico só vale onde acrescenta trajetória e distância a uma referência. Solução: (1) barras mensais com linha de break even (12 meses, mês atual acumulado e marcado); (2) barras do mês atual vs mesmo mês do ano passado, mesma escala; (3) linha de caixa diária com previsão do fecho tracejada e marcada aproximada; (4) barras horizontais por máquina com Utilização e Rentabilidade em pares, ambas em %, mesma escala; (5) despesas por categoria em barras ordenadas, nunca pizza. Comparar só grandezas da mesma unidade e escala, sempre contra uma referência. Não comparar € com %, mês a decorrer pro-ratado com mês fechado, Conversão com Ticket médio, Satisfação com receita. A pergunta «que gráficos» esconde «que referência dar a cada número»: construir a primeira série e perguntar a 3 clientes o que ainda falta. Posição: 4–5 gráficos de série e comparação contra referência, em código próprio, valem mais que um gráfico por KPI. Confiança média.

## Mapeamento
A=executor, B=forasteiro, C=contrariante, D=expansionista, E=primeiros-princípios

## Revisões cruzadas (ordem melhor→pior)
- primeiros-princípios: E>C>D>A>B
- contrariante: E>C>A>D>B
- expansionista: D>A>E>C>B
- executor: E>D>C>A>B
- forasteiro: E>C>D>A>B

Posição média: E 1,4 · C 2,6 · D 2,6 · A 3,4 · B 5,0
Falhas comuns apontadas: ninguém desenhou para ~190 dp deitado (nº de pontos, toque); ninguém verificou os dados reais; sem critério de sucesso/abandono; ninguém tratou «quem gosta de gráficos» como segmento (galeria escolhível); risco de gráfico enganar.
Verificação no código: Rentabilidade = % do investimento recuperado (kpi_catalogo.dart:890), logo Utilização e Rentabilidade são ambas % — E certo, A errado (disse €).

## Veredicto
(ver chat; resumo abaixo)
Recomendação: 5 gráficos em código próprio sobre uma primitiva de série temporal; começar pela linha acumulada do mês vs mês anterior/homólogo com break even e previsão tracejada; barras 12 meses vendas vs despesas com break even; Utilização vs Rentabilidade por máquina (ambas %); caixa; despesas por categoria. Comparar só mesma unidade/escala e sempre contra referência; nunca € com %, nunca mês a decorrer com mês fechado sem marcar «acumulado».
