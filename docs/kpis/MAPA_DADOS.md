# Fase 0 — Inventário de dados

13 de Agosto de 2026. Entregável da Fase 0 do *Plano de Implementação do
Sistema de KPIs* (v1, 11 Ago 2026). Nada da Fase 1 arranca antes de isto estar
lido.

O plano dizia: «É aqui que o plano provavelmente encolhe, e isso é bom.»
Encolheu, e por duas razões diferentes — uma de dados e outra de código. A
segunda não estava prevista.

---

## O resumo, antes dos detalhes

**1. O motor já existe.** O plano manda criar `lib/kpis/motor/`, `lib/kpis/
modelo/kpi_valor.dart` e `lib/ecras/painel_kpis.dart`. O repositório já tem
2263 linhas de motor puro, um catálogo de **25 indicadores** com selecção e
ordenação, e o tipo de retorno com estado explícito de indisponibilidade.
Construir `lib/kpis/` ao lado disso é um segundo motor a competir com o que
está a correr no telemóvel dele.

**2. A Depilconcept não tem dados para dois dos três mestres.** Zero
recebimentos, zero despesas, zero leads, zero veículos, e a ficha da empresa
sem facturação e sem custos fixos. O **Lucro** e o **Fluxo de Caixa** não têm
uma linha de origem. As fórmulas existem; os dados não.

O portão da Fase 0 — «o mapa lista pelo menos os três indicadores mestres como
calculáveis, com origem confirmada por query corrida contra a base real» —
**não passa**. Um dos três passa. Está tudo abaixo, com o output colado.

---

## 1. A língua dos identificadores

O plano manda confirmar a língua e nunca misturar. A resposta honesta é que o
repositório **já mistura, e por camadas**:

| Camada | Chamadas em português | Em inglês |
|---|---|---|
| `lib/domain` | 1 | 19 |
| `lib/data` | 1 | 66 |
| `lib/core` | 19 | 162 |
| `lib/features` | 25 | 107 |

*(contagem por amostra de verbos e substantivos do domínio em nomes de função)*

O padrão não é acidental e vale a pena mantê-lo em vez de o uniformizar: **o
modelo de domínio e a persistência estão em inglês** (`Booking`,
`expectedValueCents`, `BookingStatus.rented`) porque nasceram com o esquema;
**a regra de negócio e os ecrãs estão em português** (`tarefasPendentes`,
`estadoPeloRelogio`, `cobrancasPorReceber`, `CelulaSemaforo`). Renomear o
domínio agora é um refactor de centenas de sítios sem ganho para o gestor.

**Regra para as fases seguintes:** código novo de KPI escreve-se em português,
como o resto de `lib/core` e `lib/features`; toca-se nos nomes ingleses só
quando se lê o modelo.

---

## 2. Onde vivem os dados — e a armadilha

O Punho é *local-first*. A verdade de cada terminal é o estado local; o
servidor guarda **o registo de operações** (`punho_operacoes`, append-only) e
**uma projecção** por entidade. Os KPIs correm no cliente, sobre
`OperationsState`, e não sobre SQL.

Isso muda o que significa «origem exacta (tabela.coluna)» no plano: para o
motor, a origem é o **campo do modelo Dart**; a tabela do servidor é o espelho.
As duas colunas estão na tabela do §4.

**Só `punho_reservas` tem colunas tipadas.** Todas as outras entidades guardam
o essencial dentro de `dados jsonb`:

```
punho_reservas       id, empresa_id, cliente_id, inicio, fim, estado,
                     valor_previsto_centimos, cliente_nome_snapshot, …
punho_despesas       dados jsonb → amountCents, category, date, description,
                     machineId, status, archived
punho_recebimentos   dados jsonb → amountCents, bookingId, customerId, date,
                     method, recordedByCollaboratorId
punho_maquinas       dados jsonb → dailyRateCents, purchasePriceCents,
                     acquiredOn, category, status, archived
punho_leads          dados jsonb → source, status, convertedCustomerId,
                     bookingId, createdAt
punho_empresas       dados jsonb → facturacao_ano_passado_centavos,
                     facturacao_este_ano_centavos,
                     custos_fixos_mensais_centavos,
                     manutencao_ano_passado_centavos
```

`punho_cobrancas` é derivada e já traz `previsto_centimos`,
`recebido_centimos`, `por_cobrar_centimos` — dinheiro em cêntimos inteiros,
como o plano exige. **Não há um único campo monetário em vírgula flutuante.**

---

## 3. Densidade real — Depilconcept, 13 Ago 2026

Query corrida contra `oefqbkhioncakojipqyx`, output colado:

| tabela | linhas | de | até |
|---|---:|---|---|
| reservas | 3 | 2026-08-11 | 2026-08-12 |
| clientes | 4 | 2026-08-10 | 2026-08-12 |
| máquinas | 3 | — | — |
| **recebimentos** | **0** | — | — |
| **despesas** | **0** | — | — |
| **leads** | **0** | — | — |
| **veículos** | **0** | — | — |

Ficha da empresa:

| empresa | fact. ano passado | fact. este ano | custos fixos | manutenção |
|---|---|---|---|---|
| **Depilconcept** | **null** | **null** | **null** | **null** |
| Aluguer Nogueira | null | 12 800,00 € | 1 800,00 € | null |
| Lavandaria Nocturna (teste) | 45 000,00 € | 12 000,00 € | 900,00 € | 1 500,00 € |

Confirmado contra o registo de operações, não só contra a projecção: a
Depilconcept tem operações de `booking`, `customer` e `machine` — **nenhuma de
`expense` nem de `receipt`**. Não é perda de projecção; é ausência de registo.

**Consequências duras:**

- **Dois dias de dados.** Não há mês fechado, não há comparação homóloga, não
  há tendência. A Fase 7 exige 13 meses; faltam 13.
- **Sem despesas não há Lucro, nem Margem, nem Estrutura Compactada, nem break
  even.** São as Fases 3 e 6 inteiras.
- **Sem recebimentos não há Fluxo de Caixa nem prazo médio de recebimento.**
- **Sem leads não há funil**, portanto não há número de contactos nem taxa de
  conversão — os dois primeiros filhos das Vendas. O plano já avisava para não
  inventar uma proxy; confirma-se que não há nada para inventar a partir de.

---

## 4. Os 12 indicadores do diagrama

`OK` = calculável hoje com dados reais da Depilconcept. `motor` = a conta já
está escrita e testada. `sem dados` = a conta existe e devolve o estado de
indisponível, porque a fonte está vazia.

| # | Indicador | Estado | Já implementado em | Origem |
|---|---|---|---|---|
| 1 | **Vendas** | ⚠️ parcial | `kpis.dart` (`ticketMedioDoMes`, `previsaoDoMes`) | `punho_reservas.valor_previsto_centimos` |
| 2 | **Lucro** | ❌ sem dados | `kpis.dart` (`resultadoMesConservador`, `tesourariaDoMes`) | precisa de `punho_despesas` |
| 3 | **Fluxo de caixa** | ❌ sem dados | `kpis_de_saude.dart` (`fluxoDeCaixaLivre`, `saldoEAutonomia`) | precisa de `punho_recebimentos` + `punho_despesas` |
| 4 | nº de contactos | ❌ não recolhido | `funilProcura` existe | `punho_leads` está vazia |
| 5 | taxa de conversão | ❌ não recolhido | `funilProcura`, KPI `conversao-lead-cliente` | idem |
| 6 | CAC | ❌ fora da v1 | `custoDeAquisicao` | precisa de despesa de campanha |
| 7 | nº médio transacções/cliente | ⚠️ parcial | `ticketMedioDoMes` conta clientes que repetiram | `punho_reservas` — 3 linhas |
| 8 | valor médio de transacção | ⚠️ parcial | `ticketMedioDoMes` | `punho_reservas.valor_previsto_centimos` |
| 9 | margem bruta | ❌ sem dados | `kpis_de_saude.dart` (`margemBruta`) | precisa de `punho_despesas` |
| 10 | Estrutura Compactada | ❌ sem dados | `custosMesAgregados`, `rubricasFrota` | precisa de `punho_despesas` classificadas |
| 11 | prazos (pagamento/stock/recebimento) | ❌ sem dados | `kpis_de_saude.dart` (`cicloDeTesouraria`) | precisa das duas tabelas vazias |
| 12 | buraco de tesouraria | ❌ sem dados | `cicloDeTesouraria` devolve-o | idem |

**Um em doze é calculável, e mal** — o «Vendas» da Depilconcept são três
reservas de dois dias.

Nota sobre o nº 11: a Depilconcept não tem stock, e o plano já previa que o
prazo médio de stock fosse zero. Não é o problema. O problema são os outros
dois prazos, que dependem de facturas que não existem no sistema.

---

## 5. O que já está construído — e que o plano manda construir outra vez

| O plano pede | Já existe | Onde |
|---|---|---|
| `lib/kpis/motor/` | motor puro em `(state, now)`, 2263 linhas | `lib/core/operations/kpis.dart`, `kpis_de_saude.dart` |
| `lib/kpis/modelo/kpi_valor.dart` com estado e unidade | `CelulaSemaforo` (valor, unidade, sub-texto, nível) | `lib/features/dashboard/presentation/widgets/celula_semaforo.dart` |
| `KpiIndisponivel(razao)`, nunca zero silencioso | `NivelSemaforo.aguarda` + `EstadoVerdade.porDefinir` + campo `desbloqueio`, que diz **que dado falta** | `kpi_catalogo.dart` |
| Fase 4 — catálogo com selecção | 25 indicadores, marcação para o painel, ordenação por arrasto | `kpi_catalogo.dart`, `lib/features/kpis/presentation/kpis_page.dart` |
| Fase 5 — apreciação de cada valor | `ApreciacaoDoKpi` com tom e frase em português | `lib/core/kpis/apreciacao.dart` |
| Fase 1 — ecrã com os cartões | painel + «KPIs (todos)» | `pagina_do_painel.dart`, `kpis_page.dart` |

Há ainda uma peça que o plano não previu e que resolve metade da Fase 0 em
permanência: `KpiDefinicao.contaVerificada`. É um booleano posto à mão, KPI a
KPI, à medida que a conta é conferida — exactamente o «crivo humano» que o
plano pede no portão de cada fase, mas gravado no código em vez de num
documento que envelhece.

**O que o plano tem e o repositório não tem:**

1. **O encadeamento.** Os 25 indicadores são uma lista plana. Não há pai nem
   filhos, e é essa a ideia central do plano — um número mau tem de ter um
   filho que o explica. *Isto é o que falta construir, e é o que vale.*
2. **Balizas.** `ApreciacaoDoKpi` compara com o período anterior; não há noção
   de valor aceitável nem de sair dela.
3. **Ecrã de atenção.** Não existe.
4. **Promoção automática.** Não existe; a selecção é toda manual.

---

## 6. O que proponho, e porquê

**A Fase 0 não passa o portão.** Não vou abrir a Fase 1 como está escrita.
Recomendo três correcções ao plano:

**a) Trocar «criar o motor» por «encadear o motor que existe».** A Fase 1
deixa de ser um motor novo e passa a ser o campo `pai` no `KpiDefinicao` mais
a navegação por toque. É a ideia do plano — a cadeia — aplicada ao que já
corre. Poupa as Fases 1 a 4 quase inteiras e não deita nada fora.

**b) Antes de qualquer KPI de dinheiro, resolver a entrada de dados.** Nenhuma
conta de Lucro, Margem, Estrutura ou Tesouraria pode ser conferida contra a
Depilconcept enquanto ela não tiver uma despesa e um recebimento registados. O
portão de cada uma dessas fases — «conferido à mão contra a contabilidade» — é
inatingível hoje. **A pergunta a fazer-lhe é se a Depilconcept vai passar a
registar despesas e recebimentos no Punho, ou se esses números vêm de fora.**
A resposta decide se as Fases 3 e 6 existem.

**c) Manter a Lavandaria Nocturna como banco de ensaio.** É a única empresa com
despesas (6), recebimentos (3) e ficha completa. Serve para provar as contas
enquanto a Depilconcept não tiver dados — sem inventar seeds na empresa real,
que é regra dele.

---

## 7. Queries corridas, para o handover

```sql
-- densidade por entidade (Depilconcept)
with e as (select id from punho_empresas where nome='Depilconcept')
select 'reservas', count(*), min(inicio::date), max(inicio::date)
  from punho_reservas r, e where r.empresa_id=e.id
union all select 'recebimentos', count(*),
  min((dados->>'date')::date), max((dados->>'date')::date)
  from punho_recebimentos x, e where x.empresa_id=e.id
union all select 'despesas', count(*),
  min((dados->>'date')::date), max((dados->>'date')::date)
  from punho_despesas x, e where x.empresa_id=e.id;
-- → reservas 3 (2026-08-11 … 2026-08-12); recebimentos 0; despesas 0

-- chaves reais dentro do jsonb
select string_agg(distinct k, ', ')
  from punho_despesas d, jsonb_object_keys(d.dados) k;
-- → amountCents, archived, category, date, description, id, machineId,
--   note, status

-- ficha da empresa
select nome, dados->>'facturacao_este_ano_centavos',
       dados->>'custos_fixos_mensais_centavos' from punho_empresas;
-- → Depilconcept: null, null
```
