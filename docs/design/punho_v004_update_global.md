# v0.0.4 — Aviso de update global, independente do gate de acesso

Branch: `feat/update-global`. Primeira sprint da v0.0.4.

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
Registado em `BACKLOG_v0.1.0.md` com a nota "só se justificar" — quando houver
utilizadores reais que passem dias sem abrir a app.

## Por validar à mão

**Por fazer, para o Cesar.** Nada disto conta como validado até estar feito:

1. Publicar em `versoes_apps` uma linha para `app='punho'` com `build_number`
   superior ao instalado, `obrigatoria=false`.
2. Arrancar a app **sem fazer login** → o aviso tem de aparecer por cima do
   ecrã de login, com botão "Atualizar" a abrir o URL.
3. Entrar com uma conta com pedido pendente → aviso por cima de "Pedido em
   análise", e o ecrã continua a ser "Pedido em análise".
4. Pôr `obrigatoria=true` → o aviso tapa a app e nada por baixo responde.

## Nota de release

Este código só passa a valer **depois** de haver uma versão nova publicada. A
v0.0.3 instalada por USB no Redmi continua sem aviso automático: a app instalada
é que faz a pergunta, e essa não tem este código. É a **próxima** versão
instalada que passa a avisar das seguintes.
