# Punho — decisões de produto e roadmap vivo

> Documento central de produto. Regista o que foi decidido, o que existe no código e o que falta construir.  
> Atualizar sempre que uma decisão de negócio, UX ou funcionalidade seja fechada.

## 1. Propósito

**Punho — Agarra o comando** é uma aplicação que ensina pequenos empresários a gerir melhor o negócio através do trabalho diário: recolhe dados no momento certo, transforma-os em indicadores claros e recomenda a próxima ação concreta.

O primeiro caso de uso é o aluguer de máquinas. A arquitetura deve permitir adaptar a aplicação a outras atividades sem perder a clareza do primeiro vertical.

O Punho não é contabilidade e não toma decisões sozinho. Mostra o número, explica a causa provável, abre os registos envolvidos e propõe uma ação. A decisão final pertence sempre ao gestor.

`D:\gestao_fluxo` pode ser consultado como referência, mas não é uma dependência nem deve ser alterado para construir o Punho.

## 2. Identidade e princípios fechados

- Nome: **Punho**.
- Assinatura: **Agarra o comando**.
- Identidade visual: azul-marinho escuro, branco e laranja/dourado para ação.
- Conceito de marca: uma mão a agarrar/elevar uma linha de gráfico económico; não um punho agressivo.
- Inspiração de interface: Point of Rental, Quipli e EZRentOut, sem copiar a identidade de nenhum.
- O cliente vê apenas Punho. A ligação ao WashInvoice Control é interna e invisível.
- O empresário usa sempre uma visão de trabalho em horizontal: Windows, tablet e telemóvel de gestor em landscape. A experiência de colaborador privilegia telemóvel/tablet Android e ações rápidas.
- A barra lateral do gestor deve ter ícones e grupos claros: Gestão, Funcionários, Máquinas, Veículos quando existem, Clientes e Marcações/Reservas.
- Poucos toques, linguagem portuguesa simples e cada pedido de dados deve explicar a razão.
- Refeições são apenas uma categoria de despesa; não se pergunta o contexto da refeição.
- Uma promoção, cobrança ou campanha é uma sugestão. O Punho nunca a executa automaticamente.

## 3. O que já existe no código (estado local/piloto)

### 3.1 Estrutura operacional

- [x] Onboarding guiado com nome do empresário/responsável, empresa, forma jurídica, NIF (obrigatório, 9 dígitos, desde 2 de agosto de 2026 — ver secção 3.6), contacto, morada, equipa, frota, máquinas e referências financeiras.
- [x] Os dados que o utilizador não sabe no momento ficam em **Dados por completar**, em vez de bloquear o início.
- [x] Cliente com nome, telemóvel, NIF, email, morada, código-postal, localidade e notas. Não existe campo país.
- [x] Proteção local contra cliente duplicado por telemóvel ou NIF.
- [x] Leads separadas de clientes e conversão de lead em cliente.
- [x] Máquinas com referência, categoria, estado, preço diário, notas e fotografias locais.
- [x] Estados de máquina apresentados em português, com alteração direta; uma máquina com reserva ativa não pode ser marcada como disponível.
- [x] Ciclo base reserva-máquina: reserva confirmada passa a máquina a reservada, aluguer em curso passa-a a alugada e conclusão/cancelamento devolve-a ao estado operacional adequado. Manutenção e Parada não são anuladas automaticamente.
- [x] Declarar 15 máquinas não significa 15 disponíveis: a disponibilidade fica “Por apurar” até as máquinas serem identificadas.
- [x] Reservas com cliente, máquinas, período, valor previsto, estado e colaborador associado.
- [x] Reserva mínima de meio dia, com opções explícitas de manhã, tarde, dia inteiro ou vários dias seguidos.
- [x] Agenda de reservas centrada na máquina: lista horizontal de máquinas no topo, escolha de blocos consecutivos de manhã/tarde na vista semanal, confirmação posterior de cliente e gravação. A vista mensal mostra a ocupação da máquina e permite abrir a semana escolhida. Cada reserva apresenta a máquina e o cliente e permite atualizar o seu estado.
- [x] Despesas, recebimentos, custos de colaboradores e custos de frota iniciais.
- [x] Colaborador em modo local pode registar leads, reservas, recebimentos e despesas/faturas, sem acesso aos custos globais. Ao criar uma reserva pela agenda, a autoria fica automaticamente atribuída ao colaborador autenticado e não pode ser trocada.

### 3.2 Gestão diária e orientação

- [x] Dashboard com dinheiro recebido, despesas, pendentes, reservas, máquinas e recomendações determinísticas.
- [x] Frase da Semana e Objetivo da Semana.
- [x] Recomendações como cobrar atrasos e reforçar leads, ou sugerir promoção em dia fraco quando existe capacidade.
- [x] Alertas de máquinas declaradas mas ainda não identificadas, colaboradores incompletos e frota sem viaturas registadas.
- [x] Histórico mensal manual para os últimos cinco anos e ano atual: recebimentos, despesas pagas, publicidade, leads, conversões e manutenção.
- [x] Comparação homóloga mensal no dashboard quando existe o mesmo mês do ano anterior. Sem esse mês, o Punho pede o histórico em vez de inventar uma comparação.

### 3.3 Base técnica já iniciada

- [x] Persistência local no dispositivo e testes automatizados.
- [x] Autenticação Supabase inicial, migrations e RLS inicial documentadas.
- [x] Estrutura inicial de sincronização/outbox, ainda não equivalente a sincronização real por entidade e perfil. **Verificada a correr de ponta a ponta em 2 de agosto de 2026** (envio e recepção, campainha em tempo real nos dois sentidos) depois de corrigido um bug que a mantinha sempre parada desde que existe — ver secção 3.6. Falta ainda a granularidade por entidade/perfil e a resolução de conflitos.
- [x] Estrutura de atualizações remotas pelo WashInvoice Control.
- [x] Cliente de licenciamento inicial ligado ao padrão multi-app do Control, com trial técnico. Ver `LICENCIAMENTO.md`.

## 3.5 Decisoes e progressos — 27 de julho de 2026 (v0.0.5 + arranque v0.0.6)

**v0.0.5 (Dashboard alavancas) — em curso na branch `feat/v005-dashboard-alavancas`, 338 testes verdes:**

- [x] Dashboard reformulado: carrossel de **5 slides landscape × 4 KPIs**, cada slide responde a UMA pergunta de gestão (Dinheiro / Pipeline / Rentabilidade / Custos / Semana).
- [x] Sidebar 88 dp com labels e novo destino **Tarefas**.
- [x] Slide 1 Dinheiro com hero "Recebido este mês" (sparkline + setas ‹ › de mês), "Por receber" com CTA "Cobrar", "Pago", "Recomendação do dia" (bordo por gravidade verde/laranja/vermelho).
- [x] `TodasMetricasPage` reescrita a consumir os mesmos KPIs puros, sem duplicar contas.
- [x] Máquinas: chip de estado clicável como único controlo, "Parada" removida do menu (auto-Disponível se não em manutenção); botão **eliminar** (caixote) com confirmação + undo 6 s, só gestor.
- [x] `_vehicleDialog` corrigido (título, validação, `barrierDismissible: false`, autofocus + Cancelar).
- [x] **Backend:** trigger `AFTER INSERT ON punho_pedidos_acesso` chama Edge `enviar-push` — o gestor recebe push quando um novo empresário faz signUp. Task #196 fechada, verificada em produção.

**v0.0.5 — continuação em curso (sprint 3+4 fundidas):**

- [ ] Placeholders de máquinas a partir do onboarding (declara 20 → cria 20 linhas editáveis com flag `placeholder`).
- [ ] `_machineDialog` largo em duas colunas landscape com foto maior.
- [ ] `_collaboratorDialog` e `_vehicleDialog` sobem acima do teclado em portrait (`insetPadding`).
- [ ] `BookingsPage` limpa: título "Reservas", botão "Reservar", `DropdownButton` de máquina, calendário sem scroll (7 colunas + Manhã/Tarde visíveis de relance).
- [ ] Onboarding: sub-texto do passo 1 removido, revisão dos 12 (só fica o que ajuda a preencher).
- [ ] Funcionários finalmente **editáveis** + botão eliminar (mesmo padrão das máquinas) + nova coluna "vendas do mês por colaborador".

**v0.0.6 — sprint 1 preparada (`feat/v006-boas-vindas`):**

- [ ] **Ecrãs de contexto no onboarding:** `MaisDadosScreen` (se escolheu preencher tudo) + `BoasVindasScreen` sempre no fim, ainda em portrait, com CTA "roda o tablet — a Punho passa a horizontal".
- [ ] **Ecrã de conta** (tocar no avatar da sidebar) com identidade, chip `SESSÃO ACTIVA` / `MODO DEMONSTRAÇÃO`, dados da empresa editáveis inline (widget `EmpresaDadosForm` extraído da `CompanySettingsPage`), botão **Convidar por WhatsApp** (usa `mensagemConvite` + `wa.me`) e **Terminar sessão** com confirmação.
- [ ] **Modelo contratual do funcionário:** enum `EmploymentType { recibosVerdes, contrato }` no `Collaborator`. Diálogo com `SegmentedButton` no topo; campos condicionais (recibos verdes → NIF+IBAN+morada; contrato → NISS+estado civil+dependentes+IBAN+morada). Bloco read-only "Estimativa" com líquido do trabalhador, TSU patronal 23,75% e **Custo total para a empresa** destacado.
- [ ] **KPI "Custo real com pessoal"** no slide Custos: bruto pago + TSU patronal + custo real. Fica explícita a diferença entre o que o trabalhador vê e o que a empresa desembolsa.

**v0.0.6 — sprint 2 preparada (self-service do colaborador):**

- [ ] Colaborador recebe convite WhatsApp, entra na Punho, vê no shell portrait um card âmbar *"A tua ficha está incompleta"* e preenche o `FichaFiscalColaboradorForm` (mesmo widget que o gestor usa, reutilizado). Preenche NISS, IBAN, morada, data nasc.
- [ ] Nova RPC Supabase `punho_atualizar_ficha_colaborador` (security definer, filtra pelo `auth.uid()`), só deixa mudar campos permitidos (não custo, não cargo).
- [ ] Trigger `AFTER UPDATE` dispara push ao gestor **só na transição** `NISS null → preenchido` (evita spam).
- [ ] `CollaboratorsPage`: chip verde `FICHA COMPLETA` vs âmbar `AGUARDA COLABORADOR` (mais accionável que "NISS em falta").

Notas de arquitectura:

- Diálogos com muitos campos (`_machineDialog`, `_collaboratorDialog`, `_vehicleDialog`) usam `Dialog` largo em landscape + `insetPadding.bottom = viewInsets.bottom + 16` em portrait + cabeçalho/rodapé fixos com `Expanded(SingleChildScrollView)` no meio.
- Estimativas fiscais (`estimarSalarial`) são funções puras que **nunca guardam** o resultado — recalculam no build. Aviso obrigatório: *"Estimativa. Confirma com o teu contabilista antes de folhas oficiais."*
- Regimes especiais (TSU reduzida para pensionistas, isenção IRS de jovens, subsídios de férias/Natal) explicitamente fora — sprints dedicadas quando o Cesar decidir.

## 3.6 Decisões e progressos — 2 de agosto de 2026 (campanha de testes no telemóvel)

Primeira campanha de testes a sério num aparelho real (Redmi Note 10 Pro), com
onboarding completo simulando um empresário e dados semeados no servidor.
Achados e checklist completos em `docs/PLANO_DE_TESTES_2026-08-02.md`.

**Corrigido e commitado** (`4dfcb0f`, `5dcc5c5`):

- [x] A sincronização entre dispositivos **nunca tinha corrido** desde que
  existe: `SyncController._vivo` era posto a `false` no `onDispose` da
  primeira reconstrução do provider e nunca voltava a `true`. `sincronizar()`
  saía sempre na primeira linha, em silêncio — 15 máquinas do onboarding
  ficaram presas na fila local sem subir. Corrigido; verificado no aparelho
  com `enviadas=15 recebidas=36`.
- [x] A campainha em tempo real **nunca tinha tocado**: `payload: const {}`
  rebentava com "Cannot modify unmodifiable map" a cada envio, excepção que
  nascia dentro do future e escapava ao `try/catch`. Corrigida; verificada nos
  dois sentidos (receber e enviar) no aparelho.
- [x] Assert do Riverpod no arranque da sync (`ref` usado numa microtarefa
  depois de a dependência mudar) — corrigido.
- [x] Rotação indevida no arranque: o splash não declarava orientação, por
  isso durante 1,6 s valia o sensor. Corrigido em `splash_punho.dart`.

**Corrigido, por commitar** (verificado no Redmi, `flutter analyze` limpo,
535 testes a passar):

- [x] Ecrã vermelho ao gravar cliente (`TextEditingController` usado depois
  de `dispose`, mesmo padrão que já tinha rebentado nas máquinas) — resolvido
  com `_FormularioDeCliente`, `StatefulWidget` dono dos seus controladores.
  **Os diálogos de lead, reserva e marcação continuam com o padrão antigo** —
  mesma bomba por rebentar, não convertidos por serem formulários grandes e a
  conversão sem testes de UI ser arriscada.
- [x] Recusas invisíveis: `DialogoDeFormulario` ganhou parâmetro `aviso` que
  mostra a mensagem fora do scroll, por cima dos botões — antes iam em
  `SnackBar`, que em telemóvel deitado com teclado aberto nasce por baixo
  dele. Aplicado ao diálogo de cliente e ao de colaborador.
- [x] Cabeçalho do login e do registo cortado pela barra de estado —
  `SafeArea`.
- [x] Copy: «Ready?» → «Vamos a isto?»; «o teu tablet vai rodar» → «o teu
  ecrã vai rodar»; «em preparação para a v0.0.9» → «em preparação» (a app já
  vai na v0.1.4).
- [x] `tesourariaDoMes` passa a usar `historicalMonths` quando preenchido à
  mão (antes ignorava-o mesmo com dados).

**Decisão fechada — colaboradores sem ficha placeholder:** o onboarding
declara equipa (número de colaboradores) mas não cria fichas. Decidiu-se
**não** materializar colaboradores placeholder como faz com as máquinas,
porque uma ficha de colaborador carrega NIF/NISS e uma linha em branco a
fingir de pessoa é risco fiscal. Em vez disso, tarefa nova «N colaboradores
por registar» aponta a pendência sem fabricar dados.

**Decisão fechada — sem distribuir facturação anual por meses:** o total
anual declarado no onboarding (`revenueLastYearCents`) não é dividido por 12
para preencher `historicalMonths`, para não fabricar sazonalidade falsa. O
histórico mensal só existe quando alguém o preenche a sério, mês a mês.

**Decisão fechada — reserva bloqueia a data, não a máquina:** uma máquina
alugada só bloqueia a data/período efectivamente ocupado; deixa de recusar
reservas em **todas** as semanas seguintes enquanto o aluguer actual estiver
em curso (achado 18 do plano de testes). A implementar por outro agente.

**Decisão fechada — o limite de colaboradores vem do servidor, não do
onboarding:** `punho_subscricoes.limite_colaboradores_ativos`, autorizado
pelo Cesar no Control, manda sempre que se consegue ler; o número que o
gestor declarou no onboarding passa a ser só o valor de recurso quando o
servidor não responde (sem rede, modo demonstração). Exceder o limite não
impede o cadastro do colaborador — impede-o de aceder sem autorização
expressa do Cesar, pelo mesmo circuito de `punho_pedidos_acesso`. Implementado
em `3c7fe1c` (leitura do servidor,
`lib/features/auth/subscricao_providers.dart` e
`lib/features/auth/data/subscricao_service.dart`) e `59fb98c` (deixa de
recusar o cadastro, só avisa,
`lib/features/workforce/presentation/workforce_pages.dart`). Falta só a
peça do lado do Control: a RPC `punho_definir_limite`
(`supabase/migrations/20260802_punho_definir_limite.sql`, `4bbc60e`) está
pronta mas confirmada como **não aplicada em produção**.

**Decisão fechada — NIF da empresa passa a obrigatório no onboarding
(Opção B):** o passo "Forma jurídica e NIF da empresa" deixou de aceitar
avançar com o campo vazio ou com menos de 9 dígitos. Resolve um bug real em
produção: a Edge Function `sincronizar-empresa-punho` sempre validou
`nif.length < 9` e devolvia 400 rejeitando o payload **inteiro** — qualquer
empresa que terminasse o onboarding sem NIF ficava com
`punho_empresas.dados={}` para sempre, sem retry nenhum a corrigir isso (o
`EmpresaSyncController` insiste, mas reenvia o mesmo payload sem NIF e volta
a levar 400). Não foi mexido na Edge Function nem na validação de dígito de
controlo — só na forma (9 dígitos), igual ao que a EF já exige. Implementado
em `lib/features/operations/presentation/operational_pages.dart` (validação
inline + texto de ajuda) e `lib/core/format/campos.dart` (`nifValido`). Uma
empresa de teste já presa em produção (Lavandaria Mare Alta,
`punho_empresas.dados={}`) **não é corrigida retroactivamente** por esta
mudança — só resincroniza quando alguém preencher o NIF real em Definições
da Empresa no aparelho, que continua a aceitar o NIF em branco por ser dado
legado, fora do âmbito desta correcção.

## 3.4 Decisoes recentes: faturas e fotografias (26 de julho de 2026)

- [x] Uma despesa pode ser criada a partir de uma fotografia da fatura. O QR da AT e lido no dispositivo para sugerir data, total, NIF do fornecedor, numero do documento e ATCUD; o utilizador confirma os valores antes de guardar.
- [x] O comprovativo da despesa e enviado para o arquivo remoto privado do Punho, associado a empresa e a despesa. A autoria e registada para auditoria, mas o ficheiro nao pertence ao dispositivo nem a conta individual de quem o captou.
- [x] Acesso a comprovativos de despesas: quem o enviou e os gestores da mesma empresa.
- [x] Fotografias de maquinas podem ser enviadas por qualquer membro e ficam disponiveis a todos os membros ativos da mesma empresa. A fotografia da maquina e um recurso da empresa.
- [ ] Para ativar este comportamento no ambiente real, aplicar a migration `20260726_punho_documentos_privados.sql` no Supabase e configurar `SUPABASE_URL` e `SUPABASE_ANON_KEY` na compilacao da app.

Decisao de arquitetura: os ficheiros binarios vivem no **Supabase Storage privado**, que e o arquivo remoto da aplicacao; a base de dados guarda a empresa, a autoria, a associacao a despesa e o caminho do ficheiro. Nao se guardam fotografias como dados binarios dentro das tabelas relacionais.

## 4. Dados que o Punho precisa de aprender

### 4.1 Primeiro uso sem cansar o empresário

O onboarding recolhe o essencial, mas nunca deve exigir que o empresário saiba tudo no primeiro dia. Valores desconhecidos criam uma tarefa para completar mais tarde.

Dados de empresa:

- nome do responsável/empresário;
- nome, forma jurídica, NIF, contacto e morada da empresa;
- colaboradores, viaturas e máquinas;
- faturação do ano anterior e acumulada do ano atual;
- manutenção do ano anterior e custos fixos mensais.

Para comparações homólogas, os totais anuais não bastam. O histórico mensal permite comparar, por exemplo, maio deste ano com maio do ano passado.

### 4.2 Histórico mensal

Cada mês histórico pode receber, por etapas:

- recebimentos efetivos;
- despesas efetivamente pagas;
- investimento em publicidade;
- leads recebidas;
- leads convertidas em reserva;
- manutenção paga.

Os valores podem ser aproximados e são marcados implicitamente como registo manual. Mais tarde, WashInvoice e integrações devem importar movimentos reais e substituir/reconciliar este histórico, sem apagar o rasto da origem.

## 5. Funil comercial e publicidade — decisão de produto

O Punho mede a cadeia completa:

```text
Investimento em publicidade → Leads → Contacto → Proposta → Reserva confirmada → Dinheiro recebido → Recompra
```

Uma lead só conta como convertida quando gera a primeira **reserva confirmada**. Criar apenas uma ficha de cliente não é conversão.

Indicadores pretendidos por período, origem e colaborador:

- leads recebidas e leads válidas;
- tempo até primeiro contacto;
- taxa de contacto e taxa de conversão em reserva;
- custo por lead e custo por cliente adquirido;
- investimento em publicidade, receita atribuída e retorno da publicidade;
- receita recebida, não apenas valor proposto;
- valor médio por cliente convertido.

Exemplo pedagógico:

> 40 € em publicidade geraram 200 leads, 100 reservas confirmadas e 4 000 € em receita atribuída. Existem duas alavancas: aumentar investimento se houver capacidade e melhorar a taxa de conversão.

Antes de recomendar aumentar publicidade, o Punho confirma disponibilidade de máquinas, capacidade de equipa e qualidade das leads. Não aumenta orçamentos sozinho.

## 6. Clientes, retenção e contacto

O cliente pertence sempre à empresa e é partilhado pelos colaboradores autorizados; nenhum colaborador é dono da base de clientes.

O Punho deve identificar clientes que concluíram uma reserva e não voltaram, começando com limiares configuráveis de:

- mais de 18 dias sem regressar;
- mais de 40 dias sem regressar — subconjunto prioritário dos anteriores.

Ao carregar num indicador, abre uma lista acionável, não apenas um gráfico. Cada linha deverá mostrar:

- cliente e contacto;
- última reserva concluída e dias sem regressar;
- total já recebido desse cliente;
- origem da primeira lead, quando conhecida;
- botão de contacto e resultado do contacto.

Motivos de não retorno a registar: sem necessidade atual, preço, concorrência, indisponibilidade, insatisfação, falta de resposta e outro. Os limiares devem mais tarde adaptar-se ao ciclo normal de aluguer de cada negócio.

## 7. Reclamações, máquinas e qualidade

O Punho terá registo estruturado de reclamações ligado, quando possível, a cliente, reserva e máquina. Uma ocorrência deve ter categoria, data, descrição curta, estado de resolução e responsável.

Categorias iniciais:

- máquina avariada;
- máquina sem qualidade/condição esperada;
- máquina indisponível;
- cliente considera caro;
- outro.

O dashboard mostrará o top 5 de reclamações e cada categoria abrirá a lista real de ocorrências. Em “Máquinas avariadas”, deverá ainda destacar máquinas repetidamente problemáticas, reservas potencialmente perdidas e a próxima ação de manutenção/decisão.

## 8. Comunicações, WhatsApp e Punho IA

### 8.1 Primeira fase de WhatsApp

- Guardar telefone da empresa e do cliente.
- A partir da reserva, preparar mensagens editáveis de confirmação, pedido de confirmação, levantamento/devolução e cobrança.
- Abrir o WhatsApp para o gestor confirmar manualmente o envio.
- Guardar internamente a intenção/ação de comunicação quando existir esta funcionalidade.

Esta fase não requer automação nem API WhatsApp paga.

### 8.2 Punho IA Pro (futuro)

O cliente escreve no WhatsApp da empresa e o Punho IA interpreta o pedido, verifica disponibilidade, faz perguntas em falta e cria uma pré-reserva. Casos de baixa confiança, exceções de preço, indisponibilidade ou conflito exigem validação humana.

Evolução segura:

1. IA sugere resposta ao empresário.
2. IA responde a perguntas simples e consulta disponibilidade.
3. IA cria pré-reservas para validação.
4. Automação limitada apenas em regras aprovadas.

Para isto será necessária a WhatsApp Business Platform/API, backend seguro, consentimento/templates quando aplicável e custos de utilização da IA/plataforma. A IA nunca altera reservas, preços ou pagamentos sem regras e autorização explícitas.

## 9. Aprendizagem e autoridade

- Frase da Semana e Objetivo da Semana fazem parte da proposta Pro/educativa.
- Citações curtas e atribuídas só são usadas em contexto real de aprendizagem; ideias devem ser apresentadas como “Ideia de [autor]” quando não forem citação literal verificada.
- Ao fim de cerca de um ano de utilização, o Punho deve propor o **Balanço de Comando**: ajudar o empresário a formular a filosofia, promessa e padrões da empresa.
- O Punho IA Pro poderá transformar dados reais em objetivos semanais, cenários e plano de 90 dias. As regras determinísticas continuam a existir como base e alternativa.

## 10. Multiempresa, colaboradores e WashInvoice Control

- Uma empresa tem gestor/principal e colaboradores ativos limitados pelo plano contratado.
- O Control atribui, aumenta, reduz ou suspende a capacidade. Reduzir o limite nunca desativa colaboradores silenciosamente; exige uma escolha explícita.
- Modelo comercial previsto: uma conta principal e pacotes de colaboradores (por exemplo, até três), com cobrança mensal.
- O colaborador não vê custos, margens, lucro/prejuízo nem configuração comercial; vê apenas o necessário para registar trabalho.
- A sincronização final será granular: cada colaborador envia apenas as entidades permitidas; o gestor vê a informação da empresa.
- O Punho deve comunicar tecnicamente com o Control para licença, limites, atualizações e diagnóstico, mas nunca revelar essa marca ao cliente.

## 11. O que ainda não está implementado

### Decisões registadas na conversa de 25 de julho de 2026

- **Planeado — reativar máquina:** uma máquina marcada como suspensa/inativa deve poder voltar a ativa através de uma ação explícita na ficha da máquina. A reativação preserva o histórico e não cria uma nova máquina.
- **Planeado — Tarefas por fazer:** a barra lateral do gestor terá uma entrada **Tarefas por fazer**. Esta vista reunirá os dados, campos e decisões ainda em falta — por adiamento, preguiça ou informação ainda desconhecida — e indicará a origem de cada pendência e o caminho para a completar.
- **Decisão fechada — dados incompletos não bloqueiam:** quando o gestor não tem um dado concreto, o Punho deve permitir continuar e converter essa lacuna numa tarefa por fazer; não deve forçar o preenchimento nem perder a pendência.

### Prioridade 1 — confiança nos dados

- [ ] Criar ações dedicadas de levantamento e devolução, com checklist/fotografias/assinatura quando forem necessárias; a transição de estados base já é automática.
- [ ] Sincronização real multi-dispositivo por entidade, com resolução de conflitos e outbox persistente. O motor de base já corre e foi verificado no aparelho a 2 de agosto de 2026 (secção 3.6); falta a granularidade por entidade/perfil e a resolução de conflitos.
- [ ] Autenticação e perfis reais de colaborador aplicados a todas as consultas e ecrãs.
- [ ] RLS de produção, Storage privado e sincronização de fotografias/documentos.
- [ ] Integração efetiva de autorização, planos e vagas pelo WashInvoice Control.

### Prioridade 2 — operação comercial

- [ ] Ligar lead ao cliente convertido, reserva e recebimentos para atribuição real de receita.
- [ ] Registar data de conversão, proposta, motivo de perda e origem/campanha da lead.
- [ ] Painel clicável de funil, publicidade, retorno de clientes e listas acionáveis.
- [ ] WhatsApp manual com mensagens preparadas e histórico de contacto.
- [ ] Registo de reclamações ligado a máquina, cliente e reserva.

### Prioridade 3 — gestão avançada

- [ ] Cálculo de margem por reserva, máquina, cliente, origem de lead e colaborador, sem confundir resultado atribuível com lucro final.
- [ ] Custos fixos recorrentes, previsão de tesouraria e cenários.
- [ ] Importação/reconciliação de histórico e movimentos através do WashInvoice.
- [ ] IA Pro com backend, segurança, limites de custo e validação humana.

## 12. Regra de manutenção deste documento

Quando surgir uma decisão numa conversa, atualizar este ficheiro antes ou juntamente com a implementação. Em cada decisão assinalar uma destas situações:

- **Decisão fechada** — não deve ser reinterpretada sem nova decisão explícita.
- **Implementado localmente** — existe no dispositivo, mas ainda não está sincronizado/validado para piloto real.
- **Planeado** — faz parte do produto, mas ainda não está no código.

Os documentos técnicos específicos continuam válidos: `CHECKLIST_DE_IMPLEMENTACAO.md`, `ESTADO_ATUAL_DA_APP.md`, `LICENCIAMENTO.md`, `SEGURANCA_E_RLS.md` e os guias de Supabase/distribuição.
