# Punho — perguntas que alimentam os dados

> Lista viva. Serve para o César e o Claude se guiarem: que pergunta existe,
> onde se responde, e que KPI/célula fica coxo sem ela.
>
> Gerado a partir de uma auditoria estática ao código em 2026-08-03. Precisa
> de confirmação em primeira pessoa (usar a app como gestor real, ver
> `docs/PLANO_DE_TESTES_2026-08-02.md`) — o código diz onde a pergunta *devia*
> aparecer, não garante que aparece bem desenhada ou no sítio certo.

## Como ler

- **✅ implementado** — campo no modelo + formulário que o preenche + célula
  que já usa o dado. Se está vazio é só falta de dados a preencher, não falta
  de código.
- **⚠️ formulário existe, sem tarefa** — campo e formulário existem, mas
  ficar por preencher não gera nenhuma linha em Tarefas — o gestor só dá por
  isso se calhar de abrir a ficha.
- **❌ falta código** — falta campo no modelo, formulário, ou o cálculo que
  usa o dado. É trabalho de programação, não de preenchimento.

---

## Empresa (onboarding / definições)

Todas com formulário em `lib/features/company/presentation/company_settings_page.dart`
e tarefa automática via `OperationsState.initialDataTasks`
(`lib/core/operations/operations_controller.dart:132`) quando vazias.

| Pergunta | Campo | Estado |
|---|---|---|
| Qual é o NIF da empresa? | `companyTaxId` | ✅ implementado, tarefa urgente |
| Qual é o nome do responsável? | `ownerName` | ✅ implementado |
| Qual é o contacto (telefone) da empresa? | `companyPhone` | ✅ implementado |
| Morada, código-postal, localidade | `companyAddress/companyPostalCode/companyLocality` | ✅ implementado |
| Faturação do ano passado | `revenueLastYearCents` | ✅ implementado |
| Faturação deste ano até hoje | `revenueThisYearCents` | ✅ implementado |
| Manutenção paga no ano passado | `maintenanceLastYearCents` | ✅ implementado |
| Custos fixos mensais (rubricas: renda, eletricidade, seguros...) | `custosFixos` | ✅ implementado |
| Faturação de cada mês do ano passado (12 registos) | `historicalMonths` | ✅ implementado — alimenta a comparação homóloga |

## Máquinas

Formulário em `lib/features/operations/presentation/operational_pages.dart`
(`_FormularioDeMaquina`, ~linha 1404).

| Pergunta | Campo | Onde | Estado |
|---|---|---|---|
| Preço por dia de aluguer | `Machine.dailyRateCents` | form linha ~1481 | ✅ implementado |
| Valor de compra da máquina | `Machine.purchasePriceCents` | form linha ~1486 | ✅ implementado; sem tarefa dedicada até 2026-08-03 (ver correção abaixo) |
| Data de aquisição | `Machine.acquiredOn` | form linha ~1491 | ✅ implementado |

**Corrigido em 2026-08-03:** a célula "Utilização vs Rentabilidade"
(`sintese_slide.dart`) nunca chegava a calcular nada — ficava sempre em
"Por apurar" mesmo com preço/dia e valor de compra preenchidos para toda a
frota. Não era falta de pergunta, era falta da conta: `ocupacaoMaquinasSemana`
já existia e nunca tinha sido cruzada com `purchasePriceCents`. Agora há
`utilizacaoERentabilidade()` em `lib/core/operations/kpis.dart` a fazer essa
conta (ocupação da semana + % do investido recuperado pela receita das
reservas). Também passou a gerar tarefa (`maquinas-sem-dados-de-retorno` em
`tarefas_service.dart`) quando falta preço/dia ou valor de compra em alguma
máquina não arquivada.

## Reservas

Formulário em `operational_pages.dart` (~linha 3389).

| Pergunta | Campo | Estado |
|---|---|---|
| Valor previsto da reserva | `Booking.expectedValueCents` | ⚠️ formulário existe, campo opcional — sem ele "Ticket médio (30d)" fica "Por apurar" por falta de dados, não por falta de pergunta |

## Colaboradores

Formulários em `lib/features/workforce/presentation/workforce_pages.dart` e
`ficha_fiscal_form.dart`.

| Pergunta | Campo | Estado |
|---|---|---|
| Custo estimado para a empresa (€/mês) | `Collaborator.costCents` | ⚠️ formulário existe, sem ele "custo/hora" fica "por apurar"; já gera tarefa (`colaboradores-incompletos`, `tarefas_service.dart`) |
| Horas semanais previstas | `Collaborator.schedule` | ⚠️ idem, mesma tarefa cobre os dois em conjunto |
| NISS (vínculo contrato) | `Collaborator.socialSecurityNumber` | ✅ implementado, tarefa dedicada por pessoa |
| NIF (vínculo recibos verdes) | `Collaborator.taxId` | ✅ implementado, tarefa dedicada por pessoa |

## Frota (veículos)

Formulário em `workforce_pages.dart` (~linha 884).

| Pergunta | Campo | Estado |
|---|---|---|
| Prestação mensal do veículo | `Vehicle.monthlyPaymentCents` | ⚠️ formulário existe, sem tarefa se ficar vazio |
| Seguro (valor + periodicidade) | `Vehicle.insuranceCents` / `insuranceFrequency` | ⚠️ idem |

## Estados que são "Por apurar" por falta de movimento, não de pergunta

Não exigem nenhuma pergunta nova — resolvem-se sozinhos quando a operação
gera o primeiro registo do tipo:

- "Dinheiros que entraram" — sem `Receipt` nenhum registado
- "Reservas ativas" — sem `Booking` nenhuma
- "Clientes novos (30d)" — sem `Booking` confirmada recente
- "Conversão lead → cliente" — sem `Lead` nos últimos 30 dias
- "Ticket médio (30d)" — sem reserva com valor previsto nos últimos 30 dias

## Por fazer

- [ ] Confirmar em primeira pessoa (preencher a app como gestor real) se
  alguma destas perguntas está mal desenhada, escondida, ou pede o dado de
  forma confusa — a auditoria só confirma que o campo e o formulário
  existem, não que a UX funciona.
- [ ] Decidir se "Custo estimado do colaborador", "Horas semanais", "Valor
  previsto da reserva", "Prestação mensal" e "Seguro do veículo" merecem
  tarefa própria quando vazios (hoje só os dois primeiros já geram tarefa,
  via `colaboradores-incompletos`) — ou se ficam mesmo como preenchimento
  opcional e silencioso.
- [ ] Motor de recomendação: há dois motores em paralelo
  (`GuidanceEngine`/`recomendacaoDaSemana` — em uso — e `recomendacaoDoDia`
  — testado, nunca ligado à UI). Decisão pendente em separado (ver tarefa
  "Fundir motores de recomendação num só canónico").
