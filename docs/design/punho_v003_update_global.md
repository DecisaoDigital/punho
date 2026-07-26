# v0.0.3 — Aviso de update global, independente do gate de acesso

Branch: `release/v0.0.3`, a partir de `chore/estabilizacao-v0.0.3`. Entra na
release consolidada da v0.0.3, junto com a sprint de estabilização.

Foi pensado para a v0.0.4 e **antecipado** para aqui por uma razão prática: a
v0.0.2 instalada no telemóvel do Cesar não sabe verificar updates fora do
dashboard, portanto a v0.0.3 tem de ir por USB de qualquer maneira. Se o aviso
global não fosse nesta, a v0.0.4 também teria de ir por USB. Metendo-o aqui, a
v0.0.3 é a **última** instalação manual.

## O buraco que isto tapa

Até aqui, o aviso de nova versão só chegava a **um** tipo de utilizador: gestor,
com adesão activa em `punho_membros`, com o dashboard aberto. Duas razões, ambas
independentes:

1. `PunhoUpdateService.check()` começava com `if (session == null) return null;`
   — quem estava preso no ecrã de login nunca chegava a perguntar nada.
2. O `PunhoUpdateBanner` estava montado num único sítio: `dashboard_page.dart`.
   Quem tem sessão mas está bloqueado no `AcessoGate` ("Pedido em análise",
   "Acesso indisponível") nunca chega ao dashboard.

Ou seja, os três estados mais prováveis nesta fase da app — por aprovar,
recusado, ou sem sequer conseguir entrar — eram exactamente os três que não
recebiam aviso de update. E são esses os utilizadores a quem mais interessa
receber uma versão nova: é provável que a correcção que esperam venha nela.

O Punho não tem FCM, portanto não há canal de push. O único canal é a app
perguntar ao servidor no arranque — e era isso que a guarda de sessão matava.

## O que mudou

### 1. `check()` deixou de exigir sessão

`lib/core/updates/update_service.dart`

A Edge Function `versao-mais-recente` está deployed com `verify_jwt: true`, o
que exige uma **chave válida** no header `Authorization`, não um utilizador
autenticado. Sem sessão, o `supabase_flutter` põe lá a chave pública do
projecto e o gateway aceita-a — verificado empiricamente contra o projecto real
em Julho 2026 (ver `LICENCIAMENTO.md`, secção "Porque é que funciona sem
sessão"). O `PunhoLicencaService` já vivia disto desde a v0.0.2; o auto-update
era o único sítio que ainda replicava a guarda por engano.

Com sessão continua a mandar-se o token, para a função poder registar quem
pediu se um dia isso for útil. Sem sessão não se manda header nenhum — deixa-se
o cliente pôr a chave pública.

A Edge Function **não** foi tocada.

Aproveitou-se para dar ao serviço o mesmo `typedef` de invocação que o
`PunhoLicencaService` já tinha (`PunhoUpdateService.comInvocador`). É o que
permite testar a resposta do servidor sem rede e sem package de mocking — o
repositório não tem `mockito` de propósito, e `http` não é dependência directa.

### 2. Estado global em vez de `FutureProvider` local

`lib/features/updates/update_providers.dart` (novo)

O `punhoUpdateProvider` era um `FutureProvider` declarado dentro do ficheiro do
banner. Passou a ser um `NotifierProvider<PunhoUpdateController,
PunhoUpdateInfo?>`, que dispara a verificação:

- uma vez quando é observado pela primeira vez — que é logo no arranque, porque
  o wrapper é a raiz da app depois do `Supabase.initialize`;
- outra vez quando o `authStateChanges` traz um **utilizador novo** (só
  `signedIn`, e só se o `id` mudou: o `signedIn` também dispara em refresh de
  token, e não vale a pena repetir a chamada por isso);
- a cada 24h, alinhado com o `licencaRefreshProvider` (que usa 6h para a
  licença). Não é over-engineering: é um `Timer.periodic` de três linhas que
  cobre a app que fica dias aberta no PC do escritório.

O estado é **pegajoso para cima**: só se escreve quando a resposta traz update.
Uma verificação que falha por estar offline não pode apagar um aviso que já
estava à vista.

### 3. Wrapper à volta da raiz

`lib/features/updates/presentation/update_banner_wrapper.dart` (novo)

```
main()
  └── Supabase.initialize
      └── MaterialApp
          └── PunhoUpdateBannerWrapper          ← lê punhoUpdateProvider
              └── AuthGate                       (ou AppShell sem Supabase)
                  ├── ecrã de login              ← aviso chega aqui
                  └── AcessoGate
                      ├── PedidoEmAnaliseScreen  ← aviso chega aqui
                      ├── AcessoIndisponivel     ← aviso chega aqui
                      ├── AppShell (gestor)      ← aviso chega aqui
                      └── CollaboratorShell      ← aviso chega aqui
```

Disparo:

```
arranque ──► check() ──┐
login novo ─► check() ─┼──► punhoUpdateProvider ──► wrapper desenha o aviso
timer 24h ──► check() ─┘        (null = nada)
```

O wrapper envolve a raiz e não um ecrã. Nenhum dos shells sabe que ele existe,
e nenhum deles precisa de mudar para receber o aviso — incluindo shells que uma
versão futura venha a acrescentar. O `AcessoGate` continua a decidir tudo o que
se vê por baixo: o aviso é ortogonal, não é bypass. Os testes verificam
explicitamente que com aviso à vista o `AppShell` continua a não aparecer a
quem tem o pedido pendente.

O `PunhoUpdateBanner` saiu do `dashboard_page.dart`.

### Column para o opcional, Stack para o obrigatório

**Opcional → `Column`.** O aviso empurra o conteúdo para baixo em vez de o
tapar. Uma `Stack` punha o aviso por cima de qualquer coisa que estivesse no
topo do ecrã por baixo — que nas duas shells é a `AppBar`, ou seja os botões de
convites e de terminar sessão. Empurrar não esconde nada e não rouba toques.
Custa altura de ecrã enquanto o aviso está lá, e é o mesmo comportamento que o
`LicencaBanner` já tem dentro da `AppShell`.

**Obrigatório → `Stack` com `ModalBarrier`.** Aqui tapar é precisamente o ponto.
O ecrã por baixo continua montado — não se muda o que o utilizador estava a ver,
nem se arrisca desmontar e remontar o gate — mas fica intocável: `ModalBarrier(dismissible: false)` come todos os toques. Não há botão
de dispensar — nem para o gestor, nem para quem está bloqueado no gate. A
barreira tem `Key` própria para os testes a distinguirem das barreiras que o
`Navigator` cria por sua conta em cada rota.

## Porque não FCM nesta sprint

Push resolvia o caso "app fechada", que o arranque não cobre. Mas o custo é
desproporcionado para o problema de hoje: `firebase_messaging`, projecto
Firebase, `google-services.json`, service account no lado do Control, código de
registo e renovação de token, tratamento em foreground/background/terminated, e
uma permissão de notificações a pedir ao utilizador no Android 13+.

E não resolve nada que já não esteja resolvido: quem abre a app recebe o aviso
no arranque, e quem não a abre não a vai actualizar por ver uma notificação.
Registado em `BACKLOG_v0.0.4.md` com a nota "só se justificar", com destino
v0.1.0 — quando houver
utilizadores reais que passem dias sem abrir a app.

## Por validar à mão

**Por fazer, para o Cesar.** Nada disto conta como validado até estar feito:

0. Instalar a v0.0.3 (`0.0.3+3`) no Redmi por USB. Sem isto nada disto se
   observa — a v0.0.2 instalada não tem este código.
1. Publicar em `versoes_apps` uma linha para `app='punho'` com `build_number`
   superior a **3**, `obrigatoria=false`.
2. Arrancar a app **sem fazer login** → o aviso tem de aparecer por cima do
   ecrã de login, com botão "Atualizar" a abrir o URL.
3. Entrar com uma conta com pedido pendente → aviso por cima de "Pedido em
   análise", e o ecrã continua a ser "Pedido em análise".
4. Pôr `obrigatoria=true` → o aviso tapa a app e nada por baixo responde.

## Nota de release

A **v0.0.3 é a primeira versão com aviso de update global**. A v0.0.2 instalada
no Redmi não sabe verificar updates fora do dashboard, e é sempre a app
instalada que faz a pergunta — nenhuma versão se anuncia a si própria a uma
versão anterior que não pergunta.

Portanto:

| Versão | Como chega ao telemóvel |
|---|---|
| v0.0.3 | **USB.** Última instalação manual. |
| v0.0.4 e seguintes | Aviso na app, assim que o Cesar publicar em `versoes_apps` |

E o aviso da v0.0.3 só aparece depois de existir uma linha em `versoes_apps` com
`build_number` maior que 3 — enquanto for a versão mais recente publicada, não há
nada a anunciar e o banner fica invisível. Isso é o comportamento certo, não um
sintoma de estar quebrado.
