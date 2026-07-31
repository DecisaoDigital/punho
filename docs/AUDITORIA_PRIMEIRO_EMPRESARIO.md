# Auditoria — o que vê um empresário que abre o Punho pela primeira vez

Feita em 31 de Julho de 2026, sobre a `v0.0.18`. Percurso seguido no código, do
splash ao painel: `main.dart` → `SplashPunho` → `AuthGate` → `RegistoScreen` →
`AcessoGate` → `OnboardingPage` (7 a 12 passos) → `BoasVindasScreen` →
`AppShell` → `DashboardPage`.

O critério não é "está bonito" nem "tem bugs". É: **o que ele vê, o que devia
ver, e o que não sabe que devia ver.**

---

## 1. O painel mostra números que não são dele

**O que ele vê.** Acaba o onboarding, lê "A Punho é o painel do teu negócio",
carrega em "Entrar na Punho" e encontra:

- "Dinheiros que entraram: **1 240 €** hoje ▲18%"
- "Encontro de contas: **+380 €** · Entradas 1 240 · Saídas 860"
- "Reservas activas: **14** · 4 novas hoje"
- "Devoluções: 1 já em atraso — **Sr. Costa**"
- "Recomendação do dia: **Cobrar Silva & Filhos** (vence hoje — 340 €)"
- "Conversão lead → cliente: 28%, ▼9pp abaixo do alvo"

Nada disto existe. São constantes escritas à mão em `sintese_slide.dart`,
`operacional_slide.dart` e `procura_slide.dart`. A empresa dele acabou de ser
criada e não tem um único registo.

**Porque é que isto é o problema mais grave de todos.** Há só dois desfechos, e
os dois são maus:

1. **Ele acredita.** É um empresário a olhar para um painel de gestão. Toma "o
   Sr. Costa está em atraso" por verdade e vai ligar a um cliente que não tem.
2. **Ele percebe.** E a partir desse segundo não volta a acreditar em nenhum
   número que a app lhe mostre — incluindo os verdadeiros que vierem depois.
   Confiança num painel de gestão perde-se uma vez.

O agravante: o cartão "RECOMENDAÇÃO CANÓNICA" é **exactamente** a promessa do
produto — a forma "evidência → leitura → próxima acção" da
`BIBLIOTECA_DE_ALAVANCAS.md`. A primeira demonstração dessa promessa é feita
sobre evidência inventada.

**O que devia ver.** O produto já tem a peça honesta e não a usa: `kpis.dart` e
`guidance_engine.dart` devolvem `null` quando não há dados, e a UI sabe escrever
**"Por apurar"** com a razão. É a regra que o próprio `ESTADO_ATUAL_DA_APP.md`
celebra: *"um valor que é zero por falta de dados aparece como 'Por apurar' com
a razão, não como 0 €"*. Os três slides novos passam ao lado dela.

Um painel vazio e honesto — "Por apurar: ainda não registaste nenhuma reserva"
com o botão que leva ao sítio de registar — vale mais do que um painel cheio e
falso. E é menos trabalho do que parece: o mecanismo já existe.

**Enquanto a integração real não vier**, isto não devia estar visível a um
utilizador. Ou os slides passam a "Por apurar", ou o painel só aparece depois do
primeiro registo real.

---

## 2. Ele não consegue entrar sozinho, e fica sem saber o que esperar

**O que ele vê.** Cria conta → ecrã "Pedido em análise" → *"O acesso é libertado
manualmente pela Decisão Digital depois de confirmarmos os dados"* → um botão:
**Terminar sessão**.

E acabou. Não há prazo, não há canal ("avisamos assim que estiver activo" — por
onde? email? SMS?), não há forma de ver o estado, não há contacto, não há nada
para fazer entretanto. O `RegistoScreen` diz-se explicitamente: *"Nunca cria
empresa nem adesão"*. Do lado do Control a UI de aprovação **ainda não existe**
(`LIMITACOES_CONHECIDAS.md`) — hoje aprova-se à mão em SQL.

**O que devia ver.** No mínimo: prazo esperado ("normalmente no mesmo dia
útil"), o canal pelo qual vai ser avisado, e um contacto. Idealmente, o ecrã
devia reconsultar o estado sozinho e destrancar sem ele ter de fechar e reabrir.

**Detalhe que trai o público-alvo:** o `RegistoScreen` abre com
`_perfil = 'colaborador'` por defeito. O empresário que descobre a app sozinho é
**gestor**. O default está no perfil errado para quem a app diz servir.

---

## 3. O onboarding pede muito antes de dar alguma coisa

**O que ele vê.** Antes do primeiro ecrã de valor: nome, nome da empresa, cargo,
forma jurídica, NIF, morada, código-postal, localidade, telefone, email, número
de colaboradores, número de veículos — e, se aceitar o passo opcional, ainda o
bloco de custos fixos. À volta de 15 campos.

**O que está errado na ordem.** Quase tudo isto é administrativo — serve para
facturar e para o Control, não para produzir a primeira leitura. Nenhum destes
campos gera um número no painel.

E **em nenhum momento se pergunta o que faria diferença no primeiro dia**:
quantas máquinas tens e quanto cobras por dia. Com esses dois valores a app
podia fazer aritmética verdadeira imediatamente — receita potencial mensal,
ponto de equilíbrio, e "a tua utilização é por apurar, regista a primeira
reserva". Uma vitória real em 60 segundos, com dados dele, em vez de uma
promessa seguida de ficção.

**Erro pequeno, sítio péssimo:** a `BoasVindasScreen` promete o painel *"em
**cinco** vistas"*. O painel tem **três** slides. A primeira frase que ele lê
sobre o produto já não bate certo com o que vai encontrar a seguir.

---

## 4. O que ele não sabe que devia ver

Nada disto lhe vai ocorrer pedir. Todos mudam a probabilidade de ele ainda estar
a usar a app dentro de um mês.

### 4.1 Que os dados dele só vivem naquele telemóvel

Os repositórios operacionais ainda não escrevem em tabelas Supabase
individuais (`ESTADO_ATUAL_DA_APP.md`). Não há outbox persistente, não há
sincronização granular, não há multi-dispositivo. **Se ele perder o telemóvel,
perde o registo do negócio** — e não faz a mínima ideia disso enquanto escreve
lá os clientes todos.

Isto tem de ser dito **antes** de ele começar a escrever, não numa página de
limitações que ele nunca vai ler. Uma linha no onboarding chega.

### 4.2 Quanto custa e o que acontece a seguir

O primeiro percurso não menciona subscrição, preço, período experimental nem
onde ficam os dados. Um empresário a decidir se adopta uma ferramenta de gestão
precisa disto à cabeça — e não vai perguntar. Simplesmente não se compromete.

### 4.3 O caminho dos clientes que ele já tem

Os clientes dele estão no WhatsApp, num caderno e na cabeça. Não há importação
nenhuma — nem colar uma lista, nem contactos do telemóvel, nem CSV. É a maior
barreira de adopção para este perfil e ele nunca vai pedir um importador: vai só
desistir ao quarto cliente escrito à mão.

### 4.4 O "porquê" por trás de cada número

O `O_QUE_E_O_PUNHO.md` promete, no passo 3 do ciclo: *"mostra não apenas um
número, mas também a causa provável e os registos que o produziram"*. Os slides
novos mostram número + subtexto, e mais nada — não há como abrir um KPI e ver os
registos que lhe deram origem. A `todas_metricas_page.dart`, que fazia parte
desse caminho, foi apagada no refactor da v0.0.15 e não foi substituída.

É precisamente isto que distingue o Punho de uma folha de Excel. Sem drill-down,
é um painel bonito de números que ele não pode verificar — e um empresário que
não pode verificar um número deixa de o usar para decidir.

### 4.5 Ninguém lhe pergunta o que ele quer resolver

A app escolhe a alavanca por ele. Uma única pergunta no onboarding — *"o que te
tira o sono: falta de clientes, dinheiro a entrar tarde, máquinas paradas, ou a
equipa?"* — permitia abrir o painel na alavanca que lhe interessa e dava à app a
primeira informação verdadeira sobre o negócio dele. Custa um ecrã.

### 4.6 As Tarefas são a resposta certa e estão no sítio errado

O `tarefas_service.dart` já gera, a partir do estado real: "Identificar N
máquinas", "Registar os veículos da frota", "Falta custo ou horário — sem isso
não há custo por hora", cobranças a vencer, dados fiscais em falta.

**Isto é exactamente o mecanismo de "o que devias estar a ver e não sabes"** — a
Decisão 11 do guião, já construída e a funcionar sobre dados verdadeiros.

E um utilizador novo aterra num painel de ficção, com as Tarefas escondidas
atrás de um destino na barra lateral. Devia ser ao contrário: **enquanto a
empresa está vazia, a página de entrada é a lista de tarefas** — que converte o
vazio num caminho — e o painel abre quando houver o que mostrar.

---

## Ordem sugerida

Por relação entre estrago e esforço, não por dificuldade:

| # | O quê | Porquê primeiro |
|---|---|---|
| 1 | Tirar os números falsos dos 3 slides ("Por apurar" com razão) | É a única coisa aqui que destrói confiança de forma irreversível |
| 2 | Tarefas como aterragem enquanto a empresa está vazia | O mecanismo já existe e funciona; é só trocar a ordem |
| 3 | Dizer que os dados só vivem no telemóvel | Uma linha. Evita a perda que não tem retorno |
| 4 | Corrigir "cinco vistas" → três, e o default `colaborador` → `gestor` | Minutos |
| 5 | "Pedido em análise" com prazo, canal e contacto | Hoje é um beco sem saída |
| 6 | Perguntar máquinas + preço/dia cedo, e devolver aritmética real | Primeira vitória com dados dele |
| 7 | Drill-down de KPI para os registos de origem | É o diferenciador do produto face a um Excel |
| 8 | Importar clientes | Maior barreira de adopção a médio prazo |

Os pontos 1 e 2 mudam por completo a primeira impressão e nenhum deles precisa
de código novo de raiz — precisam de ligar peças que já existem no repositório.
