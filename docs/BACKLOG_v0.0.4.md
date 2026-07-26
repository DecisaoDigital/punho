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

## Deixado de fora do aviso de update global (v0.0.3)

Ver `design/punho_v003_update_global.md`. O aviso global entrou na v0.0.3; estas
quatro coisas ficaram deliberadamente de fora.

### Push de notificações (FCM) — destino v0.1.0, só se justificar

Hoje o único canal é a app perguntar ao Control no arranque, o que cobre todos os
utilizadores que abrem a app. FCM só acrescentaria avisar quem tem a app
**fechada**. O que custa: `firebase_messaging` e projecto Firebase,
`google-services.json` e configuração do Gradle, service account do lado do
Control, código de registo e renovação de token com tabela para o guardar,
tratamento das três situações (foreground, background, terminated) e permissão de
notificações no Android 13+. Grátis no plano Spark para volumes baixos, mas é
mais uma consola, mais um segredo e mais uma dependência de terceiros.

**Só vale a pena quando** houver utilizadores reais que passem dias sem abrir a
app e a demora a actualizar for um problema medido, não suposto.

### Persistir o último check

Hoje cada arranque a frio pergunta de novo. É uma chamada barata a uma Edge
Function, mas guardar a resposta e o instante em `SharedPreferences` evitaria a
chamada em arranques seguidos e permitiria mostrar o aviso **antes** da resposta
chegar (offline incluído). Precisa de decidir a validade da cache.

### UX do banner

Colapsar/expandir, notas de release inline com mais do que uma linha, e um estado
"a descarregar". Hoje é um cartão fixo com título, notas e botão.

### Tratamento fino do update obrigatório

Contagem regressiva antes de bloquear, mensagem a dizer *porquê* é obrigatório, e
localização das mensagens. Hoje bloqueia de imediato com texto fixo — correcto,
mas seco.

## Dívida técnica registada

- Auditoria completa de RLS — a v0.0.3 só faz o smoke de isolamento entre
  empresas.
- Testes do diálogo de máquinas e do diálogo de marcações: hoje são funções de
  topo com muitos controllers, difíceis de montar isoladamente.
- `app_shell.dart` ainda tem a `_ProfileSelector` de demonstração; quando o
  Supabase for o único caminho, sai.
