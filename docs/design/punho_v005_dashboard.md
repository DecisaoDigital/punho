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

---

# Sprint 2: Dinheiro + Convites em Tarefas

Segunda ronda na mesma branch. Quatro itens: trocar o 4º KPI do slide 1,
estender as setas de mês, trazer os convites para as Tarefas, e confirmar por
escrito a decisão do ecrã do colaborador.

## O 4º KPI do slide 1 passou a "Recomendação do dia"

O "Resultado provisório" era recebido − pago, e os dois números já estavam à
vista nas duas células acima: a célula gastava um quarto do slide a repetir
aritmética que o gestor fazia de cabeça. E não dizia o que fazer hoje.

`lib/features/dashboard/kpis/recomendacao_do_dia.dart` — função pura, com o
`now` de fora, como o resto dos KPIs. Cinco regras por ordem de urgência,
devolve **a primeira que se aplica** ou `null`:

| # | Gravidade | Dispara quando | CTA |
|---|---|---|---|
| 1 | Vermelho | cliente com dívida > 30 dias **e** ≥ 100 € | Abrir ficha → |
| 2 | Vermelho | custos ≥ 80% da receita do mês | Rever custos → (slide 4) |
| 3 | Laranja | cliente com dívida entre 15 e 30 dias | Abrir ficha → |
| 4 | Laranja | recebido < 60% do mês homólogo (se o homólogo ≥ 500 €) | Ver homóloga → |
| 5 | Verde | conversão de leads a 30 dias ≥ 40% | Ver conversão → (slide 2) |
| — | — | nada disto | "Sem sugestão para hoje" em cinza |

Três decisões dentro das regras:

- **A dívida agrega-se por cliente**, não por reserva: cobra-se a uma pessoa,
  não a um contrato. Duas reservas de 60 € do mesmo cliente passam o limiar dos
  100 €, e a frase usa a mais antiga das duas.
- **O mês homólogo** vem primeiro dos recebimentos registados do ano passado e,
  se não houver nenhum, do valor declarado no histórico mensal. Sem nenhum dos
  dois, a regra não se aplica — comparar com nada não dá aviso, dá ruído.
- **O mínimo de 500 €** no mês homólogo existe porque uma queda percentual sobre
  um valor pequeno não quer dizer nada: 40% de 30 € não é notícia.

O card é o `RecomendacaoCard`, agora partilhado com a Recomendação da Semana do
slide 5 — mesma escala de cor (verde convite, laranja aviso, vermelho risco a
acontecer), porque duas escalas para a mesma ideia ensinariam ao gestor que a cor
não significa nada. A célula **nunca desaparece**: sem sugestão mostra a frase de
vazio, senão o slide mudava de desenho de um dia para o outro.

"Abrir ficha →" leva à área de Clientes: **não existe ecrã de ficha individual de
cliente** (é o P2-8 da auditoria v0.0.3, ainda em backlog). Quando existir, é uma
linha a mudar em `_seguir`.

Capturas: `slide_dinheiro_recomendacao_vermelho.png`,
`slide_dinheiro_recomendacao_verde.png`, `slide_dinheiro_recomendacao_null.png`.

## Setas de mês nos três KPIs, com estado partilhado

`ValueNotifier<DateTime>` no `_DinheiroSlideState`, lido por um
`ValueListenableBuilder`: **um mês para o slide**, não um por card. Recuar no
"Recebido" e deixar o "Pago" em Julho punha duas verdades no mesmo ecrã.

- **Recebido** e **Pago** têm o par `‹ ›` e mudam de título ("Recebido em
  Junho", "Pago em Junho").
- A seta `›` está desactivada no mês actual e a `‹` **pára no primeiro registo**
  — não vale deixar o gestor a passear por meses vazios.
- A **Recomendação do dia** fica sempre no mês actual, e há um teste que o
  garante: recomendar sobre um mês passado não faz sentido.

### "Por receber" ficou sem setas — e diz porquê

Era o item que dependia de haver histórico de dívida. **Não há**: o modelo guarda
o valor previsto da reserva e os recebimentos, mas nada registra como a dívida
estava no fim de cada mês. Ao navegar para trás, o card assume-o com um
`só o mês actual` ao lado do título.

Nota para quem voltar a isto: seria *reconstruível* (dívida no fim do mês M =
previsto das reservas terminadas até M − recebimentos até M) e não o fiz de
propósito. O `expectedValueCents` de uma reserva é editável hoje e aplicar-se-ia
retroactivamente, portanto o histórico mudava conforme se corrigissem valores no
presente. Preferi um card que admite o que não sabe a um que apresenta números
que o Cesar não consegue reconciliar — foi essa a queixa que abriu a v0.0.4.

Captura: `slide_dinheiro_mes_passado.png`.

## Um falso zero que apareceu nas capturas

A captura do caso vermelho mostrou "Pago este mês: 0,00 €" numa empresa que
**nunca registou uma despesa**. Zero despesas pagas num mês é verdade; zero
despesas de sempre é falta de dados, e aquele "0,00 €" dizia ao gestor que não
tem custos. Passou a "Por apurar — ainda não registaste nenhuma despesa".

## Convites por responder nas Tarefas

Sexta fonte da lista. Lê o `convitesProvider` que já existia (`punho_convites`
via `listarConvites()`) e conta só os que `disponivelEm(now)` — nem usados nem
expirados.

- **Urgente** se expira em ≤ 48 h ("Expira em 11 horas — depois disso é preciso
  emitir outro"), **A completar** caso contrário.
- A CTA leva o **código** consigo: `ConvitesScreen` ganhou `destacarCodigo` e
  destaca a linha. Abrir uma lista de dez convites sem dizer qual não resolve a
  tarefa.
- **Sem Supabase a fonte cala-se.** O `tarefasProvider` usa `.valueOrNull` — em
  modo de demonstração o provider dos convites fica em erro (não há
  `Supabase.instance`) e as Tarefas não mostram erro de rede por causa disso. A
  função pura recebe a lista de fora, por isso testa-se sem servidor nenhum.

Captura: `tarefas_com_convite_urgente.png`.

## Shell do colaborador: fica em portrait

Confirmado por escrito, como pedido: **não se mexeu**. A `CollaboratorShell`
continua com o seu `PhoneOrientationLock` em portrait — seis botões grandes,
telemóvel na mão, no terreno. O `bloquearLandscape()` do `main` usa
`setPreferredOrientations`, que é uma preferência e não uma imposição, portanto
os dois convivem: a app abre em landscape e aquele ecrã pede portrait enquanto
está montado.

## Fora do âmbito, registado

- Página "Ver todas as métricas" — feita a sério em vez de placeholder, porque
  era a única forma de não perder as 17 métricas.
- Variante do slide 1 com "2-3 KPIs + recomendação do dia": a 4ª célula está
  isolada em `_ResultadoProvisorio`, portanto é uma troca de widget.
- Navegação temporal nos outros KPIs do slide 1 — v0.0.6.
- Personalização, sincronização, dark mode, animações elaboradas.

---

# Sprints 3 e 4: o que o smoke apanhou

As sprints 3 e 4 foram planeadas em separado e acabaram fundidas: as frentes A a
D da 3 saíram primeiro, e o resto da 3 (placeholders de máquinas, diálogos,
Reservas) tocava exactamente nos mesmos ficheiros que a 4. Separá-las obrigava a
mexer duas vezes no mesmo sítio, por isso vão pela ordem em que se resolvem e não
pela ordem em que foram escritas.

O fio comum é que quase tudo aqui veio de o Cesar usar a app no telemóvel e
tropeçar. Não são melhorias inventadas: são coisas que não funcionavam.

## Declarar N máquinas cria N linhas por identificar

"Um gestor com 200 máquinas não vai lá numerar e fotografar todas ao mesmo
tempo." Declarar 20 no onboarding cria `Máquina 1…20`, categoria "Por
identificar", disponíveis, prontas a serem baptizadas aos poucos. `Machine`
ganhou o campo `placeholder`, com `false` por omissão para os registos antigos.

Qualquer gravação pelo diálogo desliga o flag — daí o botão dizer **"Guardar e
identificar"** quando se está a baptizar uma. Subir o total nas Definições cria
as que faltam; **descer não apaga nada**, porque eliminar é decisão explícita,
pelo caixote da lista, e não efeito secundário de mexer num contador.

O que isto deu à vista: as Tarefas contavam o delta `declaradas − registadas`
para dizer "máquinas por identificar". Com placeholders esse delta é **zero**
mesmo havendo vinte linhas chamadas "Máquina 7" — a fonte tinha deixado de
funcionar sem se notar. Passa a contar placeholders, e o delta fica exposto à
parte para reconciliar o contador.

## Sub-textos do onboarding

O passo 1 pergunta o nome e tinha por baixo "O Punho orienta a pessoa
responsável por decidir e agir na empresa." — o pitch do produto, a meio de um
formulário. Critério aplicado aos 12 passos: **o sub-texto só fica se disser algo
sobre aquele campo**. Ficaram 7 dos 12, e os que ficaram foram reescritos mais
curtos. O do passo 7 passou a explicar a consequência concreta ("sem estes
números o painel mostra Por apurar") em vez de vender potencial.

O vazio colapsa de facto: sem isso ficava um `SizedBox` fantasma a abrir um
buraco entre a pergunta e o campo.

Os sub-textos que ficaram, por passo:

| Passo | Sub-texto |
|---|---|
| 1 · nome, 2 · empresa | *(nenhum)* |
| 3 · perfil | O gestor decide e vê tudo. O colaborador só regista o seu próprio trabalho. |
| 4 · forma jurídica e NIF | A forma jurídica pode ser alterada mais tarde. O NIF é importante para a identificação — se não souber agora, ficará como tarefa aberta. |
| 5 · contactos | Morada, código-postal e localidade + telemóvel e email. Não é pedido país. |
| 6 · equipa e frota | Número de colaboradores e de veículos (podem ser 0). Os separadores Funcionários e Veículos ficam activos quando forem maiores que 0. |
| 7 · tempo agora | Podes saltar e preencher depois, em Definições. Sem estes números o painel mostra "Por apurar" em vez de recomendações. |
| 8 · total de máquinas | Uma estimativa chega. Criamos uma linha por máquina para lhes dares nome e foto aos poucos. |
| 9–12 · números | *(uma linha cada, do género "Um número redondo serve. Fica em branco se não souberes.")* |

**Um bug que o teste apanhou de graça:** "Empresário em Nome Individual" não cabe
na largura do cartão e **rebentava a linha em 52 px** — no onboarding *e* nas
Definições da empresa. Estava lá desde a v0.0.2. Resolvido com `isExpanded` nos
dois dropdowns.

## Os três diálogos de registo

Máquina, veículo e colaborador tinham todos o mesmo defeito no telemóvel: o
teclado abre, come metade do ecrã, e o botão *Guardar* fica debaixo dele. Como o
corpo também não rolava, os últimos campos simplesmente não existiam — a
periodicidade do seguro e as horas semanais não eram alcançáveis.

A correcção vive num sítio só, o `DialogoDeFormulario` em `core/layout`:
cabeçalho e rodapé fixos, corpo num `SingleChildScrollView` dentro de um
`Flexible`, e o *Guardar* fora do scroll.

**O que se aprendeu a fazer mal primeiro:** a primeira versão descontava
`viewInsets.bottom` ao `insetPadding` à mão. O `Dialog` já lhe soma `viewInsets`
por dentro — o teclado era contado duas vezes e o diálogo ficava com 220 dp de
altura num ecrã com 532 livres. O teste passava, porque só verificava que o
*Guardar* estava acima do teclado, e estava. Foi a **captura** que deu o erro à
vista. É um argumento a favor das capturas como documentação: um teste verifica o
que lhe pedimos, uma imagem mostra o que lá está.

O diálogo da máquina é o único com duas colunas em paisagem (identificação à
esquerda, notas e fotografias à direita, miniaturas de 112 dp em vez de 78 — a
78 não se reconhece a máquina). Os outros dois são de uma coluna.

De caminho:

- **Controladores descartados cedo.** Ficavam na função e eram descartados depois
  do `await showDialog`, que devolve no instante do `pop` — com a animação de
  fecho ainda a correr e a reconstruir campos com controladores mortos. Os três
  formulários passaram a `StatefulWidget`, que é quem deve ser dono deles. Nos de
  veículo e colaborador nem eram descartados: fugiam.
- **O diálogo do colaborador não tinha saída.** Sem *Cancelar* e com
  `barrierDismissible: false`: quem o abrisse por engano tinha de criar um
  colaborador para se ver livre dele. O `DialogoDeFormulario` traz o *Cancelar* de
  série, e só agora é que o `barrierDismissible: false` é honesto.
- **"Parada" ainda era escolhível** no dropdown de estado da máquina, um sprint
  depois de sair da app. Máquinas antigas gravadas nesse estado entram como
  disponíveis — senão o valor caía fora da lista de opções.
- **Acentos estragados.** A mensagem de erro das fotografias dizia "NÃ£o foi
  possÃ­vel", em duas cópias. O ficheiro foi gravado noutra codificação em algum
  momento.

Capturas: `dialogo_maquina_largo.png`, `dialogo_veiculo_portrait_teclado.png`,
`dialogo_colaborador_portrait_teclado.png`.

## Reservas: a semana toda num ecrã

O calendário forçava 860 dp de largura mínima e vivia dentro de **dois**
`SingleChildScrollView`. Para ver a sexta-feira rolava-se na horizontal; para ver
a tarde, na vertical. Uma semana são sete dias: ou cabem, ou o ecrã é pequeno e
são as células que encolhem — não a semana que se corta.

- As duas metades do dia entram por `Expanded`; o cabeçalho passa a uma linha
  ("Seg 27/7" em vez de duas); a célula perdeu o `minHeight` de 116 dp que
  obrigava ao scroll; o `+` é de 24 dp.
- Uma célula com várias reservas rola **por dentro**, em vez de transbordar para
  cima da célula de baixo.
- O `IntrinsicHeight` da linha saiu: era preciso para sobreviver à altura
  infinita do scroll vertical, e agora estorva.
- A máquina escolhia-se numa fila horizontal de `ChoiceChip` com 64 dp de altura.
  Com vinte máquinas era uma lista para rolar às cegas, e aqueles 64 dp faltavam
  ao calendário. Passa a um `DropdownButton` de 240 dp **dentro da própria
  barra**: três linhas passam a uma.
- Nomes: o ecrã era "Marcações / Reservas" — duas palavras para a mesma coisa,
  quando a barra lateral já diz "Reservas". O botão diz "Reservar" / "Reservar
  (N)".
- A frase de contexto tinha um `SizedBox` de 10 dp de cada lado, fixos: sem nada
  a dizer ficava um buraco de 20 dp. Agora ou há frase com margem, ou não há nada.

Capturas: `reservas_landscape.png`, `reservas_semana_sem_scroll.png`.

## Funcionários: editar, eliminar, e o que cada um traz para dentro

A lista era só de leitura, e o único número visível era o custo — o que fazia da
página uma folha de despesas.

- **Editar** pela linha ou pelo lápis, sobre o mesmo id. O `Collaborator` ganhou
  `copyWith` com **sentinela** nos campos opcionais em vez de `??`: com
  `phone ?? this.phone` era impossível limpar um telemóvel escrito errado. É o
  defeito P2-5 da auditoria da v0.0.3 outra vez, e fica testado que "não mexer" e
  "apagar" são coisas diferentes. A mesma ideia do `Campo<T>` do controller,
  escrita à mão no domínio para ele não passar a depender do controller.
- **Eliminar** com confirmação e 6 segundos para anular, como nas máquinas. Por
  dentro é soft-delete: as reservas de que a pessoa foi responsável continuam a
  apontar para um registo que existe. A lista filtra arquivados — senão eliminar
  não fazia a linha desaparecer, e ninguém acredita que tenha eliminado.
- **Vendas do mês**, novo KPI puro `vendasDoMesDoColaborador`, no subtítulo e à
  frente do custo. Conta confirmadas, alugadas e concluídas; uma proposta enviada
  **não** é uma venda, senão quem só envia propostas tinha os números de quem
  fecha negócio. Sem valor esperado preenchido diz "valor por apurar" e não 0 € —
  a mesma regra dos falsos zeros do painel.
- **Desarquivar passa pelo `saveCollaborator`** de propósito: se as vagas
  contratadas encolheram nestes 6 segundos, o "Anular" tem de bater no mesmo
  limite que criar.

Duas coisas que a captura deu à vista, outra vez:

- o estado aparecia como **`active`** — o nome do valor do enum a chegar ao ecrã;
- o custo/hora vem em **cêntimos**, como o mensal, e era mostrado tal e qual: um
  colaborador a 14,10 €/hora lia-se "custo/hora: 1410.26".

Capturas: `funcionarios_com_editar_e_vendas.png`,
`funcionarios_confirmar_eliminar.png`.

## Estado no fim destas sprints

- **393 testes** verdes, `flutter analyze` limpo. Eram 338 no início da
  continuação.
- **23 capturas** em `docs/design/screenshots/v005/`.
- Sem bump de versão, sem tag, sem APK: o release não foi autorizado nesta
  continuação. O `pubspec` de outra sessão trazia `0.0.4+4` e ficou por commitar
  — mudar a versão é acto de release. A dependência nova do QR das faturas
  (`google_mlkit_barcode_scanning`) foi commitada sozinha, porque sem ela o
  código não compila.

## Registado, não feito

- Os rótulos dos botões saem como blocos negros nas capturas de golden. É o
  renderizador de testes, não a app.
- `applicationVariants` no Gradle está depreciado no AGP 8; quando sair no AGP 9,
  o substituto é a Variant API nova.
- As células do calendário da semana ficam altas (~300 dp) num ecrã de 1280×800.
  Cabe tudo e o alvo de toque é generoso, mas há espaço vazio a mais — vale uma
  segunda vista quando houver reservas reais lá dentro para ver.
