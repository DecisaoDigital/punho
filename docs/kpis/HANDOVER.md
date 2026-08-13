# KPIs — o que ficou feito, e o que fica por fazer

13 de Agosto de 2026. Fecho do *Plano de Implementação do Sistema de KPIs*
(v1, 11 Ago 2026). O inventário da Fase 0 está em `MAPA_DADOS.md`; este
documento diz o que se construiu, porque é que o plano encolheu, e onde tocar a
seguir.

---

## O plano encolheu, e foi bom

O plano mandava criar `lib/kpis/motor/`, `lib/kpis/modelo/kpi_valor.dart` e
`lib/ecras/painel_kpis.dart`. **Nada disso se fez** — o repositório já tinha
2 263 linhas de motor puro, um catálogo com 25 indicadores, selecção manual para
o painel, ordenação por arrasto, e um tipo de retorno com estado explícito de
indisponibilidade. Construir `lib/kpis/` ao lado era um segundo motor a competir
com o que já corre no telemóvel dele.

O que o plano tinha e o repositório não tinha era **a cadeia**: os 25
indicadores eram uma lista plana, sem pai nem filhos. E é aí que estava o valor
inteiro da ideia — um número mau tem de ter um filho que o explique.

Fases 1 a 4 do plano: substituídas por «encadear o que existe».
Fases 5, 6 e 7: construídas.

---

## 1. Os dados — 26 meses semeados

`scripts/semear_historico_kpis.sql`, corrido contra produção. 1 995 operações,
Julho de 2024 a Agosto de 2026, na Depilconcept. Detalhe e números mês a mês em
`MAPA_DADOS.md` §3-bis.

**Abril de 2026 é mau de propósito**: as vendas sobem 1% e o lucro passa de
+635 € (Abril do ano passado) para −48 €, porque a estrutura saltou de 2 113 €
para 3 003 €. É o caso de prova de tudo o que se construiu a seguir.

Três coisas que a semente ensinou e que ficam escritas no próprio script: o
carimbo do log não deixa escrever no passado (corrige-se com `UPDATE`, depois do
`INSERT`); nada se semeia com data no futuro; e o homólogo precisa de 26 meses,
não de 15.

## 2. Os três mestres — `lib/core/operations/kpis_da_cadeia.dart`

O diagrama do plano põe **Vendas**, **Lucro** e **Fluxo de caixa** no topo. Dois
não existiam. Havia contas de caixa (`caixaDoMes`, `tesourariaDoMes`) e contas
de saúde (`margemBruta`, `fluxoDeCaixaLivre`), mas nada respondia a «quanto
vendi este mês» nem a «quanto ganhei este mês».

A decisão que estrutura tudo o resto: **Vendas e Lucro são de competência, a
Caixa é de caixa.** As vendas contam pela data do trabalho, os custos pela data
da despesa (paga ou por pagar); a caixa conta pelo dia em que o dinheiro mexeu.
São perguntas diferentes e têm de dar números diferentes — a diferença entre
elas é o prazo de recebimento, que é um KPI filho. O que **não** se pode é
misturar: receita de competência com custo de caixa dá uma margem que sobe
sempre que se atrasa um pagamento.

## 3. A cadeia — `KpiDefinicao.pai`

```
Caixa
├── Lucro do mês
│   ├── Vendas do mês
│   │   ├── Ticket médio · Clientes novos · Receita de quem volta
│   │   ├── Reservas activas → Entregas hoje · Recolhas · Alertas
│   │   ├── Conversão lead → cliente → Leads em pipeline → Leads a arrefecer
│   │   └── Utilização vs Rentabilidade
│   ├── Estrutura → Gastos previstos do mês
│   ├── Margem bruta
│   └── Custo de aquisição
├── Ciclo de tesouraria → Cobranças a vencer
├── Fluxo de caixa livre · Saldo e autonomia
└── Dinheiros que entraram · Encontro de contas · Tendência · Saldo previsto
```

`Recomendação do dia` é a única solta, e de propósito: não explica nenhum
número, lê-os todos.

A forma é verificada em `test/core/kpis/cadeia_test.dart` — pais que existem,
sem ciclos, ids únicos, e **nenhuma folha sem destino**. Esse último apanhou um
defeito a sério: as «Cobranças a vencer», as «Entregas hoje» e as «Recolhas a
fazer» eram becos — o gestor percebia o problema e não tinha para onde ir.

## 4. O ecrã de atenção — `lib/core/kpis/atencao.dart`

A frase não é um palpite. O lucro decompõe-se exactamente:

```
ΔLucro = ΔVendas − ΔEstrutura − ΔCustos directos
```

A soma dos efeitos das parcelas **é** a variação do lucro, ao cêntimo, e o teste
verifica-o. Ordena-se por quem mexeu mais, e o primeiro é o responsável.

Com os números que estão em produção, a app escreve:

> O lucro caiu 683 € face ao mesmo mês do ano passado. O que mais subiu foi a
> estrutura: 890 € (2113 € → 3003 €). Já as vendas mantiveram-se.

Essa frase está fixada ao carácter em `test/core/kpis/atencao_test.dart`.

**A parte que se manteve é metade da notícia.** Sem ela, «a estrutura subiu»
lê-se como se as vendas também tivessem corrido mal — e o gestor sai à procura
de clientes que já tem.

## 5. A navegação — `CadeiaDoKpiPage`

**Um KPI com filhos abre a cadeia; uma folha vai directa à acção.** É a regra
inteira do toque, no painel e na bancada.

Só se desce onde há alguma coisa por baixo: as «Entregas hoje» não têm
explicação para dar, e abrir uma página que só repetisse a célula era um toque a
mais para chegar ao mesmo sítio. O ecrã da cadeia acaba sempre com o botão para
o destino operacional — não se perde caminho nenhum, ganha-se uma explicação.

## 5-bis. O break even do mês (Fase 6) — `lib/core/kpis/break_even.dart`

Nasceu de uma frase dele, a 13 de Agosto, a olhar para um Lucro de 322 € a meio
do mês que eu queria «corrigir» por comparar 13 dias com um mês inteiro:

> não faz mal, porque é o previsto até hoje. poderia ser negativo ainda não se
> ter feito o break even do mês

A conta não estava errada — faltava-lhe o par. A meio do mês a despesa já
entrou quase toda (renda e salários caem nos primeiros dias) e as vendas ainda
vão a meio: **um lucro em baixo a dia 13 é um mês que ainda não virou, não um
mês mau**. O que responde a isso é quanto falta vender:

```
  alvo            = o que a casa gasta num mês
  vendas em falta = alvo − o que já se vendeu
```

**E é só isto — a definição é dele.** A minha primeira versão separava custos de
estrutura de custos de servir o trabalho e dividia o alvo por uma margem de
contribuição. Foi corrigida no mesmo dia:

> como assim, a despeza é a despesa. daí a media de gastos dos meses anteriores.
> entre a renda fixa e a media de electicidade variavel e agua variavel e outros
> consumos e despesas, fazem parte das despesas do mes, é natural que todos os
> custos se repitam em media durantes todos os meses no futuro e presente. o
> breack even é o valor para manter a empresa em operaçao. temos de contabilizar
> todas as tabelas

A separação fixo/variável tinha uma vantagem teórica — vender mais também custa
mais a servir — e três defeitos práticos: obrigava a classificar bem cada
despesa, dava um número que ninguém consegue conferir de cabeça, e respondia a
uma pergunta que ele não fez. A pergunta é «quanto tenho de vender este mês para
não estar a perder dinheiro?», e a resposta é o que a casa gasta. A luz e a água
variam, mas variam à volta de uma média — e é essa média que se paga todos os
meses.

**De onde vem o alvo:** o maior de três, porque nenhum serve o mês todo.

1. **A despesa já lançada este mês** — exacta, mas a dia 2 ainda é quase nada.
2. **A média dos três meses anteriores** — a ideia dele: os custos repetem-se em
   média, portanto o que se gastou é a melhor previsão do que se vai gastar.
3. **Os custos fixos declarados**, para quem os preencheu e ainda não tem
   histórico que chegue.

O maior, e não a soma: são três respostas à **mesma** pergunta, e somá-las era
contar a renda três vezes. Nunca abaixo do lançado — um mês com uma despesa
extraordinária já registada não se lê pela média dos meses normais. A célula diz
sempre de onde veio o alvo quando não é o lançado.

Duas decisões que valem mais do que a fórmula:

- **A média não conta meses em branco.** Um mês sem uma despesa lançada não é um
  mês de 0 € de renda, é um mês por preencher — metê-lo na média puxava o alvo
  para baixo em silêncio.
- **O dia em que passou é exacto** (contado venda a venda, por ordem de fim); o
  dia previsto é uma projecção pelo ritmo, e **desaparece** quando ao ritmo
  actual não chega ao fim do mês, em vez de apontar para um dia que não existe.

**E a estimativa corrige-se sozinha.** Objecção óbvia: num mês que venda muito
acima da média, os consumíveis desse mês também sobem e o alvo — que é a média —
fica curto. A resposta é dele, e é a razão de o «Lucro do mês anterior» existir:

> nem sempre é necessario subir as despesas para vender mais. mas se isso
> acontecer, por exemplo no mes de Julho, quando estivermos em agosto vemos o
> lucro real do mes anterior que ja reflete esses dois aumentos

A média é uma estimativa que a realidade corrige um mês depois: assim que Julho
fecha, entra na média com os gastos que teve mesmo. Os dois KPIs são um par —
um estima agora, o outro diz a verdade a seguir. E o desvio, enquanto dura, é
pequeno: a maior parte da despesa de um mês não depende de se vender mais.

E uma ligação que o teste guarda: **o break even é a despesa do mês e o lucro é
o que passa dela**. Vendendo exactamente o que se gastou, o lucro dá zero. Se um
dia deixarem de bater, um deles está a contar uma despesa que o outro não conta.

Em produção, Agosto de 2026 da Depilconcept: despesa lançada 2 321 €, média dos
três meses anteriores **2 408 €** (2 357 + 2 345 + 2 522) — é ela o alvo, e
passou a 6 de Agosto. Por isso os 322 € de lucro que ele leu no telemóvel são um
mês já pago, e não um susto.

## 5-ter. Duas células do lucro, e porque são duas

Pedido dele, 13 de Agosto: *«quero um Kpi do lucro do mes anterior e um kpi com
o lucro até ao momento do mes, lucro ou prejuiso»*.

Não é o mesmo número duas vezes. O **mês a decorrer** tem a estrutura toda
lançada nos primeiros dias e as vendas a meio — a dia 13 lê-se mal se não se
disser que é dia 13. O **mês anterior** é o único mês inteiro, e por isso o
único que se compara sem ressalvas: é a régua.

- `lucro-mes` passou a escrever a palavra: **«322 € de lucro até hoje»**,
  **«1 811 € de prejuízo até hoje»**. O sinal sozinho passa ao lado; a palavra
  não. A margem desceu para a sub-linha, e não se perdeu.
- `lucro-mes-anterior` é novo, e fica **fora da cadeia** de propósito — como
  filho do Lucro do mês apareceria na lista do «o que está por trás deste
  número», e o mês passado não está por trás de nada: está ao lado.

## 5-quater. Os três meses lado a lado

Também dele, no mesmo dia: *«na realidade eu ali gostava de ver o lucro do mês
anterior»*. A célula só tem espaço para um termo de comparação e escolhe o
homólogo — que num negócio com estações é o que diz mais, mas deixava de fora o
mês passado, que é o que ele tem fresco na cabeça.

Duas correcções: a sub-linha da célula passou a trazer **o valor em euros** ao
lado da percentagem (`▼ 80% face a 1585 € do ano passado` — uma percentagem
grande sobre um mês pequeno assusta sem motivo), e o ecrã da cadeia ganhou os
três meses em coluna. Um mês sem uma única linha escreve-se «sem registos», não
0 € — 0 € era dizer que o mês correu mal quando o que houve foi não haver mês.

## 6. O homólogo (Fase 7)

`MesComparado` traz o mês anterior **e** o homólogo, e o homólogo ganha sempre
que exista. Num negócio com estações, comparar Setembro com Agosto acusa o
calendário em vez do negócio. Sem termo nenhum, diz-se que não há — nunca uma
percentagem fabricada.

---

## O que fica por fazer

**1. O crivo humano das contas novas.** O **Lucro do mês passou** — a 13 de
Agosto, no Redmi, com a app actualizada por ela própria à 0.3.75: o ecrã disse
322 € e a base dizia 322 €. Faltam as **Vendas**, a **Estrutura** e o **break
even**, que nasceram todos com `contaVerificada: true` porque a conta foi
conferida contra a base (query em `MAPA_DADOS.md` §7) — e isso é a conta bater,
não é ele ter olhado e concordado.

**2. ~~O break even com custos fixos declarados.~~ Resolvido, e melhor do que
estava previsto.** A versão que ficou aqui escrita usava só a despesa lançada, e
por isso no dia 2 — com a renda por lançar — dava um alvo baixo que ia subindo à
medida que as despesas entravam. Ia buscar-se aos `custosFixos` declarados em
Empresa › Custos fixos, que nem todas as empresas preenchem.

Resolveu-se sem depender de ninguém preencher nada: o alvo é o maior entre a
despesa lançada, a média dos três meses anteriores e os custos fixos declarados
— ver 5-bis. Os declarados continuam a servir, mas como rede para quem ainda não
tem histórico, e não como condição.

**3. O prazo médio de pagamento a fornecedores.** A semente lança todas as
despesas como `paid` no próprio dia, portanto o DPO é zero e o ciclo de
tesouraria fica meio. Está assinalado em `MAPA_DADOS.md` §4 em vez de
disfarçado.

**4. Promoção automática ao painel.** O plano previa-a; continua tudo manual. A
cadeia é a peça que faltava para a poder fazer bem — quem sobe ao painel devia
ser o filho que explica o número que está mau —, mas isso mexe no painel dele
sem lhe perguntar, e não se faz sem ok.

**5. O que está publicado, e o que não está.** A cadeia, o ecrã de atenção e o
homólogo saíram na **0.3.75+47**, a 13 de Agosto — e chegaram ao Redmi pela
auto-actualização da própria app, sem cabo e sem browser (o ponto 11 do
`SMOKE.md`, que estava por provar desde a 0.3.3). O **break even** e os três
meses lado a lado são posteriores: estão no repositório e **não** estão em
nenhum APK.
