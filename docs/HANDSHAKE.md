# Handshake — aba nova, Punho

Lê só isto para começar. O detalhe está em `docs/HANDOVER_SESSAO_SEGUINTE.md`;
vai lá quando precisares, não antes.

**Onde estás:** `/home/cesar/punho`, dentro do i9 (`hostname` =
`decisaodigital`). `flutter` está no PATH — corre directamente, **não uses
ssh**. Branch `main`, commits directos, `git add` por ficheiro, nunca `-A`.

**Estado:** limpo em `21b269a` (branch `main`). `flutter test` verde (641, 1
skipped), `flutter analyze` com os mesmos 8 avisos `info` pré-existentes —
linha de base, não tentes limpá-los.

---

## Sessão de 3 de Agosto — registar-terminal passa a ligar o NIF real

A Edge Function `registar-terminal` (deploy v7, já em produção) passou a
aceitar um `nif` opcional no corpo e a actualizar `licencas.nif` — que nasce
sempre com o placeholder `'000000000'` — quando recebe um NIF válido de 9
dígitos diferente do guardado. Antes disto, nenhuma instalação Punho jamais
tinha o seu NIF real ligado à linha de `licencas`, mesmo depois da empresa
preencher o NIF nas Definições. `LicencaService.registarTerminal` ganhou o
parâmetro opcional `nif`, e `_registarTerminal()` em `main.dart` busca a
ficha via `EmpresaSyncService.buscarFicha()` antes de registar, passando
`ficha?.nif`. Testes novos em `licenca_service_test.dart` cobrem os dois
casos (com e sem NIF). `flutter analyze` e `flutter test` verdes (643 testes,
1 skip) depois da mudança.

## Sessão de 2 de Agosto, mais tarde — NIF obrigatório no onboarding

Decisão fechada pelo Cesar: o NIF da empresa deixa de poder ficar como
"tarefa aberta" no onboarding — passa a obrigatório (9 dígitos) para avançar
o passo "Forma jurídica e NIF da empresa". Resolve um bug real: a Edge
Function `sincronizar-empresa-punho` sempre rejeitava (400, payload inteiro)
quem terminava o onboarding sem NIF, e a ficha ficava presa para sempre com
`punho_empresas.dados={}`. Detalhe completo na secção 3.6 de
`docs/DECISOES_E_ROADMAP_VIVO.md`. Não mexe na Edge Function nem corrige
retroactivamente fichas já presas (ex.: Lavandaria Mare Alta) — só previne o
problema em onboardings futuros.

## Sessão de 2 de Agosto, mais tarde ainda — mesma regra em Definições da Empresa

Ponta que tinha ficado aberta na sessão anterior: a Opção B ("NIF nunca em
branco") só tinha sido aplicada ao onboarding. `company_settings_page.dart`
(Definições da Empresa) continuava a aceitar gravar com o NIF vazio,
reabrindo o mesmo 400 da Edge Function `sincronizar-empresa-punho` por essa
via. Fechado com o mesmo padrão: `_nifErro` inline, `inputFormatters`
(dígitos, máx. 9), `errorText`, gate em `_guardar()` com `nifValido()`
(`lib/core/format/campos.dart`), sem `Form`/`GlobalKey` (o ecrã nunca teve).
`InitialDataTasksPage` ficou de fora — confirmado que está órfã, sem
navegação nenhuma no código a alcançá-la (a tarefa "Indicar o NIF" navega
para `CompanySettingsPage`, ver `DestinoTarefa.definicoesEmpresa` em
`tarefas_page.dart`). Detalhe completo na secção 3.6 de
`docs/DECISOES_E_ROADMAP_VIVO.md`.

## Sessão de 2 de Agosto, à noite — aparelho desbloqueado, confirmação visual completa

O César desbloqueou o Redmi fisicamente. `com.example.punho` não estava
instalado (build limpo a partir de `c3389f7`, `--dart-define` das chaves do
`.env`, `push` + `pm install`). Descoberta nova sobre o contorno do MIUI: o
diálogo de confirmação (`com.miui.securitycenter`) desactiva os botões nos
primeiros segundos e auto-cancela ao fim de ~9-12 s sem toque — resolve-se
correndo o `pm install` em background e tocando "Instalar" (coordenadas via
`uiautomator dump`) depois da janela de protecção passar, não antes.

Todos os achados marcados como "corrigido por código, por confirmar no
aparelho" na sessão anterior foram **confirmados visualmente, sem
regressões**:

- **Achado 6** (sync parada) — depois de reinstalar a app do zero e refazer
  o onboarding local, a lista de Clientes já trazia os dados semeados em
  sessões anteriores e o painel mostrava 128 € de entradas, sem acção manual.
- **Achado 7** (rotação indevida no arranque) — dez capturas em sequência
  num `force-stop` + relançar mostram o splash sempre em retrato.
- **Achado 14** (quarta-feira errada) — consistente; hoje domingo com dados,
  mostra "Valores em atraso". O ramo do bug (segunda/terça) não é
  reproduzível fora desses dias; cobertura fica no teste automático.
- **Achado 16** (crash da sync no arranque) — vários reinícios, sem ecrã
  vermelho.
- **Achado 17** (duplicado aceite + ecrã vermelho) — cliente com telemóvel
  repetido foi recusado, sem crash.
- **Achado 17b** (aviso escondido atrás do teclado) — aviso ficou visível
  com o teclado numérico aberto.
- **PIN 1234** — posto em Perfil > Cadeado > Definir PIN; confirmado a pedir
  PIN no arranque e a desbloquear.

**Achado novo, menor:** os diálogos "Mudar palavra-passe" e "Definir PIN"
disparam o banner de overflow do Flutter (`BOTTOM OVERFLOWED BY N PIXELS`)
quando o teclado abre, cobrindo o botão de ação por instantes. Só visto em
build debug (banner exclusivo de debug); não avaliado em release. Não
corrigido — aponta-se para decisão.

Detalhe completo em `docs/PLANO_DE_TESTES_2026-08-02.md`, secção "Sessão de
2 de Agosto, confirmação visual".

---

## Sessão de 2 de Agosto, fim de tarde/noite — telemóvel bloqueado, corrigido o que dava por código

**O Redmi (`94c906b9`) tem ecrã bloqueado com PIN/biometria** —
`dumpsys window policy` confirma `KeyguardServiceDelegate showing=true`,
`mScreenLocked=true`. Sem PIN/impressão digital não há como desbloquear por
`adb`; **nenhum ponto do smoke test no aparelho foi verificado visualmente
nesta sessão**. Precisa do César a desbloquear fisicamente antes da próxima
ronda.

Corrigidos por leitura de código + testes automáticos (sem ver no ecrã):

- **Achado 14** — recomendação "Quarta-feira fraca" podia usar uma quarta-feira
  **futura** em vez da última passada, às segundas e terças-feiras
  (`weekday - 3` sem `% 7`). Corrigido em `lib/core/guidance/guidance_engine.dart`
  (`0df267d`). O caso relatado (domingo, sem dados) não era este bug — era
  falta de dados reais, e já ficou resolvido quando entraram os recebimentos
  semeados; mas o bug de facto existia para dois dias da semana.
- **Achado 13** — selector de máquinas em "Confirmar reserva" mostrava só a
  referência quando existia, escondendo o nome. Agora mostra sempre
  `Nome · Referência` (`cf2b3ab`).
- **Achado 20** — despesas/recebimentos e clientes saíam pela ordem de chegada
  da sincronização. Agora despesas/recebimentos por data (mais recente
  primeiro, `9c058fe`) e clientes por ordem alfabética (`cf2b3ab`).
- **Achados 12 e 21** ("Ready?"/"o teu tablet", "em preparação para a v0.0.9")
  — **já estavam corrigidos** por `8b3b5ec`, de uma sessão anterior a esta;
  só a checklist não tinha sido actualizada.
- **SafeArea do login (P0)** — confirmado no código (`login_screen.dart` e
  `registo_screen.dart` usam `SafeArea`); por confirmar visualmente quando o
  aparelho desbloquear.
- **Rotação de ecrã indevida noutro sítio** — auditados os 9 ficheiros que
  usam `OrientacaoDoContexto`; nenhum outro ecrã declara orientação de forma
  inconsistente. A correcção do splash (achado 7) parece ser a única
  necessária; sem o aparelho não há como confirmar 100%.
- **PIN 1234** — não é bug de código. É um passo manual por fazer no próprio
  telemóvel (Definições > Cadeado), documentado como "local ao telemóvel, sem
  nada no servidor" no relatório de 1 de Agosto. Bloqueado pelo ecrã trancado.

**Achado novo, não estava na lista: a ficha da empresa NÃO chegou ao
Control.** Confirmado por SQL directo no Supabase (projecto
`oefqbkhioncakojipqyx`):

- `punho_empresas.dados` para a Lavandaria Mare Alta está **vazio** (`{}`,
  `revision=1`), apesar do onboarding completo às 01:00 UTC de 2 de Agosto.
- Não existe **nenhuma** linha em `licencas` para esta empresa
  (`machine_id ilike '%1a267759%'` devolve vazio) — o trigger
  `punho_empresas_sync_licenca` nunca correu com sucesso.
- Os logs da Edge Function `sincronizar-empresa-punho` mostram **HTTP 400
  repetido** desde 2026-08-01 23:46 UTC até pelo menos 2026-08-02 18:04 UTC, a
  cada ~20 minutos (bate certo com o temporizador do `EmpresaSyncController`).
  A função devolve 400 quando `nif.length < 9` — ou seja, a ficha que está
  presa na fila de retentativa (`SharedPreferences`, `FichaEmpresaPendente`)
  tem NIF vazio ou inválido, e **fica presa nesse payload para sempre**: o
  motor volta a tentar a mesma ficha de sempre, nunca relê o estado actual da
  app para montar uma nova.
- Não percebo, sem o telemóvel, se essa ficha presa é de uma tentativa
  **anterior** ao onboarding completo (23:46 UTC de 1 de Agosto é bem antes
  das 01:00 UTC de 2 de Agosto) que nunca foi substituída, ou se o próprio
  `_concluirOnboarding` de 01:00 UTC também mandou NIF vazio por algum motivo
  que não vejo no código. Não corrigi às cegas — aponto e fica para
  decidir/reproduzir com o aparelho na mão.

---

## Aviso, ainda válido: pode haver trabalho de outros a meio de sessões anteriores

Se `git status` mostrar alterações por commitar que não sejam tuas, corre
`flutter analyze` e `flutter test`, e commita por ficheiro. Não desfaças.

---

## Três regras do Cesar. Sem elas vais desfazer trabalho de propósito feito

1. **A app começa vazia.** O onboarding não cria registos. Quem declara quinze
   máquinas fica sem nenhuma; a app só lembra o que falta. As fichas
   placeholder foram removidas de propósito, campo `placeholder` incluído, sem
   compatibilidade. Não as reponhas.
2. **Não se disfarçam falhas.** Palavras dele: «se parte, tem de partir com
   estrondo». Nada de `try/catch` decorativos, valores por omissão a mascarar
   erro, nem migrações silenciosas. Encontraste um sítio onde a app maquilha
   uma falha? **Aponta, não remendes.**
3. **Dados a fingir só para testes**, e por seed no servidor — nunca dentro da
   app.

E a decisão de produto fechada hoje: o **limite de colaboradores** é o que o
Cesar autoriza no Control (`punho_subscricoes.limite_colaboradores_ativos`). O
número do onboarding é só informativo. Exceder **não impede o cadastro** —
impede o **acesso** sem autorização expressa dele. Autorizar o sétimo significa
que o contrato subiu.

---

## Só ele decide (não faças, pede)

- Aplicar `supabase/seeds/mare_alta.sql` (ver `docs/DADOS_DE_TESTE.md`).
- A migração da notificação de instalação — SQL pronto na adenda de
  `docs/PLANO_PUSH_INSTALACAO_PUNHO.md`. **Escrever na base de dados de
  produção foi recusado pelo classificador de permissões**: não contornes,
  pede-lhe.
- Publicar (APK + GitHub Release + `versoes_apps`) — só a pedido explícito, e
  aí vai até ao fim.
- Apagar os cinco tokens FCM mortos em `admin_dispositivos`.
- RPC `punho_definir_limite` — SQL pronto em
  `supabase/migrations/20260802_punho_definir_limite.sql` (`4bbc60e`),
  **confirmado por consulta directa que não existe em produção**
  (`pg_proc` sem `punho_definir_limite`). Continua por aplicar.

---

## O que fazer a seguir, por ordem

1. **Ver no aparelho.** Nada do que foi feito hoje foi visto a correr. À hora
   deste ficheiro não havia telemóvel ligado (`adb devices` vazio). O `adb`
   está em `~/android-sdk/platform-tools/adb` — caminho completo, o PATH do
   `.bashrc` não chega a shells não interactivos. Falta ele ligar o aparelho e
   aceitar a impressão digital RSA; em Xiaomi/MIUI precisa também de «Instalar
   via USB» e «Depuração USB (definições de segurança)».
   Prioridade a ver: onboarding a começar vazio, ficha do cliente a abrir e
   editar, os três diálogos convertidos (lead, reserva, marcação), painel de
   tesouraria a sair de "Por apurar", e o cabeçalho do login com `SafeArea`
   (era P0, corrigido às cegas na sessão anterior).
2. ~~Máquina alugada bloqueia todas as semanas seguintes~~ (achado 18) —
   **resolvido**: bloqueia só a data ocupada. Lógica em `3c7fe1c`, testes em
   `3db013b`.
3. **Control — menus do Punho.** Proposta em aberto, três peças, detalhe no
   handover. A peça pequena que o desbloqueia: RPC `punho_definir_limite` para
   editar o limite fora da criação da empresa.

---

## Duas coisas que valem mais do que parecem

**As tabelas por entidade estão vazias.** `punho_clientes`, `punho_maquinas` e
companhia têm zero linhas apesar de uso real. A fonte de verdade é o log
append-only `punho_operacoes` (sync por `seq`, Realtime pelo trigger
`punho_operacoes_avisar`), e é só de lá que o telemóvel puxa. Esclarecer isto
antes de construir seja o que for por cima daquelas tabelas.

**O bug do dinheiro.** `1.500,00 €` grava **zero**, calado, em oito sítios:
`(double.tryParse(texto.replaceAll(',', '.')) ?? 0)` dá `1.500.00`, que não é
número, e o `?? 0` inventa o zero. O ajudante correcto já existe —
`centsDeTexto` em `lib/core/format/campos.dart`. Os agentes em voo estavam a
tratar disto; confirma o que ficou feito antes de repetires.

---

## Custos

Ficheiros >500 linhas não se lêem inteiros no thread principal — delegar
(`operational_pages.dart` tem 3600+). Capturas de ecrã nunca com `Read` no
thread principal. O Cesar tem poucos tokens: bullets curtos, sem preâmbulos,
perguntas em vez de suposições.

---

## Empresa de teste

**Lavandaria Mare Alta** (`1a267759-…`), `cesarmendes78+punhoteste@gmail.com`
/ `MareAlta2026`. Supabase: projecto WashInvoice, `oefqbkhioncakojipqyx`.
