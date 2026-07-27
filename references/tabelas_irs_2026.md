# Tabelas de retenção — 2026

> **Aproximação, actualizar por ano.** Estes números servem para a app dar ao
> gestor uma ordem de grandeza do que sai da empresa e do que entra no bolso do
> trabalhador. **Não servem para processar salários.** Toda a UI que os use tem
> de mostrar o aviso de que é estimativa e que se confirma com o contabilista.
>
> Fonte a repor a cada ano: tabelas de retenção na fonte publicadas pela AT e
> taxas contributivas da Segurança Social. Quando o ano mudar, o ficheiro muda
> e os testes de `estimarSalarial` mudam com ele.

A tabela é **dimensão × regime**, não plana: o mesmo bruto lê-se de forma
diferente consoante quem paga e a que título. Isto vem da Decisão 1 do guião —
a forma jurídica é a raiz semântica dos KPIs, não um campo de identidade.

## Aplicabilidade

| Regime fiscal | Contrato de trabalho | Recibos verdes |
|---|---|---|
| `ldaIrc` | **Bloco A** — trabalhador dependente | **Bloco B** — categoria B |
| `eniOrganizado` | **Bloco A** | **Bloco B** |
| `eniSimplificado` | **Bloco A** | **Bloco B** |
| `outro` | não modelado | não modelado |

Notas de leitura, que são o que evita conclusões erradas:

- **`outro` não é modelado.** `estimarSalarial` devolve `null` e a UI diz
  "Estimativa não disponível para este regime × contrato; edita manualmente".
  Não se inventa um cálculo genérico: um número errado com aspecto de certo é
  pior do que a ausência dele.
- **O Bloco A aplica-se a qualquer regime que tenha trabalhadores
  dependentes.** É mais comum na Lda. (incluindo o sócio-gerente contratado
  como dependente), mas um ENI também pode ter empregados — e tem TSU patronal
  a pagar por eles como qualquer outra entidade.
- **O empresário em nome individual não entra em nenhum dos blocos.** Ele não é
  colaborador de si mesmo: desconta como trabalhador independente, ≈21,4% sobre
  o rendimento relevante. Fica fora desta tabela e fora do KPI de custo com
  pessoal. É contradição jurídica contá-lo, e a app não o conta.

## Bloco A — Trabalhador dependente (categoria A)

Aplicável quando `EmploymentType.contrato`.

### Contribuições — não dependem de escalão

| Quem | Taxa | Incide sobre |
|---|---|---|
| Trabalhador (TSU) | **11,00 %** | bruto |
| Entidade patronal (TSU) | **23,75 %** | bruto |

A TSU patronal é o "custo carregado" que não aparece no vencimento e que muitos
gestores esquecem: **1 000 € de bruto custam 1 237,50 € à empresa.**

Regimes especiais **não modelados** (aproximação, actualizar por ano): TSU
reduzida para pensionistas em actividade, isenções de jovem trabalhador,
contratos a muito curto prazo. Quem estiver nestes casos edita à mão.

### Retenção de IRS — aproximação por escalão

Taxa marginal aproximada sobre o bruto mensal, continente, para trabalhador
dependente. **Aproximação**: as tabelas reais têm parcela a abater e o cálculo
é progressivo, não uma taxa única.

| Bruto mensal | Solteiro, 0 dep. | Casado 1 titular | Casado 2 titulares |
|---|---|---|---|
| até 870 € | 0,0 % | 0,0 % | 0,0 % |
| 871 – 1 000 € | 4,3 % | 0,0 % | 2,2 % |
| 1 001 – 1 200 € | 8,6 % | 1,9 % | 6,1 % |
| 1 201 – 1 500 € | 12,4 % | 5,4 % | 9,6 % |
| 1 501 – 2 000 € | 16,8 % | 9,9 % | 14,0 % |
| 2 001 – 2 700 € | 21,5 % | 14,6 % | 18,7 % |
| 2 701 – 4 000 € | 26,5 % | 19,8 % | 23,8 % |
| 4 001 – 6 000 € | 31,3 % | 25,2 % | 28,9 % |
| acima de 6 000 € | 35,0 % | 30,0 % | 33,0 % |

**Dependentes:** cada dependente abate ≈0,8 pontos percentuais à taxa, até um
mínimo de 0 %. É uma simplificação grosseira do que a lei faz (deduções fixas
por dependente, não pontos de taxa) e está assim de propósito: a alternativa
era uma tabela de três dimensões que ninguém mantém.

**`MaritalStatus.other`** usa a coluna de solteiro. Não é uma afirmação sobre a
situação da pessoa — é a coluna mais conservadora das três, portanto o líquido
estimado sai por baixo em vez de por cima.

## Bloco B — Retenção na fonte, categoria B (prestação de serviços)

Aplicável quando `EmploymentType.recibosVerdes`.

O que a app precisa de saber aqui é curto, e é sobretudo o que **não** faz:

- **O valor pago é o custo total para a empresa.** Não há TSU patronal a somar.
  A entidade contratante tem, em certos casos, uma contribuição própria sobre
  prestadores economicamente dependentes — **não modelada**, porque depende de
  quanto do rendimento anual do prestador vem desta empresa, coisa que a app
  não sabe.
- **A retenção de IRS é retenção, não custo.** Sai do valor a pagar ao
  prestador, não acresce a ele. Taxa geral de **25 %** para a maioria das
  prestações de serviços; **isenção** para quem prevê faturar menos de
  15 000 € no ano e o declara. A app **não estima** este valor: quem emite o
  recibo é o prestador, e é ele que decide se retém.
- **Os descontos do prestador são dele.** A app não pede NISS, estado civil nem
  dependentes de quem está a recibos verdes, porque nada disso muda o que sai
  da empresa.

Por isso `estimarSalarial` devolve, para recibos verdes, uma estimativa
deliberadamente pobre: `custoEmpresa == bruto`, contribuições a zero, descontos
do trabalhador a `null`. O que a UI diz é a frase, não os números.

## Regime simplificado — porque não entra nesta tabela

Em `eniSimplificado` o **custo do próprio empresário** é presumido por
coeficiente (75 % do rendimento na prestação de serviços conta como matéria
tributável) e não por despesa real. Isso afecta os KPIs de margem do
empresário, não o custo dos empregados dele: um ENI simplificado com dois
empregados paga-lhes TSU patronal exactamente como uma Lda.

A distinção fica registada aqui porque é o erro fácil de cometer quando o motor
fiscal completo for escrito: **o coeficiente aplica-se ao rendimento do
empresário, nunca ao salário de terceiros.**
