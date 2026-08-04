# Portal do contabilista

Estado — 4 de Agosto de 2026:

- Migração `supabase/migrations/20260804_punho_contabilista.sql` — **aplicada**
  a `oefqbkhioncakojipqyx`. Cinco tabelas com RLS, cinco funções, dez rubricas
  no catálogo.
- Edge Function `supabase/functions/portal-contabilista/` — **publicada**,
  versão 1, `verify_jwt: false` confirmado na API de gestão.
- Percurso completo exercido em produção contra um convite descartável, e os
  dados de teste apagados no fim. O que se verificou está em «O que já se
  provou», no fim deste documento.
- Lado Dart — **feito**. `lib/features/contabilista/`, com aba própria em
  **Empresa → Histórico**, as lacunas a virarem tarefas e a criação do convite
  a mostrar o link uma vez só. 803 testes verdes, `flutter analyze` limpo.

## O problema

Uma empresa que instala o Punho hoje começa sem passado. O painel calcula
variação homóloga — `TesourariaMes.recebidoMesHomologoCents`,
`lib/core/operations/kpis.dart:62` — contra um ano que não existe, e fica cego
durante doze meses. São exactamente os doze meses em que o empresário está a
decidir se a app vale alguma coisa.

Quem tem esse passado escrito não é o gestor. É o contabilista.

Há um segundo buraco, mais silencioso. A forma jurídica o Punho sabe-a — é
perguntada no arranque da app e vive em `FichaDaEmpresa.formaJuridica`. O que
ele não sabe é o degrau a seguir: `regimeDaFormaJuridica()` manda **todos** os
ENI para `eniSimplificado` e admite porquê em comentário
(`lib/core/finance/regime_fiscal.dart:47`) — a app não pergunta se o empresário
optou por contabilidade organizada. Um ENI organizado é lido ao contrário o ano
inteiro: despesas reais tratadas como custo presumido, e ninguém dá por isso. O
contabilista responde a essa pergunta em cinco segundos.

Por isso o catálogo **não** pergunta a forma jurídica. Perguntá-la outra vez
criava duas verdades para o mesmo campo, e a errada seria a que chegasse
depois.

## O que o contabilista é aqui

**Uma fonte de dados, não um utilizador da app.** Não vê o painel, não vê
clientes, não vê o que o Punho faz. Vê uma grelha de meses e responde.

Isso decide tudo o resto:

- **Não há app para ele.** É externo, está ao computador, e instalar um APK
  para preencher campos é atrito que faz o pedido morrer. Um link com token,
  aberto no browser.
- **Não tem conta.** Não existe em `auth.users`, não consome licença, não conta
  para o limite de colaboradores. O token é a identidade toda.
- **Não fala com a base.** Escreve através de uma Edge Function que valida o
  token e usa `service_role`. Nenhuma tabela deste desenho tem policy para
  `anon` — o portal não é um cliente do Supabase, é consumidor de uma função.

## A hierarquia dos dados

Nem tudo o que chega vale o mesmo, e o desenho tem de saber disso:

1. **Discriminado por mês** — o que se quer. É o único que dá comparação
   homóloga e sazonalidade.
2. **Total do ano** — "faturei 12 000 € em 2025". Não dá comparação nenhuma,
   mas é muito melhor do que o silêncio, e há gestores que só têm isto.
3. **Nada.**

O total anual grava-se **como anual** (coluna `ano` em
`punho_respostas_contabilista`), nunca como doze linhas mensais de 1 000 €.
Escrever a média nos doze meses destrói exactamente o que se foi buscar ao
contabilista — a sazonalidade — e, pior, fica indistinguível de doze meses
medidos a sério. A partir daí o painel compara Agosto contra um Agosto que
ninguém viu, e não há como voltar atrás.

A repartição acontece na **leitura**, em `punho_serie_mensal_contabilista()`,
que devolve cada mês com a sua proveniência: `declarado` ou `repartido`. O
painel pode mostrar a linha e continuar a saber o que é medição e o que é
estimativa.

E reparte melhor do que ÷12:

- **Desconta o que já se sabe.** Quem declarou Janeiro e Fevereiro e deu o total
  do ano fica com dez meses estimados sobre o *remanescente*, não com doze
  médias que contradizem os dois meses reais.
- **Fecha ao cêntimo.** O resto da divisão inteira vai todo para o último mês, e
  a série soma exactamente o total que o contabilista escreveu. (O cast a
  `bigint` na CTE `sobra` é o que garante isto — `sum()` sobre `bigint` devolve
  `numeric` e a divisão vinha arredondada para cima, a fabricar cêntimos.)
- **Respeita a janela.** No ano corrente o total pedido vai até ao mês passado;
  repartir por doze meses num ano que vai em Agosto encolhia cada mês a dois
  terços do que vale.
- **Não inventa negativos.** Se os meses declarados já somam mais do que o total
  anual, isso é um conflito, não uma estimativa: devolve-se só o declarado e
  deixa-se o conflito à vista.

Quais rubricas aceitam total anual está no catálogo, em `aceita_anual`. Um
trigger recusa um total anual numa rubrica que não o preveja.

## As três regras

### 1. Em branco não é zero

"Não sei quanto faturou em Março de 2022" e "faturou zero em Março de 2022" são
respostas diferentes, e o Punho decide diferente com cada uma. Em branco é a
**ausência de linha** em `punho_respostas_contabilista`; zero é uma linha com
`valor_centavos = 0`. A constraint `punho_resposta_tem_valor` impede a linha
sem valor — não se grava "não sei" de forma cara.

### 2. Nada é definitivo

O contabilista volta ao link e corrige o que escreveu mal. Isso não é uma
excepção do sistema, é metade do trabalho de contabilidade. `submetido_em`
marca "acabei", não "fechei": o link continua a abrir e a aceitar correcções
até `expira_em`.

Cada correcção deixa rasto em `punho_alteracoes_contabilista` — valor antes,
valor depois, quem, quando. Um valor corrigido três meses depois de entrar já
mudou o que o painel disse ao gestor nesse intervalo; sem o rasto não há como
explicar porque é que o número de Maio mudou sozinho. Reescrever o mesmo valor
não conta como correcção: o formulário devolve a grelha inteira a cada
submissão e o histórico encheria-se de linhas mudas.

### 3. O que fica por responder é do gestor — mas só no fim

`punho_lacunas_contabilista()` devolve o que ficou em branco. Duas decisões
dentro dela:

**Agregada.** Cinco rubricas mensais em sessenta meses são trezentas células.
Trezentas tarefas não são uma lista, são um muro. A função devolve uma linha
por rubrica e o Punho faz disso uma tarefa só. Numa rubrica única `em_falta` é
1 e os meses vêm nulos.

**Com dois níveis de gravidade**, que caem certos nas severidades que
`SeveridadeTarefa` já tem:

- `em_falta` — meses sem cobertura nenhuma. Severidade `aCompletar`:
  *"Faltam 14 meses de faturação entre 2021 e 2023."*
- `so_anual` — meses que só o total do ano cobre. Não é um buraco, é um número
  de pior qualidade. Severidade `sugestao`: *"2023 só tem o total do ano.
  Discrimine por mês e passa a haver comparação homóloga."*

**Só depois de ele acabar.** As lacunas só contam quando o convite tem
`submetido_em` ou já expirou. Antes disso o silêncio não é uma lacuna, é
alguém a meio do trabalho — e empurrar o gestor para preencher o que o
contabilista ainda está a escrever é a via mais curta para dois números
diferentes do mesmo mês.

**Só o que desbloqueia algo.** Apenas as rubricas marcadas `essencial` viram
tarefa. Pedir ao gestor o que não muda nada no que ele vê gasta a única
atenção que ele tem.

## O catálogo

Vive em `punho_rubricas_contabilista`, não em Dart, porque tem dois leitores: a
app e a Edge Function que serve o formulário. Duas cópias divergiriam à segunda
rubrica acrescentada, e a que divergisse seria a que o contabilista vê.

**Mensais** — pedidas para cada mês da janela, com total anual em alternativa
para quem não souber os meses:

| chave | rótulo | essencial | aceita anual |
|---|---|---|---|
| `facturacao` | Faturação do mês (sem IVA) | sim | sim |
| `iva_liquidado` | IVA liquidado no mês | não | não |
| `compras_e_servicos` | Compras e serviços externos | sim | sim |
| `custos_com_pessoal` | Remunerações brutas + encargos | sim | sim |
| `resultado` | Resultado do mês | não | sim |

O IVA liquidado é o único que não aceita total anual: um total de IVA do ano
não serve para nada que o Punho faça — o que ele precisa de saber é quando a
entrega calha, e isso vem da periodicidade.

**Únicas** — uma resposta para a empresa toda:

| chave | rótulo | essencial |
|---|---|---|
| `regime_contabilidade` | Simplificado ou organizada | sim |
| `periodicidade_iva` | Mensal / trimestral / isento | sim |
| `cae` | CAE principal | não |
| `inicio_actividade` | Data de início de atividade | não |
| `retencao_irs` | Retenção de IRS nos recibos | não |

Acrescentar uma pergunta é um `insert` no catálogo, não um `alter table`. Foi
por isso que as respostas ficaram chave-valor: um modelo em que acrescentar uma
pergunta obriga a uma migração é um modelo em que ninguém acrescenta perguntas.

## O fluxo

1. **O gestor convida.** No Punho, secção da empresa: nome e email do
   contabilista. A app gera um token aleatório, envia o `sha256` para
   `punho_convites_contabilista.token_hash` e mostra o link em claro **uma
   vez** — para copiar para email ou WhatsApp. A base nunca guarda o token
   legível: quem lhe puser as mãos não abre o formulário de ninguém.
2. **Janela por omissão:** cinco anos até ao mês passado. Ajustável — uma
   empresa aberta há dois anos não deve receber uma grelha com trinta e seis
   meses impossíveis.
3. **O contabilista abre o link.** A Edge Function valida hash, expiração e
   revogação, marca `aberto_em` e devolve o formulário já preenchido com o que
   existir. Ele vê sempre o estado actual, não um formulário vazio.
4. **Preenche o que sabe, deixa o resto em branco.** Grava por secção, não só
   no fim — sessenta meses não se preenchem numa sentada. Cada ano tem, por
   baixo da grelha dos meses, uma linha de recurso: *"Não sei os meses — total
   do ano: ___"*. É o que apanha os anos mais antigos, onde a memória do
   contabilista já é grossa.
5. **Caixa livre no fim.** Sugestão ou pedido de ajuda, para
   `punho_mensagens_contabilista`. Entra como mensagem para o gestor, nunca
   como campo: texto livre não alimenta KPIs.
6. **Diz que acabou.** `submetido_em`. A partir daqui as lacunas viram tarefas
   do gestor, e o link continua a aceitar correcções.

## Edge Function

`supabase/functions/portal-contabilista/`. Nota de terreno: as Edge Functions
deste ecossistema vivem em `~/washinvoice-control/supabase/functions` — e a
`sincronizar-empresa-punho` **não tem código local em lado nenhum**, foi
publicada directamente. Esta nasce versionada, no repo do Punho, onde vive o
resto do desenho.

Serve HTML e trata submissões. Sem build web, sem hosting novo, sem Flutter web
para um formulário — o token já é validado do lado do servidor e não há stack a
manter. Rotas e regras no README ao lado.

Duas notas que só aparecem ao escrever o código:

- **A escrita passa por `punho_guardar_resposta_contabilista`**, não por um
  upsert do PostgREST. Motivo imediato: os índices únicos são parciais e o
  `on conflict` não sabe exprimir o predicado. Motivo melhor: é dentro dessa
  função que a empresa se deriva do convite, e por isso não há caminho nenhum
  em que o corpo do pedido escolha em que empresa escrever.
- **A leitura de euros é o sítio perigoso.** `1.234,56`, `1234.56`, `1234` e
  `1.200` têm de dar todos no número certo, e o caso ambíguo (`1.200` são mil e
  duzentos, não um e vinte) decide-se pela convenção portuguesa. Está isolada em
  `euros.ts` com testes, e o servidor devolve sempre o valor como o interpretou
  para o campo — quem escreveu vê como ficou antes de fechar a página.

## Ligação ao Punho

- **Tarefas.** `tarefasPendentes` (`lib/features/tarefas/data/tarefas_service.dart`)
  ganha um gerador que lê `punho_lacunas_contabilista()`. Severidade
  `aCompletar`. Precisa de um valor novo em `DestinoTarefa` —
  `historicoContabilista` — e do ecrã de grelha onde o gestor completa. É o
  mesmo ecrã que ele usa para rever o que o contabilista escreveu.
- **KPIs.** `recebidoMesHomologoCents` passa a cair em
  `punho_serie_mensal_contabilista()` quando não há movimentos reais desse mês.
  A app deixa de ser cega no primeiro ano.

  **A comparação mostra-se sempre, mesmo quando o homólogo é repartido.** Um
  campo vazio é pior do que um campo aproximado: o vazio não diz nada e não
  pede nada. Dados estimados dão crescimento estimado; dados verdadeiros dão
  crescimento verdadeiro — e a app diz qual dos dois está a mostrar.

  O que se propaga é a natureza do número, não a ausência dele. Se algum dos
  lados da comparação vier `repartido`, a variação sai marcada como estimativa.
  E é aí que a coisa se fecha sobre si mesma: um gestor que vê *"+12%
  (estimado)"* e não gosta tem o caminho à frente — escreve o valor real
  daquele mês do ano passado e a percentagem passa a ser verdade. O cálculo já
  lá está à espera.

  Melhor ainda: quando ele escreve esse mês, o mês sai da repartição e o
  remanescente do ano redistribui-se pelos que sobram. Cada verdade acrescentada
  corrige também os meses vizinhos, e a série continua a somar o total anual ao
  cêntimo.
- **Regime fiscal.** `regimeDaFormaJuridica()` passa a cruzar a forma jurídica
  do onboarding com a resposta a `regime_contabilidade`: ENI + organizada dá
  `eniOrganizado` em vez do `eniSimplificado` que hoje sai por omissão. A
  adivinha fica como fallback para quem não tem contabilista convidado.
- **Ficha da empresa.** `facturacao_ano_passado_centavos` e
  `facturacao_este_ano_centavos`, em `punho_empresas.dados`, **já são totais
  anuais** — cabem exactamente na coluna `ano`, com `origem = 'gestor'`. Em vez
  de ficarem a viver em paralelo, migram para lá e passam a ser o nível 2 da
  hierarquia para essa empresa: se o contabilista discriminar esse ano, os meses
  ganham; enquanto não discriminar, o valor que o gestor já tinha dado continua
  a alimentar o painel repartido. Uma verdade só, e nada do que já foi
  perguntado se perde.

## O que fica de fora da v1

- Rubricas não monetárias (número de colaboradores por mês, volumes). O
  catálogo já tem `tipo`, mas as respostas v1 só usam `valor_centavos` e
  `valor_texto`.
- Importação de ficheiro (SAF-T, Excel do contabilista). Muda o custo do
  preenchimento por completo, mas exige mapeamento por software de
  contabilidade e não bloqueia o resto.
- Convite por email automático. Na v1 o gestor copia o link e envia-o como
  quiser — é o passo que não precisa de infraestrutura para funcionar.

## O que já se provou

Percurso completo corrido contra o projecto real, com um convite descartável de
59 meses e os dados apagados no fim. Não é uma leitura do código: é o que a base
e a função respondem.

| O que se pôs à prova | O que aconteceu |
|---|---|
| Página com token válido | 200, empresa certa no título, seis anos, dez rubricas, 321 campos |
| Token inexistente | 404, a mesma resposta que um revogado ou expirado dá |
| `1.200` escrito num mês | Gravou 1200,00 € e devolveu-o já formatado ao campo |
| Total anual de 2024 | Gravou como anual, sem inventar meses |
| Campo esvaziado | Apagou a linha — voltou a «não sei», que não é zero |
| «Terminei» | Marcou `submetido_em` e os campos continuaram editáveis |
| Recarregar a página | Os quatro valores e a opção voltaram exactamente como ficaram |
| Repartição de 2021 | 30 000 € em 4 meses — só os do convite — a 7 500 € cada, fecha ao cêntimo |
| Repartição de 2024 | 48 000 € em 12 meses, fecha ao cêntimo |
| Lacunas depois de submeter | Facturação: 42 meses em falta e 16 cobertos só por total anual. As duas severidades separadas, como devem ser |
| Trilho de auditoria | `criou` e `apagou` com valor antes e depois, atribuídos ao convite |
| RPC de escrita chamado com a chave `anon` | `42501 permission denied` |
| Séries e lacunas chamadas com a chave `anon` | `[]` — as políticas RLS aguentam |

### A guarda que faltava

O teste apanhou um buraco real: um `POST` com um mês **fora** do período do
convite era aceite. A página nunca o enviaria — ela só desenha os meses pedidos
— mas o token é a autenticação toda, e quem o tiver monta o pedido à mão. Sem
guarda, um convite para os últimos cinco anos escrevia facturação em meses
futuros, e esses números entravam nos KPIs sem ninguém os ter pedido.

`punho_guardar_resposta_contabilista` passou a recusar mês fora de
`[mes_inicial, mes_final]` e ano fora dos anos que a janela toca. Rubricas de
resposta única não têm período e passam. Confirmado depois: mês futuro e ano
de 2015 recusados com 400 e mensagem legível, mês e ano dentro da janela
aceites, rubrica única intacta.

É a lição de sempre: validar na página é cortesia para quem escreve, não
segurança. Quem quer escrever à força nunca passa pela página.

### Duas funções de trigger que estavam à mão de semear

O linter do Supabase apanhou `punho_validar_resposta_contabilista` e
`punho_registar_alteracao_contabilista` executáveis por `anon` como
`security definer`. Chamá-las fora de um trigger só dá erro, portanto o risco
prático era nenhum — mas uma `security definer` aberta a `anon` é uma porta a
mais, e fechá-la custou duas linhas. Zero avisos sobre objectos do portal.


## O que o contabilista vê antes de escrever

Três coisas, por esta ordem, e nenhuma é decoração.

**Quem está a pedir.** Nome, NIF e sede da empresa, logo no cabeçalho. Um
contabilista tem dezenas de clientes e recebe links por email; «dados históricos
de a empresa» não lhe diz de quem são. O NIF é o que desfaz a dúvida — dois
clientes podem chamar-se parecido, o número é um só. Quem não tem a certeza de
que cliente está a preencher, ou não preenche, ou preenche o do lado.

**Porquê, em três parágrafos.** O que é o Punho, porque é que a comparação com o
ano anterior não funciona sem ele, e o que se espera: preencher com o que já tem
fechado — não é trabalho novo, são valores que já saíram das contas que fez. Um
pedido sem explicação parece burocracia, e burocracia de terceiros é a primeira
coisa que se adia.

**Que período faz sentido.** A app pede cinco anos por omissão. Uma empresa
aberta em 2024 não tem 2021, e o contabilista via trinta e seis meses que nunca
existiram — e não são só ruído no ecrã: cada um deles contaria como lacuna, e o
gestor acabava com uma tarefa a pedir-lhe faturação de antes de a empresa
existir. Uma tarefa impossível de fechar é pior do que nenhuma, porque ensina a
ignorar a lista toda.

Por isso é ele que escolhe de onde começar, e a grelha e as lacunas encolhem com
ele. Guarda-se em `mes_inicial_efectivo`, coluna à parte de `mes_inicial`: uma é
o que o gestor pediu, a outra é o que o contabilista disse que faz sentido
pedir. As duas interessam — «pedi cinco anos, ele diz que só há desde Março de
2024» é o gestor a ficar a saber uma coisa sobre a própria empresa, e por isso a
app mostra-lho. Só encolhe, nunca alarga além do pedido, e as respostas
anteriores ao novo início ficam guardadas: um filtro de visualização não apaga
dados.

## Uma leitura de euros, não duas

O `centsDeTexto` da app lia `1.200` como 1,20 €; o portal lê como 1 200,00 €.
Enquanto os dois escreverem no mesmo histórico, isso é o mesmo campo com dois
significados — e não rebenta: grava-se em silêncio e aparece meses depois num
painel que ninguém percebe porque está errado.

A regra que decide é agora a mesma nos dois sítios, e vive em
`lib/core/format/campos.dart` e em `portal-contabilista/euros.ts`:

* há vírgula → a vírgula é o decimal e os pontos são milhares;
* só pontos, a separar grupos de exactamente três dígitos → são milhares;
* qualquer outro ponto → é decimal, que é como escreve quem copiou de uma folha
  de cálculo inglesa.

Isto corrigiu um erro que já existia em toda a app, não só aqui: quem escrevesse
`1.200` num preço, num custo fixo ou numa faturação anual ficava com um valor
cem vezes menor. Os casos de teste são os mesmos dos dois lados —
`test/core/format/campos_test.dart` e `euros_test.ts`.
