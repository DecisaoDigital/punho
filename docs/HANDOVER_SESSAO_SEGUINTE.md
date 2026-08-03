# Handover — próxima sessão Cowork · Punho

**Data do handover:** 3 de Agosto de 2026 (actualização parcial — ver nota
abaixo)
**Branch:** `main` — árvore limpa em `beb6cd1`
**Versão publicada:** v0.2.0 (`version: 0.2.0+33`), pela cadeia completa (APK
+ GitHub Release + `versoes_apps`) a partir do i9 — o workflow antigo do
GitHub Actions foi removido nesta sessão. Instalação no aparelho de teste
**não confirmada** nesta actualização.

Nota: esta revisão só acrescenta os cinco commits mais recentes (ver secção
abaixo); o resto do ficheiro — incluindo "Em voo" e "Por autorizar pelo
Cesar" — não foi reverificado e pode já estar desactualizado por commits
intermédios não cobertos aqui.

---

## O que mudou de fundo nesta sessão

Não foram só correcções. Mudaram três regras de produto, ditas pelo Cesar, e
elas explicam quase todos os commits abaixo. Um agente que não as saiba vai
tentar repor o que foi deliberadamente tirado.

**1. A app começa vazia.** O onboarding não cria registos. Quem declara quinze
máquinas fica sem nenhuma e regista-as uma a uma; a app só o lembra do que
falta, pela conta declarado menos registado. As fichas placeholder ("Máquina
1…15") foram-se, e o campo `placeholder` saiu por inteiro dos modelos, da
gravação em disco e da interface — **sem leitura de compatibilidade**.

**2. Não se disfarçam falhas.** Palavras dele: «se parte, tem de partir com
estrondo». Nada de `try/catch` decorativos, valores por omissão a mascarar
erro, nem migrações silenciosas. Instalações antigas com placeholders gravados
deixam simplesmente de os ver lidos — se isso partir alguma coisa, é isso que
ele quer ver. Quem encontrar um sítio onde a app maquilha uma falha, **aponta,
não remenda por iniciativa própria**.

**3. Dados a fingir só para testes, e por outra via.** Em vez de placeholders,
um seed com dados inventados mas coerentes, aplicado no servidor. Está escrito
e por aplicar (ver abaixo).

**4. Limite de colaboradores — decisão fechada.** O limite é o que o Cesar
autoriza no Control (`punho_subscricoes.limite_colaboradores_ativos`),
combinado quando o empresário assina o plano. O número do onboarding é **só
informativo**: quantos tem activos de momento. Exceder **não impede o
cadastro** — impede o **acesso** sem autorização expressa dele. E autorizar o
sétimo não é excepção àquela pessoa: significa que o contrato subiu.

---

## Commitado em 3 de Agosto, os cinco mais recentes (sobre `786d845`)

```
786d845 feat(conflitos): Fase 0 — infra genérica de conflito pendente
65fae4e chore(release): remove o workflow antigo, GH Actions deixa de compilar/assinar/publicar
5c6a704 chore(release): v0.2.0
224853d fix(sugestoes): deixa de enviar nif, identifica sempre por machine_id
beb6cd1 chore(assets): regenera icones e splash (launcher_icons + native_splash)
```

- `786d845` — Fase 0, só infra e inerte por construção, para o caso de dois
  colaboradores offline reservarem a mesma máquina para clientes diferentes:
  modelo `ConflitoPendente` (id determinístico pelo par ordenado das reservas
  em conflito), registo local que nunca reabre um conflito já resolvido, e
  sincronização própria da tabela `punho_conflitos_pendentes` (RLS: SELECT
  aberto, INSERT/UPDATE só Gestor). Deteção real em `aplicarOperacaoRemota` e
  o banner de decisão do Gestor ficam para depois, a pedido.
- `65fae4e` — apaga `.github/workflows/release.yml`; deixa de compilar/
  assinar/publicar por push de tag. Publicação passa a ser inteiramente
  manual a partir do i9 (`docs/PROCESSO_DE_RELEASE.md`).
- `5c6a704` — release v0.2.0 (tag criada, notas em
  `docs/release_notes/v0.2.0.md`), publicada pela cadeia completa a pedido
  explícito do Cesar.
- `224853d` — achado de segurança real: RLS de pedidos_ajuda/sugestoes
  deixava um utilizador autenticado ler/alterar pedidos de **outra empresa**
  (faltava `is_admin()` nas policies), e o `nif` de cada pedido vinha do que
  o próprio pedido dizia. Corrigido na Supabase (RLS + trigger `BEFORE
  INSERT` a resolver `nif`/`cliente_id` sempre por `licencas`, chave
  `(machine_id, app)`) e no cliente — `sugestoes_service.dart` e
  `perfil_popup.dart` deixam de enviar `nif`, passam a enviar `machine_id`.
- `beb6cd1` — regenera ícone adaptativo e splash claro/escuro
  (`flutter_launcher_icons`/`flutter_native_splash`); puramente visual, sem
  lógica.

Nota: o hiato entre `d46065c` (fecho do handover anterior) e `786d845` — 37
commits, releases `v0.1.5` até `v0.1.11` — ficou preenchido numa revisão
posterior (3 de Agosto) em `docs/ESTADO_ATUAL_DA_APP.md` e
`docs/DECISOES_E_ROADMAP_VIVO.md` (secção 3.65). Essa revisão também
reverificou as secções "Por confirmar no aparelho" e "Achados por corrigir"
abaixo à luz desses commits — o que ficou resolvido está marcado inline.
Ainda não foi reverificada a secção "Em voo" nem "Por autorizar pelo Cesar".

---

## Commitado nesta sessão (sobre `94362b4`)

```
d46065c docs(auditoria): o que a app entrega a um empresario que responde a tudo
8d84d6d test(dados): empresa de teste com dados inventados a serio
f90a576 feat(onboarding): a app comeca vazia, sem fichas a fingir
5a2d41b fix(empresa): o empresario deixa de poder apagar os dados da app
ce85079 docs(push): porque e que a notificacao de instalacao do Punho nao se percebia
59fb98c feat(colaboradores): o limite autoriza o acesso, nao trava o cadastro
091d5d8 feat(onboarding): a frota declarada aparece, e a facturacao enche o historico
de11645 feat(clientes): ficha do cliente abre para leitura e edicao
```

`flutter analyze` com os 8 avisos `info` pré-existentes e zero erros;
`flutter test` verde (593 testes, 1 skipped) na árvore combinada.

Notas sobre commits que enganam pela mensagem:

- `091d5d8` criou placeholders de **veículos**; `f90a576`, horas depois,
  tirou-os outra vez junto com os das máquinas, por decisão do Cesar. O que
  ficou de `091d5d8` foi a escrita do `historicalMonths` a partir da facturação
  do ano passado — divisão igual pelos doze meses, resto nos primeiros, sem
  pisar meses afinados à mão nem se repetir num segundo onboarding.
- A recusa por limite saiu do `saveCollaborator` dentro de `091d5d8` (o ficheiro
  vinha de lá), e não em `59fb98c`, que é o commit da regra.

---

## Em voo — dois agentes a trabalhar quando isto foi escrito

Ambos com ficheiros disjuntos, ambos sem commitar. Se a árvore tiver alterações
por commitar ao retomar, é deles: correr `flutter analyze` e `flutter test`
antes de julgar o que quer que seja, e commitar por ficheiro.

- **Dono de `operational_pages.dart` e `test/features/operations/`:** bug do
  dinheiro nas reservas e marcações; e a pergunta em falta — valor de compra e
  data de aquisição no formulário da máquina, ambos opcionais.
- **Dono de `finance_pages.dart`, `workforce_pages.dart`, modelos e
  controlador:** o mesmo bug do dinheiro em despesas, recebimentos e custos de
  colaborador; ciclo de vida do veículo (editar e arquivar, que não existiam);
  e `archived` no cliente, com a operação pronta no modelo mas **a interface por
  ligar** — essa vive no ficheiro do outro agente.

---

## Por autorizar pelo Cesar (nada disto é decisão de agente)

1. **Migração da notificação de instalação.** `CREATE OR REPLACE` da função
   `notificar_novo_terminal`, só muda o texto. SQL pronto na adenda de
   `docs/PLANO_PUSH_INSTALACAO_PUNHO.md`. Foi-me recusada a escrita na base de
   dados de produção pelo classificador de permissões — não contornar; pedir.
2. **Aplicar o seed** `supabase/seeds/mare_alta.sql` (ver
   `docs/DADOS_DE_TESTE.md`). Idempotente, com bloco de limpeza.
3. **Apagar cinco tokens FCM mortos** em `admin_dispositivos` (4 a 17 dias,
   todos `NotRegistered`). Não impedem nada, sujam os logs.

---

## O bug do dinheiro, para quem chegar a meio

`1.500,00 €` é gravado como **zero**, calado, em oito sítios. A causa é
`(double.tryParse(texto.replaceAll(',', '.')) ?? 0)`: para `1.500,00` dá
`1.500.00`, que não é número, e o `?? 0` inventa o zero. O ajudante correcto já
existe — `centsDeTexto` em `lib/core/format/campos.dart`, que trata milhares e
devolve `null`, nunca zero. A app tinha duas maneiras de ler euros, uma certa e
uma partida, e a partida estava espalhada. Os agentes em voo estão a deixar só
uma.

---

## Achado estrutural que ninguém pediu, e é o mais importante daqui

**As tabelas por entidade estão vazias.** `punho_clientes`, `punho_maquinas` e
companhia têm zero linhas apesar de a empresa de teste ter uso real. A fonte de
verdade é o log append-only `punho_operacoes` (payload JSON por entidade, sync
por `seq`, Realtime pelo trigger `punho_operacoes_avisar`), e é só de lá que o
telemóvel puxa. Ou aquelas tabelas são resto de um desenho abandonado, ou
alguém as devia estar a preencher e não preenche.

Isto tem de ser esclarecido **antes** de se construir o Control em cima delas —
ver a secção seguinte.

---

## Control — menus do Punho, proposta em aberto

O Cesar quer comandar os colaboradores a partir do Control. Hoje existe lá um
único ecrã, "Pedidos Punho" (5.º separador, só admin), com aprovar/recusar/
revogar via RPC `punho_decidir_pedido`. O limite só se escreve **na criação da
empresa**, num campo do modal de decisão; depois disso é SQL à mão. Não há ecrã
de empresa, nem badge, nem alerta.

Proposta apresentada, por ordem de valor:

1. **Ecrã "Empresas Punho"** — lista com `ativos / limite` e marca quando o
   declarado passa o autorizado.
2. **Editar o limite fora da criação** — RPC nova `punho_definir_limite`
   com `is_admin()`, a par do `punho_decidir_pedido`. É a peça mais pequena e a
   que o desbloqueia. Como autorizar o sétimo *é* subir o contrato, esta peça
   serve as duas coisas: o botão de aprovar, quando o pedido excede o plano,
   avisa que o contrato sobe e só grava com confirmação.
   **Actualização (3 Ago):** a função já existe em produção — confirmado por
   consulta directa a `pg_proc`, assinatura compatível com a migration
   `4bbc60e`. Não se sabe quem a aplicou nem quando; por confirmar se o
   Control já tem alguma interface a chamá-la, ou se continua só a peça 1
   (ecrã) por construir.
3. **Aviso da discrepância** — o `n_colaboradores` que a app já sobe para
   `punho_empresas` entra no RPC de listagem; badge no separador. Sem migração.

Por decidir com ele: se o aviso chega dentro do Control (badge) ou se quer push.

---

## Notificações de instalação — o que já se sabe

A cadeia **existe e dispara para o Punho**: `registar-terminal` insere em
`licencas` → `trg_notificar_novo_terminal` → `notificar_novo_terminal()` →
`enviar-push` → FCM. Não filtra por app. Duas instalações Punho passaram por lá
(Redmi a 1 de Agosto às 15:21, emulador a 2 de Agosto às 00:42), ambas com
`http_post` disparado.

O que falhava era o **texto**: o corpo lê `info_host->>'hostname'`, chave que só
o POS escreve — o Punho escreve `host`, `fabricante`, `versao_app` — e o título
nunca diz de que app se trata. O Cesar recebia «Novo terminal registado —
(máquina sem nome) — 339ed162…». Som: não há canal Android custom nenhum, tudo
cai no canal por omissão, que toca; só é silencioso com o Control em primeiro
plano, e isso é por desenho.

---

## Telemóvel de testes

O Cesar vai deixar um Android antigo ligado ao i9 em permanência, e liga o dele
pontualmente para ecrãs de tamanho diferente. Do lado do i9 está tudo pronto:
`adb` em `~/android-sdk/platform-tools/adb` (o PATH do `.bashrc` não chega a
shells não interactivos — usar caminho completo ou exportar), regras `udev` em
`/etc/udev/rules.d/51-android.rules`, utilizador no grupo `plugdev`.

Falta o que só ele pode fazer: Opções de programador, Depuração USB e — em
Xiaomi/MIUI — «Instalar via USB» e «Depuração USB (definições de segurança)»,
sem as quais o `pm install` recusa. Depois, aceitar a impressão digital RSA com
«Permitir sempre a partir deste computador». À hora deste handover **não havia
aparelho ligado** (`adb devices` vazio, nada no `lsusb`).

Lembrete de custo: capturas de ecrã nunca com `Read` no thread principal.

---

## Por confirmar no aparelho (nada disto foi visto a correr)

Arrastado da sessão anterior — **os quatro itens abaixo ficaram confirmados
no aparelho real na sessão de 2 de Agosto à noite** (Redmi desbloqueado pelo
César), ver `docs/PLANO_DE_TESTES_2026-08-02.md` linhas ~499-548 e commit
`55e66d7`:

- ~~Cabeçalho do login/registo com `SafeArea` — era achado P0.~~ **Confirmado:**
  bloco "Punho / Agarra o comando." completo, sem corte, em login e ecrã de PIN.
- ~~Aviso de recusa visível com teclado aberto em landscape.~~ **Confirmado**
  (achado 17b): aviso vermelho visível com o teclado numérico aberto.
- ~~Gravar cliente duplicado sem ecrã vermelho.~~ **Confirmado** (achado 17):
  cliente com telemóvel repetido foi recusado, sem crash, sem gravar.
- ~~Ficha da empresa a chegar ao Control depois de fechar a app.~~
  **Confirmado agora (3 Ago), por SQL directo em produção:** `punho_empresas`
  da Lavandaria Mare Alta já não está `{}` — tem `dados` completos (NIF
  509442129, 15 máquinas, etc.), `updated_at` 2026-08-03T12:49:21Z. O achado
  novo que tinha sido levantado em paralelo (ficha presa por NIF inválido,
  400 da `sincronizar-empresa-punho`) fica coberto pela obrigatoriedade do
  NIF fechada nesta sessão (`7269953`/`21b269a`) — mas não retroactivamente
  para quem já estava preso; esta empresa de teste em concreto já ressincronizou.

Desta sessão, tudo o que está commitado só tem testes automáticos por trás.
Prioridade ao retomar: onboarding a começar vazio (a mudança de maior alcance),
ficha do cliente a abrir e a editar, os três diálogos convertidos (lead, reserva
e marcação — o ecrã vermelho só se via fora dos testes, na animação real de
fecho), e o painel de tesouraria a sair de "Por apurar".

---

## Achados por corrigir (ver detalhe em `docs/PLANO_DE_TESTES_2026-08-02.md`
## e `docs/AUDITORIA_EMPRESARIO_EXEMPLAR.md`)

**Resolvido (achado 18):** uma máquina alugada bloqueia **apenas a data
ocupada**, não a máquina inteira. `machineAvailable`/`conflictFor`
(`lib/core/operations/operations_controller.dart`) já não olham para
`status == rented` — só para sobreposição real de datas, com excepção da
manutenção, que continua a bloquear sempre. Lógica em `3c7fe1c`, testes que a
fixam em `3db013b` (comentário "Decisão de 02/08/2026" em
`test/operations_test.dart`).

**Resolvido no hiato de 2–3 de Agosto (v0.1.5–v0.1.11), todos confirmados no
aparelho real ou por teste automático — ver `docs/PLANO_DE_TESTES_2026-08-02.md`:**
- ~~Rotação de ecrã indevida noutro ecrã~~ — auditados os 9 ficheiros que usam
  `OrientacaoDoContexto`; só o splash tinha o problema (`5dcc5c5`), e o achado
  7 (splash) foi confirmado em retrato em 10 capturas seguidas no aparelho.
- ~~Máquinas com referência perdem o nome no selector de reservas~~ — achado
  13, resolvido em `cf2b3ab`: mostra sempre `Nome · Referência`.
- ~~Ordem das listas de despesas e clientes não segue data nem alfabeto~~ —
  achado 20, resolvido: despesas/recebimentos por data desc (`9c058fe`),
  clientes por ordem alfabética (`cf2b3ab`).
- ~~«Recomendação do dia: Quarta-feira fraca» num domingo~~ — achado 14, bug
  real confirmado (`weekday - 3` sem `% 7`, errado às segundas/terças) e
  corrigido em `0df267d`; confirmado no aparelho em 02/08 à noite.
- ~~PIN 1234 por pôr~~ — posto em Perfil > Cadeado > Definir PIN, confirmado
  a pedir PIN no arranque e a desbloquear no aparelho em 02/08 à noite.

**Por fazer, continua aberto — nenhum commit do hiato o resolve:**
- Origem/campanha do lead e a ligação lead → cliente → recebimento nunca são
  perguntadas (auditoria, eixo 2).
- Overflow cosmético nos diálogos "Mudar palavra-passe" e "Definir PIN" com o
  teclado aberto — achado novo de `55e66d7`, só visto em build debug, não
  corrigido, "aponta-se para decisão".

**Testes por executar:** Faixa C ponto 5 (documentos, só em Windows) e Faixa D
(uma verificação no Control por **cada** empresa nova — só houve uma).

---

## Como trabalhar aqui

Builds, `flutter analyze`, `flutter test` e APK **no i9** — e a sessão de hoje
correu **dentro** do i9 (`hostname` = `home-lab-claude`), sem SSH: o `flutter`
está no PATH e chama-se directamente. Ver `CLAUDE.md` na raiz.

`git add` explícito por ficheiro, nunca `-A`. Commits directos a `main`.
Publicar (APK + GitHub Release + `versoes_apps`) **só a pedido explícito** do
Cesar, e aí vai até ao fim.

Ficheiros grandes (>500 linhas) não se lêem inteiros no thread principal —
delegar. `operational_pages.dart` tem 3600+.

---

## Estado dos push notifications (ainda válido)

Trigger `trg_notificar_novo_pedido_punho` (`AFTER INSERT` em
`punho_pedidos_acesso`) confirmado a funcionar em produção. Task #196 fechada.

---

## Dados de teste no servidor

Empresa **Lavandaria Mare Alta** (`1a267759-…`), conta
`cesarmendes78+punhoteste@gmail.com` / `MareAlta2026`, com 36 operações
semeadas mais registos criados pela app durante os testes (`Teste Duplicados`,
`Campainha Teste`, `Cliente Sino`, `Lavadora 8 kg`, colaboradora
`Ana Ferreira`, uma reserva confirmada em 29/07). O seed novo, quando for
aplicado, acrescenta 54 operações etiquetadas `por_dispositivo='seed-mare-alta'`
e não toca em nada disto. Apagar quando a empresa deixar de servir para testes.
