# O ciclo do trabalho — plano de execução

**Escrito a 4 de Agosto de 2026.** Substitui nada; complementa
`DECISOES_E_ROADMAP_VIVO.md` com uma única ideia estruturante.

---

## 1. Porque este documento existe

O Punho tem hoje peças excelentes e desligadas: leads que entram, máquinas que
se reservam, custos que se sabem ao cêntimo, recebimentos que se registam. O
que não tem é **um fio que as atravesse**. Cada uma vive no seu ecrã, e é o
gestor quem faz o transporte de cabeça.

A concorrência que serve de referência — Jobber, Housecall Pro, ServiceTitan —
não ganha por ter mais funcionalidades. Ganha porque tudo o que faz está
pendurado num objecto só, que anda do princípio ao fim:

```
pedido → orçamento → confirmado → em curso → concluído → recebido → volta
```

E a consequência disso não é estética, é de dados: **num ciclo, o dado não se
pede, cai.** Cada transição de estado é um facto registado por alguém que
estava a trabalhar, não a preencher um formulário. É por isso que os relatórios
deles são bons — não por terem melhores gráficos, por terem melhores entradas.

## 2. O que já existe (e ninguém está a usar)

Metade do ciclo já está escrita no modelo:

| Peça | Onde | Estado |
|---|---|---|
| `LeadStatus` | `domain/models/operations.dart` | `newLead → contacted → proposal → converted \| lost` |
| `BookingStatus` | idem | `request → proposalSent → confirmed → rented → completed \| cancelled` |
| `Booking.expectedValueCents` | idem | existe |
| `Receipt.bookingId` | `domain/models/finance.dart` | existe |
| `bookingReceivedTotal` / `bookingPendingCents` | idem | existem |
| `convertLead` | `core/operations/operations_controller.dart` | existe, idempotente |

Falta carne em três sítios e uma espinha que ligue tudo. Não é preciso inventar
objectos novos: **a `Booking` é o Trabalho**, e é ela que passa a carregar o
ciclo.

## 3. As quatro regras

Valem para tudo o que se seguir. São elas que impedem que o ciclo se transforme
noutra lista de campos.

1. **Um objecto do princípio ao fim.** O Trabalho carrega a lead que o originou
   e os recebimentos que o fecham. Nada de tabelas paralelas.
2. **Cada transição pede uma coisa só** — e nunca mais a volta a pedir. É a
   mesma regra que já governa os custos: *manda a fonte declarada.*
3. **Nunca existe um trabalho sem próximo passo visível.** Se o ciclo não sabe
   dizer o que fazer a seguir, o estado está mal desenhado.
4. **O ecrã diz, não descreve.** Um número sem verbo não é informação, é
   decoração.

## 4. As cinco funcionalidades em falta, por ordem de valor

**1. Orçamento a sério.** Há um estado (`proposalSent`) e um número
(`expectedValueCents`). Não há linhas (máquina × dias × preço), validade,
quando foi enviado, quando foi aceite, nem **porque se perdeu**. É a peça de
maior retorno: dá taxa de conversão, dá seguimento aos que não responderam, e
dá ao cliente o papel que ele precisa de mostrar a quem decide.

**2. Prova do serviço — fotos e assinatura, na entrega e na devolução.** Para
quem aluga máquinas não é conforto, é a diferença entre cobrar um dano e
discutir. Fecha também os extras: dias a mais, contador de horas, combustível
saem da devolução e não da memória de ninguém.

**3. A conversa com o cliente sai da app.** Confirmação, lembrete na véspera,
"vou a caminho", recibo. Não precisa de Twilio no dia 1: já existe
`url_launcher`, e um WhatsApp pré-escrito resolve 80% — desde que a app
**registe que foi enviado**.

**4. Fechar até ao documento fiscal.** `Receipt` é um pagamento, não é uma
factura. Enquanto o utilizador fechar o trabalho aqui e reescrever tudo noutro
lado, o Punho é mais um sítio onde ele trabalha. A ponte para o WashInvoice é o
que o torna *o* sítio.

**5. Saber o que a lead rendeu.** `LeadStatus.converted` não apontava para
cliente nenhum. Ligada a cadeia `Lead → Customer → Booking → Receipt`, passa a
haver **euros por canal** e não contagens.

As três primeiras põem o Punho à mesa. As duas últimas são as que ninguém copia
depressa.

## 5. As fases

### Fase 0 — a espinha *(feita a 4 de Agosto de 2026)*

Não entrega funcionalidade nova ao cliente; torna as outras baratas.

- `Lead` ganha `convertedCustomerId` e `bookingId` — a cadeia da origem.
- Um motor puro do próximo passo: `core/ciclo/proximo_passo.dart`. Dado um
  trabalho e uma data, devolve **um** passo, com verbo, motivo e urgência.
- Um ecrã, **A minha semana**, onde cada trabalho aparece no estado em que está
  com um botão só.
- Vocabulário: `bookingStatusLabel` sai de dentro do ecrã de reservas e passa a
  viver no modelo, onde já viviam `machineStatusLabel` e `leadSourceLabel`.

### Fase 1 — Orçamento

Linhas, validade, enviado em, aceite/perdido com motivo. Partilha com texto
gerado. O painel ganha a frase que hoje não pode dizer: *"3 orçamentos por
responder há mais de 4 dias — 4.200 €."*

**O que o cliente ganha:** deixa de perder trabalho por esquecimento. É a fase
que se paga a si própria mais depressa.

### Fase 2 — Execução

Entrega e devolução com fotografias, assinatura no ecrã e leitura de contador.
Extras calculados, não escritos.

**O que o cliente ganha:** deixa de discutir danos e deixa de esquecer os dias
a mais.

### Fase 3 — Cobrança

Do trabalho concluído sai o documento. Ponte para o WashInvoice. Dívida por
cliente à vista, com idade.

**O que o cliente ganha:** recebe mais cedo e escreve tudo uma vez só.

### Fase 4 — A volta

Cliente sem trabalho há 90 dias, máquina a chegar às horas de revisão, época
que se repete. **Uma** sugestão por semana, não uma caixa de entrada.

**O que o cliente ganha:** trabalho que aparece sem ter de andar à procura.

## 6. Onde está a diferenciação

Nenhuma das cinco funcionalidades acima diferencia — só põem à mesa. A
diferença do Punho está em duas coisas que a concorrência estruturalmente não
faz:

- **O painel que manda, não o que descreve.** *"A retroescavadora está parada
  há 9 dias e custa-te 38 €/dia mesmo parada. Estes 4 clientes alugaram-na o
  ano passado nesta semana."*
- **O custo verdadeiro por trabalho**, com TSU patronal, prestação da máquina e
  combustível, ao nível fiscal português. É o que permite dizer a frase que
  nenhum concorrente diz: *"este trabalho deu prejuízo"*, e *"este cliente
  parece bom e paga a 63 dias"*.

## 7. O que não construir

Mesmo que a concorrência tenha: rotas optimizadas, suites de atribuição de
marketing, inventário, processamento de salários. Não é aí que se ganha nada, e
cada um deles é um poço.

## 8. O teste do plano

> O gestor abre a app de manhã, faz o que ela diz, e fecha em dois minutos.

Se ele tiver de andar à procura do que fazer a seguir, o ciclo ainda não existe.

---

## Anexo — o que a Fase 0 deixou de fora, de propósito

- **A minha semana** entrou como segundo destino da barra, a seguir ao Painel,
  e **não** como ecrã de arranque. Com poucos trabalhos em carteira, uma lista
  vazia é uma má primeira impressão. Promover a primeiro é decisão para quando
  a Fase 1 estiver no terreno.
- Os sete destinos passaram a oito. A Decisão 2 (`navigation_controller.dart`)
  proibia destinos **condicionais** — uma barra que muda sozinha não se decora.
  Um oitavo destino permanente não a viola; muda-a uma vez, de propósito, e
  fica.
- A `Booking` não foi renomeada para `Trabalho` no código. O vocabulário mudou
  onde o utilizador lê; renomear a classe atravessa quatro ficheiros grandes e
  27 testes, e pagava-se com risco sem entregar nada. Faz-se com a Fase 1, que
  já lhe mexe na estrutura.
- O ecrã do colaborador (`collaborator_shell.dart`) ainda não tem A minha
  semana. É onde ela mais valeria — mas depende do perfil de acesso, e isso é
  desenho próprio.
