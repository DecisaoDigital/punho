# Handover — próxima sessão Cowork · Punho

**Data do handover:** 2 de Agosto de 2026
**Última branch activa:** `main` (sem branch de sprint aberta; há alterações
por commitar directamente sobre `main`, ver abaixo)
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

## Por commitar — verificado no aparelho, `flutter analyze` limpo, 535 testes

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

**Antes de commitar:** os diálogos de lead, reserva e marcação continuam com
o padrão antigo de `TextEditingController` (o mesmo bug do ecrã vermelho,
por rebentar) — não foram tocados nesta sessão por serem formulários grandes
e a conversão sem testes de UI ser arriscada. Não bloqueia o commit do resto,
mas fica registado para não se dar como resolvido.

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

1. Detalhe de cliente não abre — NIF, email, morada e notas chegam do
   servidor mas não há ecrã que os mostre.
2. Onboarding não cria colaboradores nem veículos (só as máquinas viram
   placeholders).
3. Facturação do ano passado não gera `historicalMonths` — painel fica em
   "Por apurar" mesmo com onboarding 100% preenchido.
4. Máquinas com referência perdem o nome no selector de reservas (as 15
   placeholders "Máquina N" enterram as reais).
5. Ordem das listas de despesas e clientes não segue data nem alfabeto.
6. PIN 1234 por pôr (arrastado do relatório de 1 de Agosto).

---

## Passo imediato ao retomar

1. Rever o `git diff` do que está por commitar (lista acima), confirmar que
   nada ficou esquecido a meio, e commitar em Portugal — no i9, com
   `flutter analyze` e `flutter test` a correr limpo antes do commit
   (`git add` explícito por ficheiro, não `-A`).
2. Confirmar com o Cesar se a implementação do bloqueio por data (máquina
   alugada) já está em curso por outro agente ou se falta arrancar.
3. Perguntar se o limite de colaboradores deve passar a vir da subscrição
   antes de mexer em `workforce_pages.dart` outra vez.
4. Seguir pela lista de achados por corrigir acima, começando pelo detalhe
   de cliente (é o único ecrã que existe para máquinas e não existe para
   clientes — assimetria visível a qualquer utilizador).

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
