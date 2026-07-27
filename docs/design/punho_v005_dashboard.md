# v0.0.5 — Painel em carrossel, barra lateral com rótulos, destino Tarefas

Branch: `feat/v005-dashboard-alavancas`.

## Antes e depois

**Antes:** 17 `_Metric` num `Wrap`, todos do mesmo tamanho, sem ordem nem
agrupamento. Por baixo, três painéis (comparação homóloga, frase da semana,
comando de crescimento), cinco botões de acção e quatro avisos condicionais. O
gestor tinha de escolher onde olhar e a app não ajudava — e "Recebido hoje: 0 €"
dizia-lhe que não tinha facturado, quando a verdade era que ainda não havia
registos.

**Depois:** cinco slides, cada um com uma **pergunta de gestão** no cabeçalho e
**quatro KPIs** que a respondem em conjunto.

Capturas em `screenshots/v005/`, geradas com dados fixos a 15 de Julho de 2026:

| Ficheiro | O que mostra |
|---|---|
| `1-dinheiro.png` | Slide 1 com movimento |
| `2-pipeline.png` | Slide 2 |
| `3-maquinas.png` | Slide 3 |
| `4-custos.png` | Slide 4 |
| `5-semana.png` | Slide 5 |
| `0-sem-movimentos.png` | Empresa configurada e sem um único registo |

Regenerar com
`flutter test --update-goldens test/features/dashboard/screenshots_test.dart`.

Duas notas sobre as imagens: os tipos de letra são carregados do sistema (o
`flutter test` não tem nenhum), portanto o desenho é fiel mas o tipo não é o do
telemóvel; e os rótulos dentro dos botões laranja saem como blocos escuros —
defeito do renderizador de testes com o peso 800, não da app. Os testes de widget
confirmam que o texto existe ("Cobrar →", "Feito", "Abrir Tarefas →").

## O mockup e este desenho não são a mesma coisa

`docs/mockups/dashboard_v2.html` é um painel de **três colunas com scroll**
(herói + tesouraria | procura + máquinas + frota | recomendação + acções). O
prompt desta sprint pede um **carrossel de cinco slides com grelha 2×2**. São
desenhos diferentes e não se podem confrontar lado a lado.

Segui o prompt para a estrutura e o mockup para a **linguagem visual**: barra de
88 dp com rótulos, badge vermelho de contagem, cartões de 12 px de raio com
bordo de 0,5 px, herói com bordo esquerdo laranja, verdes e âmbares das
tesourarias, avatar no fundo da barra. Quem comparar as imagens com o HTML vai
reconhecer a família, não o esqueleto.

## Os cinco agrupamentos, e porque são estes

Cada slide responde a **uma** pergunta. O critério de agrupamento não é o tema
("finanças", "operação") mas a **decisão** que o gestor tem em mãos.

### 1 · Dinheiro do mês — *estou a facturar o esperado? preciso de cobrar?*

Recebido (herói, com sparkline diária e navegação de mês) · Por receber · Pago ·
Resultado provisório.

Lêem-se como uma frase: **entrou** isto, **falta entrar** aquilo, **saiu** isto,
**sobra** aquilo. Nenhum dos quatro serve sozinho — "recebi 1320 €" só significa
algo ao lado do que falta receber e do que já saiu.

O resultado chama-se *provisório* e diz debaixo "faltam as contas por pagar,
portanto não é lucro". O painel antigo chamava-lhe "Resultado operacional
simples" e dava ilusão de lucro no dia 3 do mês, quando as despesas ainda não
tinham sido pagas.

### 2 · Pipeline e compromissos — *tenho negócio à porta? preciso de mais leads?*

Reservas confirmadas 14 dias (herói, com mini-calendário) · Leads por contactar ·
Conversão 30 dias · Cauções.

É o funil lido de baixo para cima: o que já está fechado, o que está à espera de
uma chamada, e a eficiência com que um vira o outro. Duas reservas confirmadas
são boas notícias ou más notícias dependendo de haver 12 leads ou zero atrás
delas.

### 3 · Rentabilidade das máquinas — *o que está a render? o que está parado?*

Ocupação da semana (herói, anel) · Mais alugadas · Sem alugar há mais de 7 dias ·
Valor médio por reserva.

Uma ocupação de 40% não diz o que fazer. Ao lado do top e das paradas, diz: é
esta que trabalha, é aquela que não sai do parque.

### 4 · Custos operacionais — *estou dentro do orçamento? onde corto?*

Custo da equipa (herói) · Custo da frota · Manutenção paga · **Custos sobre a
receita**.

Os três primeiros são rubricas; o quarto é o juízo sobre elas, e é o único com
semáforo (verde < 60%, amarelo 60–80%, vermelho > 80%). Sem ele, três números
grandes de custo não dizem se há problema.

### 5 · A minha semana — *o que faço hoje?*

Recomendação (herói, uma só) · Próximas 3 reservas · Tarefas pendentes ·
Cobranças com atraso.

O único slide que pede acção em vez de leitura. A recomendação tem bordo colorido
por gravidade — verde é convite, laranja é aviso, vermelho é risco a acontecer
agora — e dois botões: *Adiar 7 dias* e *Feito*.

## Onde foram as 17 métricas antigas

Nenhuma desapareceu. `TodasMetricasPage` ("Ver todas as métricas →", no slide 4)
tem a lista completa como estava, mais a comparação homóloga e a frase da semana.

| Métrica antiga | Onde está agora |
|---|---|
| Recebimentos do mês | Slide 1, herói |
| Por receber | Slide 1 |
| Despesas pagas do mês | Slide 1 ("Pago este mês") |
| Resultado operacional simples | Slide 1, reformulado como "provisório" |
| Recebido hoje | Só na lista completa — um dia isolado não decide nada |
| Despesas pagas hoje | Idem |
| Por pagar | Slide 4, dentro do total de custos |
| Leads por contactar | Slide 2 |
| Reservas desta semana | Slide 2, substituído por "confirmadas 14 dias" |
| Valor previsto em reservas confirmadas | Slide 2, ao lado da contagem |
| Máquinas paradas | Slide 3, como "sem alugar há mais de 7 dias" |
| Máquinas disponíveis | Slide 3, na sub-linha da ocupação |
| Máquinas identificadas / declaradas | Tarefas ("identificar N máquinas") |
| Colaboradores ativos / vagas | Slide 4, na sub-linha do custo da equipa |
| Custo estimado de colaboradores | Slide 4, herói |
| Custo estimado mensal de frota | Slide 4 |
| Comparação homóloga (painel) | Lista completa |
| Frase da semana / objectivo | Lista completa |
| Comando de crescimento | Slide 5, como recomendação única |
| Avisos condicionais (dados por completar, máquinas por identificar, colaboradores incompletos, frota sem veículos) | Destino **Tarefas** |
| Botões de despesa/recebimento/listas/sincronizar | Destino **Finanças** |

"Colaboradores ativos / vagas" continua a mostrar `X / 3`. O 3 é um limite fixo
no código e não vem de nada que o gestor tenha escrito — está identificado como o
próximo falso número a resolver, mas mexer nele é decisão de produto (é o
conceito de "vagas", que o `saveCollaborator` faz cumprir).

## Decisões técnicas

**`PageView`, não carrossel próprio.** Dá o swipe de tablet de graça, mantém
montados só os slides vizinhos e a animação é a do sistema. Um carrossel manual
só se justificaria para efeitos que aqui não valem nada. As setas laterais e as
teclas ← → existem porque num PC arrastar a página com o rato é desconfortável.

**Estado do slide activo:** `int` no `State` do painel, com `PageController`. Não
foi para provider: só o painel precisa de saber, e pô-lo global fazia com que
voltar ao painel mantivesse o slide antigo em vez de abrir no dinheiro.

**Estado do mês no slide 1:** local ao slide, reposto ao voltar ao mês corrente
quando o slide é remontado. Só o "Recebido" navega no tempo; os outros três
cards ficam no mês actual, senão o slide deixava de se ler como um conjunto.

**KPIs em funções puras** (`lib/core/operations/kpis.dart`), não em métodos do
controller. Testam-se sem `ProviderContainer` e recebem o `now` de fora — sem
isso os testes mudavam de resultado com o dia em que corressem. É o padrão que
`availableMachines` e `stoppedMachines` já seguiam.

**Zero por falta de dados devolve `null`.** Toda a camada de KPIs respeita isto e
o widget `KpiPorApurar` mostra "Por apurar" com a razão. Vale para: resultado do
mês sem movimentos, taxa de conversão sem leads, ocupação sem máquinas, ticket
médio sem valores, peso dos custos sem receita, tendência sem termo de
comparação.

**Grelha 2×2 que enche o ecrã.** `KpiGrid2x2` usa `Expanded` nas duas direcções,
com a célula 1-1 a valer 3/5 da altura (é a que leva gráfico). Abaixo de 320 px
de altura passa a coluna com scroll: num telemóvel em landscape, quatro células
apertadas não se leem, e mentir sobre isso é pior do que rolar.

**Vocabulário separado.** *Frota* são os veículos da empresa (custo, slide 4);
*Máquinas* são as que se alugam (receita, slide 3). O prompt pedia um método
`ocupacaoFrotaSemana()`; chama-se `ocupacaoMaquinasSemana()` precisamente por
causa desta regra.

**Adiar recomendações vive em memória** (`recomendacoesAdiadasProvider`).
Persistir implicava mais um campo no armazenamento local e a decisão de o
sincronizar. Consequência assumida: fechar a app esquece os adiamentos.

## Dados que não existem

- **Cauções** (slide 2): não há campo no modelo. O card diz "as cauções ainda não
  se registam na app" em vez de mostrar 0 €, que seria mentira.
- **Data em que uma máquina parou**: o modelo não a guarda. O KPI mede o **último
  aluguer** e chama-se "sem alugar há mais de 7 dias", que é o que sabe dizer.
  Uma máquina marcada como parada hoje mas alugada ontem não aparece — e está
  certo.
- **Convites por responder** em Tarefas: precisa de sessão Supabase e da lista de
  convites; ficou de fora desta sprint (as outras seis fontes entraram).

## Landscape, e a excepção

`bloquearLandscape()` corre no `main` depois do `Supabase.initialize`. Portrait
não é suportado: quatro KPIs lado a lado não caberiam sem espremer os números até
não se lerem.

**Excepção deliberada:** a `CollaboratorShell` continua a pedir portrait enquanto
está montada. Aquele ecrã é para o telemóvel na mão, no terreno, com seis botões
grandes — outro utilizador, outro dispositivo, outra forma. Se o Cesar quiser
tudo em landscape, é tirar o `PhoneOrientationLock` de lá.

## Barra lateral

88 dp em vez de 72, para caber o rótulo debaixo do ícone. Com só ícones, o nome
dependia do tooltip — que num tablet exige toque longo, ou seja, não existe para
quem está a aprender a app.

Ordem: Gestão · Máquinas · Clientes · Reservas · Finanças · Funcionários ·
Frota · Tarefas. Activo com fundo e bordo esquerdo laranja.

**A lista do prompt não incluía Funcionários — mantive-o.** É o único acesso à
área de colaboradores, e continua condicionado a haver colaboradores declarados
(igual à Frota). Removê-lo escondia uma área inteira da app sem que isso fosse
pedido.

O badge de Tarefas conta as pendências e só fica **vermelho quando há algo
urgente**; caso contrário é cinzento-escuro. Um badge vermelho permanente por
causa de uma morada em falta deixa de significar nada.

## Fora do âmbito, registado

- Página "Ver todas as métricas" — feita a sério em vez de placeholder, porque
  era a única forma de não perder as 17 métricas.
- Variante do slide 1 com "2-3 KPIs + recomendação do dia": a 4ª célula está
  isolada em `_ResultadoProvisorio`, portanto é uma troca de widget.
- Navegação temporal nos outros KPIs do slide 1 — v0.0.6.
- Personalização, sincronização, dark mode, animações elaboradas.
