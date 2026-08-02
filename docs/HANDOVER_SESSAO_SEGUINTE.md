# Handover — próxima sessão Cowork · Punho

**Data do handover:** 2 de Agosto de 2026 (revisto às 13h, após commitar)
**Última branch activa:** `main` — **árvore limpa, nada por commitar**
(`git status` vazio em `902059c`)
**Versão instalada no aparelho de teste:** v0.1.4+25 (`v0.1.4` taggeada)
**Skill de contexto a invocar primeiro:** nenhuma para Punho ainda

---

## Onde estás agora

Fechou-se a primeira campanha de testes a sério num aparelho real (Redmi Note
10 Pro, por `adb`/`flutter run` a partir do i9). Três faixas: dados semeados
no servidor a chegar ao telemóvel, onboarding do zero simulando um
empresário, e a bateria de oito testes manuais que já existia no repo, mais
verificação da campainha e das notificações no Control. Checklist viva,
achados 1–21 e comandos exactos usados estão em
`docs/PLANO_DE_TESTES_2026-08-02.md` — não repetidos aqui.

Resultado por faixa: A passa; B falha o critério "dashboard sem por apurar";
C tem 4 de 8 pontos limpos; D passa.

O achado maior: **a sincronização entre dispositivos nunca tinha corrido uma
única vez** desde que existe. Já está corrigida e commitada, tal como a
campainha em tempo real (também nunca tinha tocado) e a rotação indevida do
ecrã no arranque.

---

## Já commitado nesta sessão

```
902059c docs(testes): campanha de 2 Ago, decisoes e handover actualizados
8b3b5ec fix(copy): textos alinhados com a versao real e com o telemovel
d50be94 feat(tarefas): colaboradores por registar aparecem na lista
2710fa4 fix(kpis): tesouraria usa o historico mensal preenchido a mao
3db013b fix(ui): cabecalho cortado, avisos escondidos e ecra vermelho do cliente
e4a8bb0 test(sync): regressoes da carga inicial e da fila concorrente
a8e916b feat(sync): a ficha da empresa insiste ate subir
3c7fe1c feat(subscricao): o limite de colaboradores passa a vir do servidor
3a64e49 docs(testes): checklist viva da campanha de 2 Ago 2026
4dfcb0f fix(sync): sincronização presa, campainha muda e ref inválido pós-microtarefa
5dcc5c5 fix(splash): o punho não gira mais durante a animação de arranque
29aee10 fix(sync): os dados do aparelho nunca subiam, e a fila perdia-se
```

- `_vivo = true` reposto no `build()` do `SyncController` — o motor deixa de
  morrer na primeira reconstrução do provider.
- Campainha: mapa mutável em vez de `const {}`, `try/catch` a envolver o
  `await` (a excepção nascia dentro do future e escapava ao catch de fora).
- Assert do Riverpod: repositório passa a vir de `motor.repositorio` em vez
  de `ref.read` dentro da microtarefa `_montar`.
- Splash declara `portraitJa()` no `initState`.

---

## O que os 8 commits de 13h fizeram — e o que falta confirmar

`flutter test` verde (576 testes, 1 skipped) e `flutter analyze` com 8 avisos
`info` pré-existentes (deprecações do Flutter e chavetas), zero erros. Os
commits foram feitos directamente sobre `main`, como o resto do dia.

Além do que a lista abaixo já descrevia, entraram duas peças novas que **não
foram testadas no aparelho** — só têm testes automáticos:

- `lib/features/auth/data/subscricao_service.dart` +
  `subscricao_providers.dart` — o limite de colaboradores passa a ser
  autorizado pela subscrição no servidor, com o valor do onboarding como
  fallback se a rede falhar. Fecha a implementação, **não** a decisão (ver
  "Por decidir").
- `lib/core/empresa_sync/empresa_sync_controller.dart` + `ficha_pendente.dart`
  — a ficha da empresa insiste até subir: sobrevive a fechar a app, repete de
  20 em 20 minutos e ao voltar do fundo; terminar o onboarding envia logo.

**Por confirmar no Redmi na próxima sessão** (foram corrigidos às cegas, o
aparelho não voltou a ser usado depois):
- Cabeçalho do login/registo com `SafeArea` — era achado P0.
- Aviso de recusa visível com teclado aberto em landscape.
- Gravar cliente duplicado sem ecrã vermelho.
- Ficha da empresa a chegar ao Control depois de fechar a app.

---

## Detalhe do que foi commitado (referência)

`git status` mostra estes ficheiros modificados em `lib/` e `test/` (mais
`docs/PLANO_DE_TESTES_2026-08-02.md`, já actualizado por esta sessão):

- `lib/core/layout/dialogo_de_formulario.dart` — parâmetro `aviso`: mensagem
  de recusa fora do scroll, por cima dos botões (antes ia em `SnackBar`, que
  em telemóvel deitado com teclado aberto nasce escondida).
- `lib/core/operations/kpis.dart` — `tesourariaDoMes` passa a usar
  `historicalMonths` quando preenchido à mão.
- `lib/features/auth/presentation/login_screen.dart`,
  `registo_screen.dart` — `SafeArea` no cabeçalho, cortado pela barra de
  estado.
- `lib/features/empresa/presentation/empresa_page.dart` — copy «em
  preparação para a v0.0.9» → «em preparação».
- `lib/features/operations/presentation/boas_vindas_screen.dart` — «Ready?»
  → «Vamos a isto?»; «o teu tablet» → «o teu ecrã».
- `lib/features/operations/presentation/operational_pages.dart` —
  `_FormularioDeCliente` (`StatefulWidget` dono dos seus
  `TextEditingController`) substitui o diálogo antigo que causava o ecrã
  vermelho ao gravar cliente; aviso de duplicado ligado ao novo parâmetro
  `aviso`.
- `lib/features/tarefas/data/tarefas_service.dart` — tarefa nova «N
  colaboradores por registar».
- `lib/features/workforce/presentation/workforce_pages.dart` — aviso de
  limite de colaboradores ligado ao novo parâmetro `aviso`.
- Testes actualizados: `test/features/dashboard/kpis_test.dart`,
  `test/features/tarefas/tarefas_page_test.dart`.
- Novos, ainda não adicionados ao git: `test/core/sync/carga_inicial_test.dart`,
  `test/core/sync/fila_sem_corridas_test.dart`.

**Fica por resolver:** os diálogos de lead, reserva e marcação continuam com
o padrão antigo de `TextEditingController` (o mesmo bug do ecrã vermelho, que
só foi corrigido no formulário de cliente) — não foram tocados por serem
formulários grandes e a conversão sem testes de UI ser arriscada. Vai rebentar
igual quando alguém os usar.

---

## Decisão já tomada, por implementar agora

Uma máquina alugada deve bloquear **apenas a data ocupada**, não a máquina
inteira. Hoje, uma reserva confirmada deixa a máquina "alugada" e recusa
qualquer nova reserva em **todas** as semanas seguintes, mesmo vazias
(achado 18 do plano de testes). Há testes que fixam o comportamento actual
(`máquina parada não pode receber nova reserva`) — vão precisar de revisão,
não é só mudar a regra de negócio.

---

## Por decidir

Se o limite de colaboradores activos deve vir da subscrição no servidor
(`limite_colaboradores_ativos`) ou continuar a vir do que o gestor declara no
onboarding. Hoje vem só do onboarding — a regra de recusa funciona, mas um
gestor dá-se as vagas que quiser; na empresa de teste o valor real da
subscrição é 1, o declarado é 3.

---

## Achados por corrigir, por urgência (ver detalhe no plano de testes)

**P0 — partem a app ou deixam o painel vazio**

1. Detalhe de cliente não abre — NIF, email, morada e notas chegam do
   servidor mas não há ecrã que os mostre. É o único ecrã que existe para
   máquinas e não existe para clientes; assimetria visível a qualquer
   utilizador.
2. Onboarding não cria colaboradores nem veículos (só as máquinas viram
   placeholders). A frota fica por identificar.
3. Facturação do ano passado não gera `historicalMonths`. **Metade resolvida:**
   o commit `2710fa4` fez os KPIs *lerem* o histórico quando existe; quem o
   *escreve* a partir da facturação continua a não escrever, por isso o painel
   ainda fica em "Por apurar" com o onboarding 100% preenchido.

**P1 — risco técnico e decisões que bloqueiam**

4. Diálogos de lead, reserva e marcação com o padrão antigo de
   `TextEditingController` — mesmo bug do ecrã vermelho, por rebentar.
5. Máquina alugada bloqueia todas as semanas seguintes (secção acima).
6. Limite de colaboradores: decisão por fechar (secção acima).
7. Rotação de ecrã indevida — a do splash foi corrigida em `5dcc5c5`; falta
   reproduzir em que outro ecrã ainda acontece.

**P2/P3 — incomodam, não travam**

8. Máquinas com referência perdem o nome no selector de reservas (as 15
   placeholders "Máquina N" enterram as reais).
9. Ordem das listas de despesas e clientes não segue data nem alfabeto.
10. "Recomendação do dia: Quarta-feira fraca" num domingo — confirmar a
    regra do dia da semana.
11. PIN 1234 por pôr (arrastado do relatório de 1 de Agosto).

**Testes por executar** (não são bugs): Faixa C ponto 5 (documentos, só se faz
em Windows) e Faixa D (uma verificação no Control por **cada** empresa nova —
só houve uma).

---

## Passo imediato ao retomar

1. Instalar a build actual no Redmi e confirmar os quatro pontos da lista
   "Por confirmar no Redmi" acima. São correcções feitas às cegas; até serem
   vistas no aparelho não contam como fechadas — o cabeçalho do login era P0.
2. Perguntar ao Cesar as duas decisões em aberto antes de mexer no código
   que dependem delas: limite de colaboradores (subscrição vs onboarding) e
   se o bloqueio por data da máquina alugada já está em curso por outro
   agente.
3. Atacar os P0 por ordem: detalhe de cliente, depois onboarding a criar
   colaboradores e veículos, depois a escrita de `historicalMonths`.

**Como trabalhar aqui:** builds, `flutter analyze`, `flutter test` e APK no i9
(ver `CLAUDE.md` na raiz). `git add` explícito por ficheiro, nunca `-A`.
Commits vão directos a `main`. Publicar (APK + Release + `versoes_apps`) só a
pedido explícito do Cesar.

---

## Estado dos push notifications (ainda válido)

Trigger `trg_notificar_novo_pedido_punho` (`AFTER INSERT` em
`punho_pedidos_acesso`) confirmado a funcionar em produção: para a empresa
de teste desta campanha, `enviar-push` devolveu 200 três segundos depois do
pedido de acesso, e o Cesar aprovou no Control um minuto depois. Task #196
permanece fechada.

---

## Dados de teste deixados no servidor

Empresa **Lavandaria Mare Alta** (`1a267759-…`), conta
`cesarmendes78+punhoteste@gmail.com` / `MareAlta2026`, com 36 operações
semeadas mais alguns registos criados pela app durante os testes
(`Teste Duplicados`, `Campainha Teste`, `Cliente Sino`, `Lavadora 8 kg`,
colaboradora `Ana Ferreira`, uma reserva confirmada em 29/07). Apagar quando
a empresa deixar de servir para testes.
