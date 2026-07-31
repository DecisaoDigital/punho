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
