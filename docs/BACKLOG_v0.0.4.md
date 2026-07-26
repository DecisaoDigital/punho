# Backlog v0.0.4

Recolhido durante o bug hunt da v0.0.3. **Nada disto foi implementado** — a
sprint de estabilização não acrescenta features.

## Lacunas de funcionalidade encontradas

### Editar cliente
`ClientsPage` só cria. Não há caminho para corrigir um telemóvel mal escrito ou
acrescentar o NIF depois. As máquinas já têm edição; os clientes não. Era o
ponto 3 do plano de fluxos ("Clientes — criar, **editar**") e não existe.

### Arquivar / apagar cliente
Não há forma de tirar um cliente da lista. Com o tempo a lista só cresce.

### Identidade do colaborador entre Supabase e repositório local
O `AcessoGate` passa o `id` da conta autenticada à `CollaboratorShell`, e é esse
o valor que fica em `collaboratorResponsibleId` nas leads e marcações. Mas os
`Collaborator` do repositório local têm ids próprios (`collab-a`, ...). Os dois
mundos não estão ligados: "A minha atividade" de um colaborador real não cruza
com a ficha de colaborador da empresa. Precisa de decisão de modelo.

### Limpar a diária de uma máquina
`Machine.copyWith` usa `?? this.dailyRateCents`, portanto apagar o campo não o
apaga. Resolver implica um `copyWith` com sentinela ou campos `Optional`.

### Traduzir os enums à vista
Categoria de despesa, método de pagamento, estado da lead e estado da marcação
aparecem em inglês (`other`, `transfer`, `newLead`, `confirmed`). Já existe
`machineStatusLabel()`; falta o equivalente para os outros quatro.

### Filtro de período no financeiro
`FinanceListPage` mostra "Este mês: X" por cima de uma lista sem filtro. Ou a
lista passa a respeitar o período, ou passa a haver um selector de período.

### Guarda de reentrância nos diálogos
Vários `onPressed` fazem `Navigator.pop` sem impedir o segundo toque. Um padrão
partilhado (flag `_ocupado`, ou um `FilledButton` que se desactiva ao primeiro
toque) resolvia de uma vez em todos.

## Dívida técnica registada

- Auditoria completa de RLS — a v0.0.3 só faz o smoke de isolamento entre
  empresas.
- Testes do diálogo de máquinas e do diálogo de marcações: hoje são funções de
  topo com muitos controllers, difíceis de montar isoladamente.
- `app_shell.dart` ainda tem a `_ProfileSelector` de demonstração; quando o
  Supabase for o único caminho, sai.
