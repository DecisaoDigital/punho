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
Fases 5 e 7: construídas.
Fase 6 (break even): **não feita** — ver «O que fica por fazer».

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

## 6. O homólogo (Fase 7)

`MesComparado` traz o mês anterior **e** o homólogo, e o homólogo ganha sempre
que exista. Num negócio com estações, comparar Setembro com Agosto acusa o
calendário em vez do negócio. Sem termo nenhum, diz-se que não há — nunca uma
percentagem fabricada.

---

## O que fica por fazer

**1. O crivo humano das três contas novas.** As Vendas, o Lucro e a Estrutura
nasceram com `contaVerificada: true` porque a conta foi conferida contra a base
(query em `MAPA_DADOS.md` §7) — mas isso é a conta bater, não é o César ter
olhado para o ecrã e concordado com o que ele diz. **Falta o passo a pé, no
telemóvel**, com os dados da Depilconcept.

**2. Fase 6 — break even.** Não foi feita. Precisa de separar custo fixo de
custo variável, e a app hoje só tem `custosFixos` declarados à mão, que nem
todas as empresas preenchem. É a fase que arrisca mais inventar.

**3. O prazo médio de pagamento a fornecedores.** A semente lança todas as
despesas como `paid` no próprio dia, portanto o DPO é zero e o ciclo de
tesouraria fica meio. Está assinalado em `MAPA_DADOS.md` §4 em vez de
disfarçado.

**4. Promoção automática ao painel.** O plano previa-a; continua tudo manual. A
cadeia é a peça que faltava para a poder fazer bem — quem sobe ao painel devia
ser o filho que explica o número que está mau —, mas isso mexe no painel dele
sem lhe perguntar, e não se faz sem ok.

**5. Nada disto está publicado.** O código está no repositório e por commitar.
O telemóvel tem uma build local rotulada 0.3.74 que **não** leva a cadeia.
