# Auditoria: o empresário exemplar

**Pergunta de partida:** se um empresário real, empenhado, responder a tudo o que a app pergunta e tiver todos os dados para preencher os campos — a Punho resulta? O que consegue mostrar, e o que ainda é código partido?

**Data:** 2026-08-02. **Estado do código:** verificado contra o repositório ao vivo (havia outra sessão a editar `lib/` durante esta auditoria — ver nota no Eixo 3). Commits de referência: `de11645`, `091d5d8`, `59fb98c`, `5a2d41b`.

---

## Eixo 1 — O que a app pergunta

### Onboarding

Os três ecrãs em `lib/features/operations/presentation/` (`boas_vindas_screen.dart`, `ecra_de_contexto.dart`, `mais_dados_screen.dart`) **não pedem dados** — são ecrãs de contexto (ícone, texto, um botão). Servem para explicar o que vem a seguir. A recolha real está em `OnboardingPage`, dentro de `operational_pages.dart:28-551`, organizada em passos:

| Passo | Campos | Obrigatório |
|---|---|---|
| 0 | Nome (do utilizador) | Sim |
| 1 | Nome da empresa | Não (default "A minha empresa") |
| 2 | Cargo — Gestor / Colaborador | Sim (dropdown) |
| 3 (colaborador) | Telemóvel | Não |
| 3 (gestor) | Forma jurídica (ENI / Lda.), NIF da empresa | Forma jurídica sim, NIF não |
| 4 (só gestor) | Morada, Código-postal, Localidade, Telemóvel/telefone, Email | Não |
| 5 (só gestor) | Nº de colaboradores, Nº de veículos | Sim (numérico, default 0) |
| 6 (só gestor) | Switch "quero preencher agora" / "entro e preencho depois" | — |
| 7 (se escolheu preencher tudo) | Número aproximado de máquinas | Sim (numérico, default 0) |
| 8–11 | Faturação ano passado (€), Faturação este ano até hoje (€), Manutenção paga no ano passado (€), Custos fixos mensais (€) | Não |

Validação de euros: `_euroCents()` (linha 558) — trata corretamente separador de milhar português (ponto) e decimal (vírgula).

### `InitialDataTasksPage` — "Dados por completar" (linhas 615-821)

Repete os mesmos campos de identificação da empresa e as 4 referências financeiras do onboarding, num único ecrã, para quem entrou sem preencher tudo.

### `HistoricalDataPage` — "Histórico mensal" (linhas 832-892)

Dropdown de ano + editor por mês (12 meses). Por mês pede, segundo a decisão de roadmap documentada: recebimentos, despesas pagas, publicidade, leads recebidas, leads convertidas, manutenção — todos opcionais.

### Formulário de Máquina (`_FormularioDeMaquina`, linhas 1350-1519)

Nome* (obrigatório), Número interno/série, Categoria, Preço diário de aluguer (€), Estado atual (dropdown), Notas/manutenção, Fotografias. **Não pede valor de compra nem data de aquisição** (ver Eixo 2 — é o achado mais grave desta auditoria).

### Formulário de Veículo (`_FormularioDeVeiculo`, `workforce_pages.dart:726-841`)

Matrícula* (obrigatória, aceita qualquer texto — sem validação de formato), Tipo, Nome/identificação, Prestação mensal (€), Seguro (€), Periodicidade do seguro. **Só existe para criar — nunca para editar** (ver Eixo 3).

### Formulário de Cliente (`_FormularioDeCliente`, linhas 1776-1959)

Nome* (obrigatório), Telemóvel, NIF, Email, Morada, Código-postal, Localidade, Notas. Valida duplicados por telemóvel/NIF.

### Formulário de Lead (`_FormularioDeLead`, linhas 1977-2062)

Só Nome e Telemóvel (ambos preenchidos são exigidos na gravação, mas sem asterisco visual nem validação de duplicados). Nunca pede Email, NIF, Morada — só 2 dos 8 campos que o Cliente tem.

### Formulário de Colaborador (`_FormularioDeColaborador`, `workforce_pages.dart:259-532`)

Nome* (obrigatório), Custo estimado (€), Telemóvel, Função, Periodicidade do custo* (mensal/semanal), Horas semanais previstas. Depois, consoante o vínculo (Contrato / Recibos Verdes):
- **Contrato:** NISS (regex `^[12]\d{10}$`, só aviso, não bloqueia), Estado civil* (dropdown), Nº de dependentes, IBAN, Morada.
- **Recibos Verdes:** NIF do prestador (aviso se não tiver 9 dígitos), IBAN, Morada.

### Formulário de Reserva/Marcação (dois formulários distintos, assimétricos)

- **Confirmação de reserva** (a partir do calendário, linhas 3079-3330): Cliente (dropdown, com opção "Novo cliente…" inline), Estado inicial, Valor previsto (€), Notas.
- **Nova marcação** (linhas 3390-3700+): Cliente, Máquina, Duração (Meio dia/Dia inteiro/Vários dias), Período (se meio dia), datas (date picker), Estado inicial, Responsável (só se aplicável), Valor previsto (€), Notas.

### Despesa (`RegisterExpensePage`, `finance_pages.dart`)

Valor, Categoria* (dropdown), Máquina associada (opcional), Veículo associado (opcional), Nota, Estado (Paga/Por pagar — só o gestor escolhe; colaborador é sempre "Por pagar"), Documento (opcional, com OCR/QR).

### Recebimento (`RegisterReceiptPage`, `finance_pages.dart`)

Valor, Cliente* (dropdown, obrigatório), Reserva associada (opcional), Método (dropdown), Nota.

### Ficha fiscal — ver Colaborador acima (é o mesmo formulário, condicional ao vínculo).

**Assimetrias registadas no Eixo 1:** Cliente (8 campos, valida duplicados) vs Lead (2 campos, sem validação); Máquina (CRUD completo com editar) vs Veículo (só criar) vs Cliente (criar/editar, sem eliminar); Confirmação de reserva (permite criar cliente inline) vs Marcação directa (não permite).

---

## Eixo 2 — O que a app precisa para mostrar o que promete

Cruzando os ecrãs de resultados (`kpis.dart`, dashboard, tarefas, finanças) com o Eixo 1, a disciplina geral do código é boa: zeros por falta de dados aparecem como `null` → "Por apurar" com uma explicação, não como `0` enganador. Mas há **perguntas que a app nunca faz**, o que condena certos números a ficarem "Por apurar" para sempre — mesmo com o empresário mais dedicado.

### O achado mais grave: "Utilização vs Rentabilidade" nunca sai de "Por apurar"

`lib/features/dashboard/presentation/slides/sintese_slide.dart:95-124`. A célula precisa de **preço/dia** (que o formulário de máquina pede) e de **valor de compra** (`Machine.acquiredOn`, campo que já existe no modelo — `lib/domain/models/operations.dart:90` — e é gravado/lido no repositório Supabase). Mas **nenhum ecrã da app tem um campo para o preencher.** O próprio código admite isto no comentário:

> "Falta o valor de compra das máquinas para calcular o retorno" — a máquina "ainda não guarda" [na UI], e sem ele não há retorno para pôr ao lado da ocupação.

Confirmado por grep: `acquiredOn` só aparece no modelo e no repositório de sincronização — zero ocorrências em `operational_pages.dart` (onde vive o formulário de máquina) ou em qualquer ecrã de dashboard como campo de entrada. **Um empresário que preencha os 15 máquinas com nome, categoria, preço/dia e estado nunca vai ver este KPI sair de "Por apurar".**

### Outras perguntas em falta ou incompletas face ao que se promete mostrar

- **Origem/campanha do lead**: o roadmap (`DECISOES_E_ROADMAP_VIVO.md`) já identificou que falta ligar lead → cliente convertido → reserva → recebimentos, e registar motivo de perda/origem. O formulário de Lead hoje só pede Nome e Telemóvel — insuficiente para qualquer análise de funil por canal.
- **`expectedValueCents` da reserva pode ficar `null`** e nunca entra no cálculo de dívida em atraso (`kpis.dart:175-176`) — não é falta de pergunta (o campo "Valor previsto" existe), mas como é opcional, uma reserva sem valor nunca aparece como "a cobrar", o que pode esconder dívida real.
- **Data de última sincronização** não é mostrada em lado nenhum — se o Supabase falhar, o utilizador não sabe que está a ver dados desatualizados (não há campo a perguntar nem ecrã a mostrar).
- **Cliente sem campo país**: telefone/NIF são campos livres sem validação de origem, mas também não há um campo "país" para clientes estrangeiros — qualquer cruzamento futuro por geografia fica impossível.

### O resto do cruzamento está bem defendido

`kpis.dart` (997 linhas, mapeado por completo) trata sistematicamente valores em falta com guard clauses (`== 0 ? null`, `.isEmpty ? null`, `?? 0` em somas) — não encontrámos nenhuma divisão por zero desprotegida nem data mal tratada nesse ficheiro. Os slides do dashboard (síntese, operacional, procura) mostram "Por apurar" com motivo explícito sempre que a origem de dados está vazia. As Tarefas agregam corretamente lacunas conhecidas (dados fiscais em falta, colaboradores por registar, veículos por identificar, máquinas placeholder).

---

## Eixo 3 — O que está partido

**Nota:** durante esta auditoria havia outra sessão a editar `lib/` ao vivo (WIP visível em `git status`: `operations_controller.dart`, `operation_repository.dart`, `operations.dart`, `workforce.dart`, `operational_pages.dart`, `tarefas_service.dart` e testes associados). Essa WIP implementa a decisão de 2026-08-02 de deixar de criar máquinas/veículos placeholder no onboarding. Os achados abaixo foram verificados contra esse estado mais recente.

### Achados 1-21 do `PLANO_DE_TESTES_2026-08-02.md` — estado actual

| # | Achado | Estado |
|---|---|---|
| 1, 4, 5 | Tooling (APK/dart-define, MIUI, emulador) | N/A — não são bugs de código |
| 2 | Cabeçalho do login cortado | **Corrigido** (`3db013b`) — `SafeArea` em `login_screen.dart:68` e `registo_screen.dart:124` |
| 3 | Rotação indevida noutro ecrã | Não reproduzível como estava; causa estrutural (bloqueio global) corrigida em `orientacao_do_contexto.dart` |
| 6 | Sync nunca corria | **Corrigido** — `sync_providers.dart:99` |
| 7 | Rotação no arranque | **Corrigido** — `splash_punho.dart:41` |
| 8 | Onboarding não cria colaboradores/veículos | **Já não é bug** — desenho deliberado (nem máquinas são mais criadas automaticamente); Tarefas avisam explicitamente (`tarefas_service.dart:163-201`) |
| 9, 10 | Faturação do ano passado não vira histórico / painel fica "Por apurar" | **Corrigido** (`091d5d8` + `2710fa4`) — `_distribuirFaturacaoDoAnoPassado`, `operations_controller.dart:332,375-396` |
| 11 | Cartões de cliente não abrem | **Corrigido** (`de11645`) — `operational_pages.dart:1675-1679` |
| 12 | Textos "Ready?"/"tablet" | **Corrigido** (`8b3b5ec`) |
| 13 | Máquinas placeholder enterram as reais | **Deixou de se aplicar** — conceito de placeholder removido do modelo |
| 14 | "Quarta-feira fraca" num domingo | **Não é bug** — recomendação prospectiva legítima |
| 15, 16 | Campainha em tempo real / assert Riverpod | **Corrigidos** (`4dfcb0f`) |
| 17, 17b | Cliente duplicado + ecrã vermelho / aviso invisível | **Corrigidos** (`3db013b`) |
| 18 | Máquina alugada bloqueia semanas seguintes | **Corrigido** — `operations_controller.dart:766-778` |
| 19 | Limite de colaboradores recusa sem avisar | **Corrigido** (`59fb98c`) — passou a autorizar, não bloquear |
| 20 | Ordem das listas (despesas, clientes) sem critério | **Continua a aplicar-se** — nenhum `.sort()`/`orderBy` em `operational_pages.dart` nem `finance_pages.dart` |
| 21 | "em preparação para a v0.0.9" | **Corrigido** (`8b3b5ec`) |

Bónus fora da lista: `5a2d41b` removeu o botão "Repor" de Definições da Empresa, que apagava todos os dados com um toque.

### Achados novos — PARTIDO (existe, mas falha)

**1. Valor de reserva acima de 999 € é gravado como zero, sem aviso.**
`operational_pages.dart:3272-3278` (e réplica em `:3636-3644`), no campo "Valor previsto (€)" da Confirmação de Reserva e da Marcação:
```dart
final cents = ((double.tryParse(expectedValue.text.replaceAll(',', '.')) ?? 0) * 100).round();
```
Isto só troca vírgula por ponto — não remove o separador de milhar. O mesmo ficheiro tem `_euroCents()` (linha 558-566) que trata isto correctamente e é usado no onboarding/Definições. Verificado directamente no código (não apenas por relato do agente): confirmámos que `_euroCents` faz `raw.replaceAll('.', '').replaceAll(',', '.')` quando há vírgula, mas o parsing da reserva não. Um gestor que escreva "1.250,00" (notação PT normal para valores ≥ 1000 €) vê a reserva gravada com `expectedValueCents: null` — sem erro, sem aviso. Só funciona por coincidência para valores abaixo de 1000 €.

**2. Ordem das listas de clientes e despesas continua sem critério** (achado 20, persiste) — confirmado por grep: sem `.sort()` em `operational_pages.dart:1654` (clientes) nem `finance_pages.dart:41` (despesas/recebimentos).

### Achados novos — EM FALTA (nunca foi feito)

**3. Veículo: só é possível criar, nunca editar, ver detalhe ou arquivar.**
`workforce_pages.dart:696-704` — o `ListTile` de cada veículo não tem `onTap` nem `trailing`; `_vehicleDialog()` (linha 715) não aceita um veículo existente; não há `archiveVehicle` chamado em lado nenhum da UI. Uma matrícula errada fica gravada para sempre.

**4. Cliente: não tem campo `archived`, não pode ser eliminado nem arquivado.**
Confirmado directamente no código: `lib/domain/models/operations.dart:116-131` — a classe `Customer` não tem `archived` (ao contrário de `Machine`, `Vehicle`, `Collaborator`) nem sequer `copyWith`. Confirmámos por grep que `archiveCustomer` não existe em lado nenhum de `lib/`. Um cliente duplicado por engano fica na lista para sempre — `ClientsPage` só tem botão de editar, `MachinesPage` tem editar **e** eliminar.

**5. "Valor de compra" da máquina — campo existe no modelo, nunca chega à UI** (ver Eixo 2 — é simultaneamente uma pergunta em falta e a causa directa de um KPI permanentemente por apurar).

### Hipóteses verificadas e descartadas (não são bugs)

- **NIF estrangeiro, telefone internacional, matrícula antiga:** todos os campos são texto livre (`TextField` sem `RegExp`/validator de formato) — aceitam qualquer valor. Não recusam nada.
- **Divisões por zero em `kpis.dart`:** disciplina consistente de guard clauses; nenhuma encontrada sem proteção.
- **`DateTime.parse` sem try/catch:** existe em `operation_repository.dart`, mas só processa datas geradas pela própria app (round-trip ISO), não input de formulário.
- **Botões "em breve"/TODO/onPressed vazio:** nenhum encontrado em `lib/`.

---

## Veredicto

Com um empresário exemplar — todos os campos preenchidos, dados plausíveis — a Punho **entrega o essencial**: tesouraria do mês, cobranças em atraso, pipeline de leads, ocupação de máquinas e recomendação do dia calculam-se correctamente a partir do que foi pedido, com boa disciplina de "Por apurar com motivo" em vez de zeros enganadores. Os 21 achados da campanha de testes de hoje estão, na sua maioria, corrigidos ou já não se aplicam — o trabalho de hoje limpou bastante.

Onde a app o deixa mal é em dois pontos concretos. Primeiro, há uma promessa que **nunca pode ser cumprida**, por muito dedicado que o empresário seja: o retorno das máquinas ("Utilização vs Rentabilidade") depende de um "valor de compra" que nenhum ecrã pergunta, apesar de o modelo já ter o campo pronto — é uma pergunta esquecida a meio do caminho entre o dado e o ecrã. Segundo, há uma perda silenciosa de dinheiro: escrever o valor de uma reserva grande na notação portuguesa normal ("1.250,00 €") grava a reserva sem valor nenhum, sem qualquer aviso — um bug real, não uma limitação conhecida. A isto junta-se uma assimetria de manutenção incómoda mas menor: veículos não se editam depois de criados, e clientes não se apagam nunca — ambas "em falta", não "partidas", mas ambas vão irritar um empresário real ao fim de poucas semanas de uso.
