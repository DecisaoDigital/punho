# Ligação — o que perguntamos ↔ o que os ecrãs mostram

Levantamento feito em 31 de Julho de 2026 sobre a `v0.0.18`, antes de avançar
para novos slides. A pergunta a que responde: **os 12 números que os 3 slides
mostram hoje em ficção, quais é que já podem ser verdadeiros com o que a app
recolhe?**

Resposta curta: **9 dos 12 já dão, hoje, com KPIs que já existem.** 2 precisam
de uma função nova sobre dados que já lá estão. 1 é impossível — falta um campo
no modelo.

Não é preciso recolher quase nada de novo. É preciso **ligar**.

---

## De onde vieram os números falsos

Do mockup. O `punho_dashboard_3primeiros_slides.html` que serviu de desenho aos
3 slides tem lá dentro `1 240`, `920`, `4,10`, `Silva & Filhos` e `Sr. Costa` —
exactamente os valores que estão hoje em produção, transcritos à letra para
constantes Dart.

Não foi descuido de ninguém: foi um mockup implementado como se fosse
especificação. **Um desenho define a forma, não os valores.** Vale a pena ficar
escrito, porque os slides 4 a 9 vão nascer todos do mesmo sítio — e se o padrão
se repetir, chegamos a nove ecrãs de ficção em vez de três.

Regra prática para os próximos: um slide novo nasce ligado a um KPI que devolve
`null`, mostra "Por apurar" e só depois ganha números. Nunca ao contrário.

---

## A arquitectura está fechada — 9 slides

O brainstorm (`BRAINSTORM_DASHBOARD_9_SCREENS_2026-07-29.md`) reconcilia a
formulação "2 operacionais + 6 alavancas + 1 direcção" com o que está no guião:

| Bloco | Slides |
|---|---|
| 2 operacionais | 1 · Primeiro impulso · 2 · Operacional |
| 6 alavancas | 3 Procura · 4 Tesouraria · 5 Margem · 6 Frota · 7 Equipa · **9 "Se…" (Previsibilidade)** |
| 1 direcção | 8 · Objectivos |

A 6ª alavanca é o slide 9 (Previsibilidade Simulada) — decidido a 29 de Julho.
Não fica por nomear nenhum slide.

**Nota de arrumação:** a secção "Pontos abertos que o Cesar precisa de fechar"
no fim desse ficheiro (6ª alavanca? Previsibilidade dentro ou fora?) já foi
respondida pelo bloco RECONCILIADO no topo do mesmo ficheiro. Quem o ler de
baixo para cima vai reabrir uma discussão fechada. Vale a pena apagá-la.

E o guião já nomeia as funções que faltam:
`entregasHoje`, `devolucoesHoje`, `devolucoesEmAtraso`,
`cobrancasNaProximaSemana`, `alertasOperacionais`,
`utilizacaoVsRentabilidadeMaquinasMes`, `progressoObjetivo`,
`ritmoNecessarioParaAlvo`, `alavancaMaisRelevanteParaObjetivo`.

Das nove, **as cinco primeiras são filtros sobre `Booking`** — o levantamento
abaixo mostra que já dão hoje. `utilizacaoVsRentabilidade` precisa do preço/dia.
As três últimas pertencem ao slide 8 (Objectivos), que ainda não existe.

---

## O que já se recolhe

| Modelo | Campos que alimentam o painel |
|---|---|
| `Booking` | `startsAt`, `endsAt`, `status`, `machineIds`, `expectedValueCents`, `customerId` |
| `Machine` | `status`, `dailyRateCents`, `archived`, `placeholder` |
| `Lead` | `status`, `source`, **`createdAt`** |
| `Customer` | `name`, `phone`, `taxId`, … — **sem data de criação** |
| Finanças | recebimentos, pagamentos, despesas (via `OperationsState`) |
| Equipa/frota | custos de colaboradores e veículos, horários |

E o `kpis.dart` já tem 756 linhas de funções puras prontas: `tesourariaDoMes`,
`cobrancasPorReceber`, `funilProcura`, `leadsPorContactar`, `ticketMedioReserva`,
`ocupacaoMaquinasSemana`, `topMaquinasMaisAlugadas`, `maquinasSemAluguerHaMaisDe`,
`compromissosProximos`, `custosMesAgregados`, `custoRealComPessoalMes`,
`resultadoMesConservador`. Mais o `guidance_engine.dart` para as recomendações.

**Toda esta maquinaria está desligada dos 3 slides novos.** Os slides são
constantes escritas à mão.

---

## Célula a célula

### Slide 1 · Primeiro impulso

| Célula (hoje, falsa) | Fonte real | Estado |
|---|---|---|
| "Dinheiros que entraram · 1 240 € **hoje**" | `tesourariaDoMes().recebimentos` | **Já dá** — mas ver nota (a) |
| "Utilização vs Rentabilidade · 72% · 4,10 €/h" | `Booking.machineIds` × `startsAt`/`endsAt` × `Machine.dailyRateCents` | **Função nova**, dados existem — ver (b) |
| "Encontro de contas · +380 €" | `tesourariaDoMes()` (recebimentos − pagamentos) ou `resultadoMesConservador()` | **Já dá** |
| "Recomendação do dia · Cobrar Silva & Filhos" | `guidance_engine` + `cobrancasPorReceber()` | **Já dá** |

**(a)** O slide diz "hoje"; a Decisão 6 do guião diz **recebimentos do mês**.
São coisas diferentes e é preciso decidir qual. Recomendo o mês: um empresário
de aluguer não recebe todos os dias, e "0 € hoje" às 10h da manhã é um sinal
falso de alarme.

**(b)** É o único KPI verdadeiramente novo do slide 1, e a Decisão 6 já lhe deu
nome e assinatura: `utilizacaoVsRentabilidadeMaquinasMes({now, bookings,
machines, recebimentos})`. Ocupação = % de dias-máquina reservados no mês;
rentabilidade = € por máquina no mesmo período. O `ocupacaoMaquinasSemana` já
existente é o mesmo cálculo noutra janela — serve de base.

### Slide 2 · Operacional

| Célula (hoje, falsa) | Fonte real | Estado |
|---|---|---|
| "Reservas activas · 14 em curso" | `bookings` com `status` em `{confirmed, rented}` e `endsAt >= hoje` | **Já dá** |
| "Entregas & levantamentos hoje · 6" | `bookings` com `startsAt` = hoje | **Já dá** |
| "Devoluções hoje / 48h · 3 · 5" | `bookings` com `endsAt` em [hoje, hoje+48h] | **Já dá** |
| "Cobranças a vencer (7d) · 920 € · 4 clientes" | `cobrancasPorReceber()` + `compromissosProximos()` | **Já dá** |
| Rodapé "Alertas operacionais" | síntese das 4 células acima | **Já dá** |

Este é o slide mais barato de tornar verdadeiro: **quatro filtros sobre
`bookings`**, nenhum cálculo novo, nenhum campo novo. Devia ser o primeiro.

### Slide 3 · Procura e vendas

| Célula (hoje, falsa) | Fonte real | Estado |
|---|---|---|
| "Clientes novos (30d) · 17" | — | **Não dá.** `Customer` não tem data de criação |
| "Leads em pipeline · 9 · 3 sem contacto >5d" | `funilProcura()` + `leadsPorContactar()` | **Já dá** (`Lead.createdAt` existe) |
| "Ticket médio · 42 €" | `ticketMedioReserva()` | **Já dá** |
| "Conversão lead → cliente · 28%" | `funilProcura()` (`LeadStatus.converted` / total) | **Já dá** |
| "Recomendação canónica" + CTA | `guidance_engine`; CTA tem `TODO` por ligar | **Motor dá**, navegação por ligar |

**O único buraco real do levantamento:** `Customer` não guarda quando foi criado.
Um campo `createdAt` resolve — mas os clientes já registados ficam sem data. Duas
saídas: (i) inferir a partir da primeira reserva do cliente, que é uma boa
aproximação e não precisa de migração; (ii) acrescentar o campo e assumir que a
métrica só é fiável a partir de agora, dizendo-o.

> **Decidido a 31/07/2026: fica pela primeira reserva, "por agora"** (Cesar).
> Implementado em `clientesNovos()`. É uma decisão **provisória**, não a forma
> definitiva — quem lá voltar não deve tratá-la como assente.
>
> O que a torna provisória: um cliente registado que ainda não alugou não conta
> como angariado. Hoje é aceitável e até defensável (ainda não comprou). Deixa
> de o ser no dia em que as leads passarem a entrar de fora
> (`ENTRADA_DE_LEADS.md`): aí passa a haver muita gente registada sem reserva, e
> "clientes novos" começa a contar menos do que a realidade.
>
> **O gatilho para rever é a entrada de leads externas**, não uma data.

---

## O outro lado: perguntas que fazemos e não servem para nada

O onboarding pede ~15 campos antes de mostrar o primeiro ecrã. Cruzando com o
que os slides precisam:

| Pergunta do onboarding | Alimenta que célula? |
|---|---|
| Nome do responsável | Saudação do painel |
| Nome da empresa | Saudação, e sync para o Control |
| Forma jurídica | Raiz semântica dos KPIs (Decisão 1) — real |
| NIF, morada, código-postal, localidade, telefone, email | **Nenhuma.** Serve a facturação e o Control |
| Nº de colaboradores | Custo com pessoal (alavanca Equipa, ainda sem slide) |
| Nº de veículos | `rubricasFrota` (alavanca Margem, ainda sem slide) |
| Nº de máquinas | Cria placeholders — base da ocupação |
| Custos fixos (opcional) | Encontro de contas, margem |

E **a pergunta que falta**, que sozinha desbloqueia mais do que todas as
administrativas juntas: **quanto cobras por dia por máquina.**

O campo já existe (`Machine.dailyRateCents`), é opcional, e o onboarding nunca o
pergunta — as máquinas nascem como placeholders sem preço. Sem ele:

- não há "rentabilidade por máquina" (célula 2 do slide 1)
- não há receita potencial nem ponto de equilíbrio
- não há como avaliar se a ocupação é boa ou má

Uma pergunta — "quanto cobras por dia, em média?" — com um valor único aplicado
a todas as máquinas, e afinável por máquina depois. É a diferença entre um
painel que mede e um painel que conta reservas.

---

## Rentabilidade por máquina — qual é o método de contas

O `4,10 €/h` do slide 1 é **receita** por hora. Rentabilidade é receita menos
custo, e para haver custo por máquina é preciso decidir **como se reparte**.
Sem esse método escrito, o número é uma opinião.

### O que já dá para atribuir a uma máquina

| Peça | Existe? |
|---|---|
| Receita — `Booking.expectedValueCents` + `machineIds` | **Sim**, falta regra de repartição quando a reserva tem várias máquinas |
| Custo directo — `Expense.machineId` (manutenção, reparações) | **Sim.** O campo já existe no modelo |
| Data de aquisição — `Machine.acquiredOn` | **Sim** |
| **Valor de aquisição** | **Não.** `Machine` não tem preço de compra |
| **Vida útil** | **Não.** Nem campo nem default por categoria |
| Custos indirectos (renda, luz, salários, publicidade) | Existem na empresa, **sem chave de repartição** por máquina |

### Três níveis, e o que cada um responde

**Nível 1 · Margem directa (contribuição)**
`receita atribuída − despesas etiquetadas com essa máquina`
Responde a: *esta máquina dá ou tira dinheiro no dia-a-dia?*
Precisa só da regra de repartição da receita. **Computável hoje.**

**Nível 2 · + recuperação do investimento**
`acumulado da margem directa desde a compra, contra o valor de compra`
Responde a: *esta máquina já se pagou? quando se paga?*
Precisa do valor de compra em `Machine`. **Não** precisa de amortização — ver a
secção seguinte: no caso real as máquinas foram pagas a pronto, e aí a pergunta
é de payback, não de repartição contabilística.

**Nível 3 · + quota-parte dos custos de estrutura**
`− parte da renda, luz, salários, publicidade`
Responde a: *quanto custa a estrutura por trás de cada máquina?*
Precisa de uma chave de repartição, e a escolha muda a conclusão:

- **por máquina (÷ N)** — simples, honesto numa frota homogénea
- **por dias ocupados** — cobra a estrutura a quem trabalhou; mas assim **uma
  máquina parada parece barata**, que é ao contrário do que interessa ver
- **por receita gerada** — proporcional, mas atenua o peso da máquina fraca,
  que é precisamente a que devia doer

### A recomendação

**O método depende da pergunta, e a app tem de dizer a qual está a responder.**

Para "vendo esta máquina ou fico com ela?", a resposta certa em contabilidade de
gestão é a **margem de contribuição** — nível 1 ou 2, nunca custo totalmente
repartido. Repartir a estrutura por uma máquina que se vai vender não faz a
estrutura desaparecer; a renda continua a ser paga.

Proposta concreta:

1. **Slide 1 · "Utilização vs Rentabilidade" usa o nível 2**, por máquina e por
   mês, apresentado por dia de ocupação. É o número que responde a "esta
   máquina paga-se". Sem valor de aquisição preenchido → **"Por apurar: falta o
   valor de compra"**, com atalho para o preencher.
2. **A repartição da estrutura (nível 3) vive no slide 5 · Margem**, ao nível da
   empresa e não da máquina — ali a pergunta é "quanto pesa a estrutura", e a
   resposta não precisa de ser imputada a activos individuais.
3. **Regra de repartição da receita** numa reserva com várias máquinas:
   proporcional ao `dailyRateCents` de cada uma, com divisão em partes iguais
   quando os preços não estiverem preenchidos. Usa o campo que já vamos ter de
   pedir, e é defensável perante o gestor.

### Máquinas pagas a pronto mudam o enquadramento

No caso real do piloto as máquinas são caras mas **já foram pagas a pronto**.
Não há prestações, não há juros, não há renda. O dinheiro já saiu.

Isso torna a amortização mensal a métrica errada. A amortização serve para
distribuir um custo por exercícios contabilísticos; quem pagou a pronto não tem
esse problema — tem outro, muito mais concreto:

> **Quanto é que esta máquina já me devolveu do que me custou, e quando é que
> passa a zero?**

É **recuperação do investimento (payback)**, não amortização. E é uma leitura
que um empresário entende sem explicação nenhuma:

> *Máquina 3 · custou 8 000 € · já devolveu 5 200 € em 14 meses · ao ritmo
> actual recupera em ~7 meses.*

Depois do payback, a mesma máquina passa a ler-se ao contrário — deixa de ser
"quanto falta recuperar" e passa a "quanto está a gerar limpo". A célula do
slide 1 pode mudar de estado sozinha nesse momento, que é um bom momento para a
app assinalar.

### Os quatro custos que sobram, e onde é que cada um pode ser imputado

| Custo | Atribuível à máquina? | Estado |
|---|---|---|
| **Preço de compra** | Sim, directo | Falta o campo em `Machine` |
| **Reparações** | Sim, directo | **Já dá** — `Expense.machineId` + `machineMaintenance` |
| **Deslocações** (entrega e recolha) | Só via reserva | **Não dá hoje** — ver abaixo |
| **CAC e publicidade** | Não deve ser | Fica na alavanca Procura |

**Deslocações** são o único buraco novo. Uma viagem serve uma *reserva*, não uma
máquina — e a reserva pode levar várias. Hoje o combustível entra como
`ExpenseCategory.fuel` ligado a um `vehicleId`, sem qualquer ligação à reserva
que o motivou. Duas saídas:

1. **Custo médio por deslocação** — o gestor diz uma vez quanto lhe custa em
   média uma entrega + recolha, e a app multiplica pelo número de reservas da
   máquina. Uma pergunta, aproximação honesta, zero fricção diária.
2. **`bookingId` nas despesas** — exacto, mas obriga a etiquetar cada
   abastecimento à reserva que o gerou. Para quem gere por memória e WhatsApp,
   é fricção a mais para o retorno.

Recomendo a 1 agora e a 2 como opção para quem quiser precisão.

**CAC e publicidade não devem ser imputados por máquina.** O custo de adquirir
um cliente pertence ao *cliente*, não ao activo que ele por acaso alugou.
Empurrá-lo para a máquina é onde o número deixa de ser defensável: a mesma
máquina fica boa ou má consoante a campanha desse mês. O sítio próprio é a
alavanca Procura — `publicidade do período ÷ clientes novos do período` — e essa
conta precisa da data de criação do cliente, que é o buraco já identificado
acima. **São o mesmo problema.**

### O que isto acrescenta às perguntas a fazer

Ao **preço/dia** já identificado, junta-se:

**No diálogo da máquina** — o mesmo que o gestor já abre para lhe dar nome e
foto, com mais duas linhas:

- **valor de compra**
- **comprada ou alugada** — muda a conta por inteiro: a alugada não tem payback,
  tem renda mensal, e nunca chega a "recuperada"

**Nas definições da empresa**, uma vez:

- **custo médio de uma deslocação** (entrega + recolha)

Nenhuma destas é onboarding novo. São ecrãs que já existem.

---

## Recolhas, não devoluções — e o bug que isso destapa

Correcção do Cesar a 31/07/2026: **não são devoluções, são recolhas.** As
máquinas são alugadas e têm de ser **recuperadas** para voltarem a estar
disponíveis para outro cliente.

Não é vocabulário. É a diferença entre um acontecimento passivo do cliente e
**trabalho que a empresa tem de fazer** — com deslocação, com custo, com alguém
atribuído, e com atraso possível.

### O bug

`operations_controller.dart:845` decide o estado da máquina assim:

```dart
final hasRentedNow = related.any((booking) =>
    booking.status == BookingStatus.rented &&
    !now.isBefore(booking.startsAt) &&
    now.isBefore(booking.endsAt));
```

**No instante em que `endsAt` passa, a máquina passa sozinha a `available`** —
sem ninguém a ter ido buscar. A máquina está fisicamente no estaleiro do cliente
e a app diz que está livre.

Consequências reais:

1. **Aluga-se uma máquina que não se tem.** O novo aluguer começa depois do
   `endsAt` do anterior, portanto não há conflito de reservas — no papel. Na
   rua, a máquina ainda está com o cliente anterior.
2. **A ocupação fica subestimada.** O tempo entre o fim do aluguer e a recolha
   efectiva não conta como ocupado, quando na prática a máquina não estava
   disponível para mais ninguém. Isto contamina o KPI de utilização do slide 1.
3. **"Recolha em atraso" não existe** — e é o alerta operacional que mais
   importa no dia-a-dia de quem aluga.

### O que falta no modelo

`Booking` tem `startsAt` e `endsAt` — datas previstas. Não tem o registo dos
dois acontecimentos que dizem o que aconteceu de facto:

- **entregue em** — quando a máquina saiu
- **recolhida em** — quando voltou

Com esses dois campos:

- a máquina só passa a `available` quando houver recolha registada
- "recolhas a fazer" e "recolhas em atraso" tornam-se computáveis e verdadeiras
- a ocupação passa a medir o tempo real de indisponibilidade
- a deslocação ganha o seu acontecimento: são duas viagens por aluguer, e é
  exactamente sobre elas que assenta o custo médio de deslocação da secção
  anterior
- o slide 2 deixa de ser uma contagem passiva e passa a ser **uma lista de
  trabalho por fechar**, que é o que o gestor abre a app para ver

### O botão "Recolhida" do colaborador

Decisão do Cesar: o colaborador tem de ter um botão **"Recolhida"** para carregar
quando está a recolher a máquina em casa do cliente.

É o sítio certo. A `CollaboratorShell` já é isso — telemóvel na mão, no terreno,
seis botões grandes, portrait, *"O que quer registar?"*. Acrescentar **Entreguei**
e **Recolhida** é coerente com o que lá está.

**Mas o botão é a parte fácil, e sozinho não funciona.**

Hoje a sincronização (`SincronizacaoFichaEmpresa`) empurra o **estado operacional
completo** com uma revisão, e detecta conflitos em vez de os fundir. Ou seja:

- o colaborador carrega em "Recolhida" → grava no estado **local dele**
- para chegar ao gestor, tem de empurrar o estado **todo**
- o gestor, que entretanto mexeu em qualquer coisa, empurra o dele
- **um dos dois perde o trabalho**

Um colaborador no terreno e um gestor no escritório a editarem em paralelo é
precisamente o cenário que este modelo não aguenta. O botão existiria e a
máquina continuaria a aparecer alugada — ou pior, o registo desaparecia no
próximo sync.

### O caminho mais curto que funciona: eventos em vez de estado

Não é preciso resolver a sincronização granular toda para entregar isto. Basta
uma coisa muito menor:

**Uma tabela de eventos, só de acrescentar.**

```
punho_eventos_reserva
  reserva_id · tipo ('entrega' | 'recolha') · em · por_colaborador · empresa_id
```

Porque é que isto resolve, e o estado completo não:

- **Eventos não colidem.** Duas linhas escritas por dois telemóveis diferentes
  sobrevivem as duas. Não há revisão, não há conflito, não há vencedor.
- **É pequeno.** Uma tabela, uma política RLS, um `insert`. Não é o outbox
  genérico nem a sincronização granular de tudo — é o caminho estreito que
  entrega esta funcionalidade.
- **Fila offline é trivial.** Em casa do cliente pode não haver rede. Guardar
  eventos por enviar e reenviar depois é fácil quando o evento é imutável e só
  se acrescenta — ao contrário de um estado completo, que tem de ser
  reconciliado.
- **A disponibilidade da máquina passa a derivar dos eventos**, não do relógio.
  Há evento de recolha → livre. Não há → continua indisponível, por muito que o
  `endsAt` já tenha passado.

**Dois sítios a corrigir quando isto entrar**, ambos com o mesmo erro de usar o
`endsAt` como se fosse a recolha:

- `operations_controller.dart:845` — o estado da máquina
- `availableMachines()` no mesmo ficheiro — a contagem de disponíveis

### Consequência para a célula do slide 2

Já não é *"Devoluções hoje / 48h · 3 · 5"*. É:

> **Recolhas a fazer** · 3 hoje · 5 em 48h · **1 em atraso desde ontem**

O atraso a vermelho, com o nome do cliente e um toque para marcar recolhida.
E enquanto não estiver marcada, a máquina não aparece disponível a ninguém.

Decisão do Cesar a 31/07/2026, e é o mecanismo que resolve a tensão entre
"perguntar tudo à cabeça" e "não ter dados para calcular nada".

**A app começa com o número mais simples que consegue ser honesto, e oferece um
botão que o aprofunda.** Cada toque em *Refinar este valor* faz só as perguntas
necessárias para subir um degrau — e, ao responder, o gestor vê o número mudar e
percebe porquê.

É aqui que a app cumpre a promessa de *"ensina o empresário a perceber as
alavancas"* (`O_QUE_E_O_PUNHO.md`). Não com um tutorial: com o número dele a
mexer-se à frente dele, e a razão escrita ao lado.

### A escada, no caso do lucro por máquina

| Degrau | O que mostra | O que pergunta para subir |
|---|---|---|
| 0 | "Por apurar" | Valor de compra · preço/dia |
| 1 | **Recuperação**: custou 8 000 €, já devolveu 5 200 € | — (usa reservas) |
| 2 | **− reparações** | Nada, se as despesas já estiverem etiquetadas à máquina |
| 3 | **− deslocações** | Custo médio de uma entrega + recolha |
| 4 | **− estrutura** | Que custos fixos incluir · chave de repartição |

O degrau 2 é o exemplo do que isto tem de bom: **muitas vezes não há pergunta
nenhuma a fazer** — o dado já lá está, e o refinamento é só a app a mostrar que
o sabe usar.

### Regras que fazem a diferença entre pedagógico e confuso

**1. O número diz sempre em que degrau está.**
`5 200 € recuperados · antes de deslocações e estrutura`. Um valor de lucro sem
o seu nível é um valor sem significado, e dois gestores a olhar para o mesmo
ecrã tirariam conclusões diferentes.

**2. Cada refinamento mostra o antes e o depois.**
> *Era 5 200 €. Com as deslocações passou a 4 400 €.*
> *Cada aluguer desta máquina custa-te 40 € de deslocação — em 20 alugueres,
> 800 €.*

É esta linha que ensina. Sem ela, o gestor responde a perguntas e não percebe
para que serviram.

**3. Uma resposta serve para sempre e para todas.**
O custo médio de deslocação responde-se uma vez e aplica-se a toda a frota e a
todos os períodos. Refinar não pode transformar-se num interrogatório mensal.

**4. Refinamentos por fazer são Tarefas.**
Cada degrau por subir vira uma entrada no `tarefas_service` — *"Sabe quanto te
custa uma entrega? Refina o lucro das máquinas"* — com a severidade
`aCompletar`. Liga-se à Decisão 11 e dá conteúdo real à página de Tarefas de
quem ainda não tem operação nenhuma registada.

**5. O gestor pode ver e desfazer o que respondeu.**
Um ecrã com as respostas dadas e o efeito de cada uma. Um número que ele não
consegue auditar é um número que ele deixa de usar para decidir.

**6. Comparações só entre iguais.** ⚠️
É a armadilha deste mecanismo. Se a Máquina 1 está no degrau 4 e a Máquina 3 no
degrau 1, o ranking "máquina mais rentável" é mentira — a Máquina 3 parece
melhor por ter menos custos descontados.

Regra: **qualquer vista comparativa usa o degrau mais baixo entre as máquinas
comparadas**, e diz que o está a fazer. Quando o gestor sobe o degrau de uma
máquina, a app sugere subir o das outras — que é, por acaso, um bom empurrão
pedagógico.

### Aplica-se para lá das máquinas

O mesmo padrão serve a alavanca Procura (CAC), a Margem (peso da estrutura) e o
slide 8 (Objectivos):

- **CAC no degrau 1**: `publicidade ÷ clientes novos`.
- **CAC no degrau 2**: separa por canal — pergunta quanto foi para cada um.
- **CAC no degrau 3**: contra o valor do cliente ao longo da vida, e aí a
  pergunta é sobre recorrência.

O widget é um só, partilhado, e nasce com o slide 2 mesmo que só seja usado a
sério no slide 1.

### Decisões fechadas nesta ronda

- **CAC e publicidade ficam na alavanca Procura**, não são imputados por
  máquina. Confirmado pelo Cesar a 31/07/2026.
- **Payback substitui amortização** no slide 1, porque as máquinas do piloto
  foram pagas a pronto.
- **Vida útil deixa de ser pedida** — só serviria para amortizar. Se um dia for
  precisa para valor residual, entra então.

---

## Ordem de trabalho proposta

Antes de qualquer slide novo:

1. **Slide 2 (Operacional) a sério.** Quatro filtros sobre `bookings`. Zero
   código novo de cálculo. Prova o padrão de ponta a ponta.
2. **Slide 1 (Síntese) a sério**, menos a célula 2 — as outras três já têm KPI.
   Decidir "hoje" vs "mês" na primeira célula.
3. **Perguntar o preço/dia** no onboarding e na identificação de máquina.
4. **`utilizacaoVsRentabilidadeMaquinasMes`** — a função nova. Só faz sentido
   depois do ponto 3, senão devolve "por apurar" a toda a gente.
5. **Slide 3 (Procura) a sério**, com "clientes novos" resolvido por inferência
   da primeira reserva, e o CTA ligado ao destino Leads.
6. **Todas as células sem dados escrevem "Por apurar" com a razão** — a regra já
   existe no `kpis.dart` e na `kpi_grid_2x2.dart`, é só respeitá-la.

Só depois disto os slides 4-9 (Tesouraria, Margem, Frota, Equipa, Objectivos,
Previsibilidade) valem a pena: aí o padrão está provado sobre dados reais e cada
alavanca nova é repetição, não invenção.
