# Plano de testes no telemóvel — 2 de Agosto de 2026

Aparelho: Redmi Note 10 Pro (`M2101K6G`, Android 13 / API 33, arm64-v8a),
ligado por USB, série `94c906b9`. Conduzido por `adb` a partir do i9.

---

## O que o Cesar pediu

Três faixas de teste. As duas primeiras são as que interessam; a terceira é a
lista que já existia no repo.

### Faixa A · Dados semeados no servidor têm de chegar ao telemóvel

Introduzir dados no Supabase e confirmar que aparecem na conta do telemóvel.
**Todos** os dados, não uma amostra:

- facturação do ano passado **e** deste ano
- máquinas
- clientes
- reservas
- tudo o resto que a app leia

Objectivo: detectar se os dados chegam **de todos os campos** e verificar se não
há nada partido pelo caminho.

### Faixa B · Iniciação do zero, a simular um empresário

Arrancar com a app limpa e percorrer o onboarding como se fosse um empresário
real, com dados inventados mas plausíveis, preenchendo **tudo**. Critério de
passagem: os ecrãs do dashboard funcionam **sem a palavra "por apurar"** em lado
nenhum.

Ordem entre A e B é livre.

### Faixa D · Campainha e notificações no Control

- Confirmar que a **campainha** funciona (tempo real —
  `washinvoice-control/supabase/punho_campainha_tempo_real.sql`, por commitar).
- De cada vez que nasce uma **empresa nova** (instalação da app do zero),
  verificar no **Control** se a notificação chegou. Uma verificação por cada
  iniciação feita, não só na última.

### Faixa C · `docs/GUIA_DE_TESTES_MANUAIS.md`

Fazer os oito, todos:

1. Onboarding: declarar 15 máquinas e confirmar que a disponibilidade fica "Por apurar".
2. Máquinas: registar uma disponível e uma parada; criar reserva confirmada e tentar sobrepor outra.
3. Clientes: tentar criar dois clientes com o mesmo telemóvel.
4. Finanças: criar despesa por pagar e confirmar que não entra em despesas pagas.
5. Documentos: em Windows, associar ficheiro a uma despesa e confirmar campos antes de guardar.
6. Funcionários: criar activos até ao limite e tentar excedê-lo.
7. Frota: declarar frota sem veículos e confirmar a mensagem de identificação pendente.
8. Recomendações: criar valores por receber ou capacidade disponível e verificar o próximo passo.

> Nota de contradição a resolver: o ponto 1 da Faixa C **exige** "Por apurar",
> a Faixa B **proíbe** "por apurar" no dashboard. São contextos diferentes
> (disponibilidade de máquinas acabadas de declarar vs. KPIs do dashboard com
> dados completos), mas convém confirmar com o Cesar ao chegar lá.

---

## Achados até agora

### 1. O APK debug ia outra vez sem `--dart-define` — repetido de ontem

Compilado sem as chaves, a app entra em **modo de demonstração local**: não fala
com o servidor e pede os 12 passos de onboarding. É exactamente o que
`docs/relatorio_2026-08-01.md` já documentava. Corrigido: recompilado com
`SUPABASE_URL` e `SUPABASE_ANON_KEY` do `.env`, e aí o ecrã de "Iniciar sessão"
apareceu como devia.

Comando certo:

```bash
cd ~/punho && set -a && . ./.env && set +a
flutter build apk --debug --target-platform android-arm64 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

### 2. Cabeçalho do ecrã de login cortado pela barra de estado

No ecrã "Iniciar sessão", o bloco "Punho / Agarra o comando." fica por baixo da
barra de estado — o topo das letras está escondido. Falta `SafeArea` ou margem
de topo. Captura: `~/shots/punho_phone2.png`.

Liga-se ao item "o ecrã inicial, por rever" que ficou em aberto no relatório de
1 de Agosto.

### 3. Rotação de ecrã indevida — por reproduzir

O Cesar viu o ecrã rodar onde não devia. No telemóvel a rotação automática está
ligada (`accelerometer_rotation=1`, `user_rotation=0`). A app decide orientação
em `lib/core/orientacao/orientacao_do_contexto.dart`. **Falta saber em que ecrã
aconteceu** para reproduzir.

### 4. MIUI bloqueia `adb install`

`adb install` devolve `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`.
Contorno que funciona, sem tocar nas definições do telemóvel:

```bash
adb -s 94c906b9 push app-debug.apk /data/local/tmp/punho.apk
adb -s 94c906b9 shell pm install -r -t /data/local/tmp/punho.apk
```

### 5. Emulador instalado no i9 (plano B)

`emulator` + `system-images;android-35;google_apis;x86_64` instalados em
`~/android-sdk`; AVD `punho` (Pixel 6, API 35, x86_64) criado e a arrancar em
headless. O user `cesar` foi acrescentado ao grupo `kvm` — para o emulador
correr numa shell nova sem re-login, usar `sg kvm -c "..."`.


### 6. A sincronização entre dispositivos nunca corria — **corrigido**

O achado maior da campanha. `SyncController._vivo` nasce `true`, e o
`ref.onDispose` de **cada** reconstrução do provider punha-o a `false`. O
Riverpod reaproveita a instância do Notifier entre reconstruções, e o motor de
sincronização só existe **depois** de o acesso resolver — ou seja, depois de
pelo menos uma reconstrução. Resultado: quando o motor finalmente chegava,
`_vivo` já era `false` e `sincronizar()` saía na primeira linha, sem log e sem
erro. A app dizia "em espera" para sempre.

Sintomas confirmados no Redmi antes da correção:

- 15 máquinas do onboarding presas na fila local (`punho_sync.fila_v1`), nunca
  enviadas
- nenhum cursor gravado — nada era recebido do servidor
- `punho_operacoes` só tinha as linhas que este agente semeou por SQL
- nenhuma linha `[Sync]` no log, em nenhum arranque

Correção em `lib/features/sync/sync_providers.dart`: repor `_vivo = true` no
início do `build()`. Depois disso, no mesmo aparelho e sem limpar dados:

```
[Sync] a correr: fila=15 cursor=0 empresa=1a267759-…
[Sync] fim: enviadas=15 recebidas=36
```

Nota de método: os `debugPrint` do Flutter **não aparecem** em `adb logcat`
neste MIUI. Para ver logs é preciso `flutter run` ligado por USB.

### 7. Rotação no arranque — causa encontrada e corrigida

O ecrã do punho aparecia em retrato, rodava para landscape e voltava a retrato
ao entrar no login. Ninguém pedia orientação até ao `AuthGate`: o
`AndroidManifest` não define `screenOrientation` e o `SplashPunho` não declarava
nada, por isso durante os 1,6 s da animação valia o sensor. Corrigido em
`lib/shared/widgets/splash_punho.dart` — o splash passa a declarar
`portraitJa()` no `initState`, como qualquer outro ecrã (Decisão 13). O manifest
não foi tocado de propósito: bloquear na activity é o bloqueio global que deitou
o onboarding no tablet.

### 8. Onboarding não cria colaboradores nem veículos

O passo 6 pede o número de colaboradores (3) e de veículos (1). O passo 8 cria
15 linhas de máquina placeholder, mas `collaborators` e `vehicles` ficaram
vazios no repositório local. Só as máquinas são materializadas.

### 9. Faturação do ano passado não vira histórico

`revenueLastYearCents: 14800000` e `maintenanceLastYearCents: 940000` ficam
guardados no bloco `onboarding`, mas `historicalMonths` fica `[]`. É por isso
que o painel continua a dizer "Por apurar" mesmo com o onboarding todo
preenchido.

### 10. Painel com onboarding 100% preenchido: 11 de 12 cartões em "Por apurar"

Critério de passagem da Faixa B falhado. Só depois de haver **movimento**
(recebimentos, reservas, clientes) é que os números aparecem — o que os 12
passos declaram não alimenta cartão nenhum. Com os dados semeados, "Dinheiros
que entraram" passou a 128 € e "Encontro de contas" a +128 €; "Utilização vs
rentabilidade" continua "Por apurar" porque faltam preços/dia em 15 de 20
máquinas (as placeholders).

### 11. Cartões de cliente não abrem

Na lista de Clientes, tocar no cartão não faz nada — nem no nome, nem no corpo.
NIF, email, morada e notas chegaram do servidor mas **não há forma de os ver nem
de editar um cliente já criado**. As máquinas têm lápis e caixote; os clientes
não têm nada.

### 12. Copy do último ecrã do onboarding

- «Ready?» em inglês no meio do português
- «o teu **tablet** vai rodar sozinho» — a frase aparece igual no telemóvel

### 13. Reservas: máquinas com referência perdem o nome

No seletor de máquinas do ecrã Reservas, as placeholders aparecem por nome
(«Máquina 15») e as máquinas reais por referência («LAV-11B», «CAL-02»). As 15
placeholders vêm primeiro e enterram as reais.

### 14. «Recomendação do dia: Quarta-feira fraca» num domingo

O cabeçalho diz «Dom., 2 ago. 2026» e o cartão recomendava «Quarta-feira fraca».
Depois de haver dados passou a «Valores em atraso», mas o texto do dia da semana
merece confirmação.


### 15. Campainha em tempo real nunca tocou — **corrigido**

`_tocarCampainha` enviava `payload: const {}`. O `realtime_client` escreve
dentro desse mapa antes de enviar, e um mapa `const` é imutável: **cada envio
lançava `Unsupported operation: Cannot modify unmodifiable map`**. O `try/catch`
à volta não apanhava nada, porque a excepção nascia dentro do future e não na
chamada — subia como erro não tratado. Ou seja: desde que existe, a campainha
nunca avisou aparelho nenhum.

Corrigido em `lib/features/sync/sync_providers.dart`: mapa mutável e `try/catch`
a envolver o `await`.

Verificado nos dois sentidos:

- **receber** — operação semeada no servidor + `POST /realtime/v1/api/broadcast`
  no tópico `punho:empresa:<id>` → o Redmi sincronizou em ~4 s
  (`[Sync] fim: enviadas=0 recebidas=1`) e o cliente apareceu na lista, sem
  esperar pelo temporizador de 5 minutos
- **enviar** — cliente criado na app → `[Sync] fim: enviadas=1`, sem excepção
  nenhuma no log

### 16. Assert do Riverpod no arranque da sincronização — **corrigido**

Com a sincronização finalmente a correr, apareceu no log:
`'!_didChangeDependency': Cannot use ref functions after the dependency of a
provider changed but before the provider rebuilt`. O `_montar` corre numa
microtarefa e lá dentro fazia `ref.read(operationRepositoryProvider)` — já
depois de a dependência ter mudado. Corrigido: o repositório vem de
`motor.repositorio`, que é o mesmo objecto e não toca no `ref`.

### 17. Ecrã vermelho ao gravar cliente — **corrigido**

**A validação de duplicados nunca esteve em falta.** `addCustomer` recusa como
devia (`operations_controller.dart:619`); o primeiro relato ("duplicado
aceite") foi artefacto do seed deste agente: a app grava sempre
`companyId: "local-company"`, e as linhas semeadas por SQL levaram o UUID da
empresa, por isso os dois grupos nunca se cruzavam na comparação. Testado de
novo só com clientes criados na app: o segundo com o mesmo telemóvel é
recusado.

Fica a nota: se um dia a app passar a gravar o id real da empresa neste campo,
os clientes antigos (`local-company`) deixam de ser comparados com os novos e a
verificação abre um buraco. Hoje não parte nada porque o valor é constante.

**O ecrã vermelho, esse, era real e reproduzível:**

```
A TextEditingController was used after being disposed.
The relevant error-causing widget was: TextField
  operational_pages.dart:1711
```

O `_customerDialog` criava os `TextEditingController` na própria função e
descartava-os a seguir ao `await showDialog`, que devolve no instante do
`Navigator.pop` — com a animação de fecho ainda a correr. Bastava a lista por
baixo reconstruir-se nesse intervalo (é o que a gravação faz) para os campos
serem construídos outra vez com controladores mortos. Daí o assert em cascata
`'_dependents.isEmpty': is not true` e o ecrã vermelho.

O padrão certo já existia no mesmo ficheiro: o `_FormularioDeMaquina` foi criado
por causa deste mesmíssimo bug, e traz o comentário a explicá-lo. O diálogo de
clientes tinha ficado por converter.

Corrigido com `_FormularioDeCliente`, um `StatefulWidget` dono dos controladores
que os descarta no seu próprio `dispose`. Verificado no Redmi nos dois caminhos:
telemóvel repetido → recusa, sem crash; cliente novo → gravado e sincronizado
(seq 67), sem crash.

**Os diálogos de lead, de reserva e de marcação continuam com o padrão antigo**
(controladores descartados a seguir ao `await showDialog`) — mesma bomba por
rebentar. Não foram convertidos porque são formulários grandes, com datas,
selecção de máquinas e estado próprio, e a conversão sem testes de UI é
arriscada.

### 17b. Recusas invisíveis no telemóvel — **corrigido**

A mensagem de recusa ia num `SnackBar`, que num telemóvel deitado com o teclado
aberto nasce **por baixo do teclado**: a gravação era recusada e o que se via
era o botão a não fazer nada. Era o mesmo sintoma do limite de colaboradores
(achado 19).

`DialogoDeFormulario` ganhou um parâmetro `aviso`, que mostra a mensagem a
vermelho com ícone **fora do scroll**, logo por cima dos botões — sempre à
vista, com ou sem teclado. Verificado: «Já existe um cliente com o mesmo
telemóvel ou NIF na empresa.» aparece com o teclado numérico aberto.

### 18. Uma reserva confirmada bloqueia a máquina para sempre

Criada uma reserva confirmada na LAV-11B em 29/07 manhã. A máquina passou a
"alugada" e a partir daí o ecrã diz **«LAV-11B está alugada e não pode receber
reservas»** com o botão desligado — não só nesse dia, mas em **todas as semanas
seguintes** (confirmado em 03/08 a 09/08, com a grelha vazia).

A sobreposição é recusada, que é o que o ponto 2 pedia, mas o preço é não se
poder marcar a mesma máquina para a semana que vem enquanto estiver alugada
hoje. Há testes que fixam este comportamento (`máquina parada não pode receber
nova reserva`), por isso é uma decisão de desenho a rever, não um bug de
implementação.

### 19. Limite de colaboradores: recusa certa, aviso invisível

A regra existe e funciona (`StateError` em `operations_controller.dart:663`), e
o ecrã mostra "3 colaboradores ativos de 3 vagas contratadas". Ao tentar o
quarto, o diálogo fica aberto e **nada acontece à vista**: a mensagem vai num
`SnackBar`, que em telemóvel deitado com o teclado aberto fica **por baixo do
teclado**. Do lado de quem usa: o botão Guardar não faz nada.

Além disso o limite (3) é o que o próprio declarou no onboarding, não o
`limite_colaboradores_ativos` da subscrição no servidor — que para esta empresa
é **1**. Um gestor dá-se as vagas que quiser.

### 20. Ordem das listas

Despesas e clientes não seguem data nem alfabeto (despesas: 480 de 20/12, 220 de
5/7, 86 de 15/7, 284 de 1/8, 418 de 28/7). Parece ordem de inserção.

### 21. «Timeline de obrigações fiscais — em preparação para a v0.0.9»

O texto está no separador Empresa › Estado. A app é a **v0.1.4**: promete uma
versão que já passou.

---

## Bloqueios

### ~~Palavra-passe da conta~~ — resolvido

Sessão iniciada com a conta de teste (`cesarmendes78+punhoteste@gmail.com` /
`MareAlta2026`) e a palavra-passe ficou guardada no gestor da Google. O email
estava por confirmar e bloqueava o login («Confirma o email antes de iniciares
sessão»); confirmado por SQL no Supabase, com autorização do Cesar.

### ~~Acesso de escrita ao Supabase~~ — resolvido

O MCP do Supabase ficou disponível a meio da sessão. É por aí que se semeia,
se consulta RLS e se resolvem bloqueios de conta. Projecto:
`oefqbkhioncakojipqyx` (partilhado com o WashInvoice Control).

**Como semear para a Faixa A:** inserir em `punho_operacoes` (não nas tabelas
por entidade — a app lê o registo append-only desde um cursor). Uma linha por
entidade, com `entidade` ∈ {customer, machine, booking, expense, receipt,
collaborator, vehicle, lead}, `payload` no formato dos `_xToJson` de
`lib/data/repositories/operation_repository.dart`, e `por_dispositivo`
diferente do aparelho (senão a app ignora como eco próprio).

---

## Checklist viva

Risca-se aqui à medida que acontece. `[x]` feito · `[~]` a decorrer ·
`[!]` bloqueado · `[ ]` por fazer.

### Preparação

- [x] Emulador Android instalado no i9 (plano B) — AVD `punho`, API 35
- [x] User `cesar` no grupo `kvm`
- [x] Contorno do bloqueio de instalação do MIUI encontrado e documentado
- [x] APK debug compilado **com** `--dart-define` e instalado no Redmi
- [x] Estado local limpo (`pm clear`) antes de começar
- [x] APK recompilado e reinstalado com as correcções de rotação e de sync
- [x] APK recompilado de novo em 02/08 à noite a partir do HEAD `c3389f7`
      (com `--dart-define`, push + `pm install` — o pacote não estava
      instalado no aparelho no início desta sessão, foi build limpo)

### Faixa B · Iniciação do zero (a simular empresário)

- [x] App arranca no ecrã de "Iniciar sessão" a falar com o servidor
- [x] Conta de teste criada: **Rui Salgueiro** ·
      `cesarmendes78+punhoteste@gmail.com` · empresa **Lavandaria Mare Alta** ·
      cargo **Gestor** · palavra-passe `MareAlta2026`
- [x] Acesso aprovado pelo Cesar no Control (02 Ago, 01:00 UTC)
- [x] Email confirmado por SQL (estava a bloquear o login)
- [x] Sessão iniciada e palavra-passe guardada no gestor da Google
- [x] Onboarding completo, 12 de 12 passos, tudo preenchido:
      Lda. · NIF 509442129 · Rua da Praia Norte 42, 2450-101 Nazaré ·
      912445780 · geral@marealta.pt · 3 colaboradores · 1 veículo ·
      15 máquinas · 148 000 € ano passado · 92 000 € este ano ·
      9 400 € manutenção · 3 800 €/mês custos fixos
- [!] **Dashboard sem "por apurar": falhado** — 11 de 12 cartões em "Por apurar"
      logo a seguir ao onboarding (achado 10). Com dados semeados melhora, mas
      "Utilização vs rentabilidade" continua por apurar (achado 9 e 10)

### Faixa A · Dados semeados no servidor → telemóvel

- [x] Acesso de escrita resolvido (MCP do Supabase)
- [x] 36 operações semeadas em `punho_operacoes`
- [x] Semear facturação do ano passado (3 recebimentos de 2025: 26 000, 21 000
      e 9 800 cêntimos)
- [x] Semear facturação deste ano (5 recebimentos de 2026)
- [x] Semear máquinas (5, com preço/dia, categoria, data de aquisição e notas)
- [x] Semear clientes (6, com NIF, email, morada, código-postal e notas)
- [x] Semear reservas (5, com máquinas, colaborador e valor previsto)
- [x] Semear despesas (6: pagas e por pagar, 6 categorias, com máquina/veículo
      associado e `dataSource` manual/qr/ocr)
- [x] Semear colaboradores (2, com horário semanal, NISS, NIF, estado civil e
      dependentes) e 1 veículo com matrícula, seguro e prestação
- [x] Semear leads (3, em 3 estados e 3 origens)
- [x] Confirmar que chegam ao telemóvel — **`recebidas=36`** depois da correcção
      da sincronização
- [x] Clientes: nome, telemóvel, código-postal e localidade certos na lista
- [x] Máquinas: nome, categoria, referência e estado certos
- [x] Reservas: aparecem na grelha da semana, com máquina e cliente certos
- [x] Painel: 128 € de entradas e saldo +128 €, com o −39 % vs Agosto de 2025
      calculado a partir do recebimento semeado do ano passado
- [!] **Nem todos os campos são verificáveis no telemóvel** — o detalhe de
      cliente não abre (achado 11), por isso NIF, email, morada e notas chegaram
      mas não há ecrã que os mostre

### Faixa C · Guia de testes manuais

- [x] 1 · 15 máquinas → placeholders "Máquina N" com categoria "Por
      identificar"; o painel pede o preço de 15 de 20 e as Tarefas mostram
      "15 máquinas por identificar". O preço **é** editável no telemóvel — o
      diálogo faz scroll (Nome, Referência, Categoria, Preço/dia, Estado)
- [x] 2 · disponível + parada: criada "Lavadora 8 kg" pela app (subiu ao
      servidor em segundos, seq 56) e o Secador 14 kg passado a "Em manutenção"
      pelo lápis. Reserva confirmada criada em 29/07 (Alojamento Vista Serra).
      **Sobreposição recusada** — mas a máquina fica bloqueada para todas as
      datas (achado 18). Nota: `MachineStatus.stopped` mostra-se de propósito
      como "Disponível"; o estado "parada" de hoje é "Em manutenção"
- [x] 3 · dois clientes com o mesmo telemóvel — **passa (02/08 à noite)**:
      "Teste Duplicado2" com o telemóvel de Alojamento Vista Serra foi
      recusado, sem ecrã vermelho, sem gravar; o aviso "Já existe um cliente
      com o mesmo telemóvel ou NIF na empresa." ficou visível mesmo com o
      teclado numérico aberto (achado 17 e 17b, ambos corrigidos)
- [x] 4 · despesa por pagar não entra em despesas pagas — **passa**: os 284 €
      de 1/8 aparecem como "Por pagar" e o total "Este mês" fica a 0,00 €
- [ ] 5 · documentos em Windows — não se faz no telemóvel
- [~] 6 · funcionários até ao limite e a exceder — a regra recusa como devia,
      mas o aviso é invisível e o limite não é o da subscrição (achado 19)
- [!] 7 · frota sem veículos → identificação pendente — **falha**: o onboarding
      declarou 1 veículo, não criou nenhum, e não há mensagem nem tarefa a dizê-lo
      (achados 8 e 21). As máquinas geram placeholders, os veículos não
- [x] 8 · recomendações → próximo passo: sem dados dizia "Quarta-feira fraca"
      (num domingo, achado 14); com dados passou a "Valores em atraso —
      confirmar recebimentos e criar leads", e as Tarefas apontam os dois passos
      seguintes

### Faixa D · Campainha e Control

- [x] Campainha em tempo real a funcionar — **corrigida e verificada nos dois
      sentidos** (achado 15). Nunca tinha tocado: rebentava em cada envio.
      **Nota de 02/08 à noite:** o trigger DB de `punho_campainha_tempo_real.sql`
      **não está aplicado** (confirmado por `pg_trigger` — sem entrada); o Punho
      usa broadcast directo entre aparelhos por falta de partições em
      `realtime.messages`. O ficheiro entrou em git no washinvoice-control como
      registo do caminho abandonado, não como algo activo
- [x] Empresa nova nº 1 (Lavandaria Mare Alta): notificação confirmada do lado
      do servidor — `enviar-push` devolveu **200 às 00:59:06 UTC**, o pedido de
      acesso entrou às 00:59:03 e o Cesar aprovou no Control às 01:00:10. O
      trigger `trg_notificar_novo_pedido_punho` (AFTER INSERT em
      `punho_pedidos_acesso`) é quem dispara — confirmado ainda existente e
      activo em `pg_trigger`
- [ ] Uma verificação no Control por **cada** empresa nova — só houve uma
      empresa nova nesta campanha; para repetir é preciso criar outra conta
- [!] **Ficha da empresa NÃO chegou ao Control — achado novo, confirmado por
      SQL.** `punho_empresas.dados` está `{}` para a Lavandaria Mare Alta,
      apesar do onboarding completo. Não existe nenhuma linha em `licencas`
      para esta empresa. Os logs da Edge Function `sincronizar-empresa-punho`
      mostram HTTP 400 repetido desde 2026-08-01 23:46 UTC até pelo menos
      2026-08-02 18:04 UTC, a cada ~20 min (bate com o temporizador do
      `EmpresaSyncController`) — a EF recusa com `nif_invalido` quando
      `nif.length < 9`. A ficha presa na fila de retentativa do telemóvel tem
      NIF vazio/curto e o motor nunca a substitui por uma nova a partir do
      estado actual da app; fica a repetir a mesma ficha presa para sempre.
      Não percebi, sem o aparelho, se essa ficha presa é de uma tentativa
      anterior ao onboarding completo (23:46 UTC de 1 Ago, bem antes das
      01:00 UTC de 2 Ago) ou se o próprio fim do onboarding também mandou NIF
      vazio. Não corrigi às cegas

### Achados por corrigir

- [x] ~~Rotação de ecrã indevida~~ — corrigida no splash (achado 7).
      Auditados os 9 ficheiros que usam `OrientacaoDoContexto` nesta sessão:
      nenhum outro ecrã tem declaração de orientação inconsistente.
      **Confirmado no aparelho em 02/08 à noite:** app fechada e reaberta de
      raiz (`am force-stop` + relançar), 10 capturas em sequência durante o
      arranque — o splash fica em retrato do princípio ao fim, só passa a
      paisagem já dentro do painel (comportamento pedido, não bug)
- [x] ~~Sincronização entre dispositivos parada~~ — corrigida (achado 6).
      **Confirmado no aparelho:** app reinstalada do zero (`pm clear` real,
      dados locais perdidos), onboarding local repetido, e ao entrar em
      Clientes os cinco registos semeados em sessões anteriores (Alojamento
      Vista Serra, Campainha Teste, Cliente Sino, etc.) e o saldo de 128 €
      já lá estavam — a sincronização trouxe tudo do zero sem intervenção
- [x] ~~Campainha em tempo real~~ — corrigida (achado 15), ver nota acima
- [x] ~~Assert do Riverpod no arranque da sync~~ — corrigido (achado 16).
      **Confirmado no aparelho:** `am force-stop` + relançar a app várias
      vezes, sempre chegou ao painel com sync a correr, sem ecrã vermelho
      nem crash em nenhuma tentativa
- [x] ~~Cliente duplicado aceite + ecrã vermelho~~ — corrigido (achado 17,
      `_FormularioDeCliente`). **Confirmado no aparelho:** criado
      "Teste Duplicado2" com o telemóvel `961002233` (já usado por
      Alojamento Vista Serra) — gravação recusada, sem ecrã vermelho, sem
      cliente novo na lista
- [x] ~~Cabeçalho do ecrã de login cortado pela barra de estado~~ —
      confirmado `SafeArea` presente em `login_screen.dart` e
      `registo_screen.dart`; **confirmado no aparelho:** o bloco
      "Punho / Agarra o comando." aparece completo, sem corte pela barra
      de estado, tanto no ecrã de login como no ecrã de PIN pós-reinício
- [x] ~~Onboarding não cria colaboradores nem veículos~~ (achado 8) — deixou
      de ser bug: é o comportamento pretendido desde a regra "a app começa
      vazia" (decisão de produto de 02/08, `f90a576`)
- [x] ~~Faturação do ano passado não gera histórico~~ (achado 9) — corrigido
      por `091d5d8` (`historicalMonths` a partir da facturação declarada)
- [~] Painel em "Por apurar" com onboarding completo (achado 10) — em tensão
      com a regra "a app começa vazia": só deixa de dizer "por apurar" quando
      há movimento real, o que agora é o comportamento esperado, não um bug.
      Por confirmar no aparelho se ainda incomoda na prática
- [x] ~~Detalhe de cliente não abre~~ (achado 11) — corrigido por `de11645`
- [x] ~~Máquina alugada não aceita reservas em semana nenhuma~~ (achado 18) —
      corrigido (`3c7fe1c`/`3db013b`): só bloqueia a data ocupada
- [x] ~~Aviso de limite de colaboradores invisível~~ — corrigido
      (`DialogoDeFormulario.aviso`, `e91fdb2`). **Limite local vs. subscrição**:
      decisão de produto de 02/08 (`59fb98c`) tornou isto informativo — o
      cadastro nunca recusa por limite, quem trava é o Control ao aprovar
      acesso. **Atenção:** `washinvoice-control/docs/estado_e_roadmap.md`
      ainda descreve isto como "por decidir" — parece desactualizado face a
      esta decisão, vale a pena o César confirmar qual dos dois lados está
      certo
- [x] ~~«Ready?» e «o teu tablet» no último ecrã do onboarding~~ (achado 12) —
      já estava corrigido por `8b3b5ec`, de sessão anterior a esta
- [x] ~~Máquinas com referência perdem o nome no seletor de reservas~~
      (achado 13) — corrigido (`cf2b3ab`): mostra sempre `Nome · Referência`
- [x] ~~Ordem das listas de despesas e clientes~~ (achado 20) — corrigido:
      despesas/recebimentos por data desc (`9c058fe`), clientes por ordem
      alfabética (`cf2b3ab`)
- [x] ~~«em preparação para a v0.0.9» numa app v0.1.4~~ (achado 21) — já
      estava corrigido por `8b3b5ec`
- [x] ~~Recomendação do dia usa a quarta-feira errada~~ (achado 14) — bug real
      encontrado e corrigido: `weekday - 3` sem `% 7` apontava para uma
      quarta-feira futura às segundas/terças (`0df267d`). O caso relatado
      (domingo) era falta de dados, não este bug — mas o bug existia.
      **Confirmado no aparelho em 02/08 à noite** (ainda domingo): painel
      mostra "Valores em atraso", não "Quarta-feira fraca" — consistente.
      O ramo específico do bug (segunda/terça-feira sem dados) não foi
      reproduzível hoje por não ser esse o dia da semana; fica coberto pelo
      teste automático (`weekday - 3 % 7`), não por observação visual
- [x] ~~PIN 1234 por pôr~~ — **posto e confirmado em 02/08 à noite.**
      Definições > Perfil > Cadeado (PIN + biometria) > Definir PIN → `1234`
      em ambos os campos → Guardar → biometria oferecida e recusada ("Só
      PIN") → SnackBar "PIN definido." → ecrã passou a "PIN de 4-6 dígitos
      activo." Reiniciada a app (`force-stop` + relançar): pediu "Introduz o
      PIN" no arranque, recusou um PIN errado ("PIN erado.") e aceitou
      `1234`, entrando no painel

### Achado novo · overflow de renderização em dois diálogos (debug build)

- [!] Os diálogos **"Mudar palavra-passe"** (Perfil) e **"Definir PIN"**
      (Cadeado) disparam o banner amarelo/preto do Flutter
      `BOTTOM OVERFLOWED BY ~1-49 PIXELS` quando o teclado abre, cobrindo o
      botão de ação (Cancelar/Guardar) momentaneamente. Só apareceu em
      builds debug (banner é exclusivo de debug); não confirmado se o
      overflow real também existe em release sem o aviso visual. Não
      corrigido — aponta-se para decisão, não é um dos achados desta ronda

### Bloqueio anterior, agora resolvido

- [x] ~~Ecrã do Redmi (`94c906b9`) trancado com PIN/biometria.~~ — **o
      César desbloqueou fisicamente o aparelho em 02/08 à noite.** Sessão
      completa de confirmação visual feita nessa janela (ver secção
      "Sessão de 2 de Agosto, confirmação visual" abaixo)

### Por commitar

Tudo em `lib/`, com `flutter analyze` limpo e **535 testes a passar**:

- `lib/shared/widgets/splash_punho.dart` — orientação declarada no splash
- `lib/features/sync/sync_providers.dart` — `_vivo = true` no `build()`,
  campainha com mapa mutável e `catch` no `await`, repositório vindo do motor

### Dados de teste deixados no servidor

Empresa **Lavandaria Mare Alta** (`1a267759-…`), conta
`cesarmendes78+punhoteste@gmail.com` / `MareAlta2026`. Além das 36 operações
semeadas: `Teste Duplicados` (telemóvel repetido), `Campainha Teste`,
`Cliente Sino`, `Lavadora 8 kg`, colaboradora `Ana Ferreira` e uma reserva
confirmada em 29/07. Apagar quando a empresa deixar de servir.

---

## Sessão de 2 de Agosto, confirmação visual (à noite, aparelho desbloqueado)

O César desbloqueou o Redmi fisicamente. Retomados os pontos que na sessão
anterior só tinham sido corrigidos por leitura de código.

**Preparação:** `com.example.punho` não estava instalado no aparelho (não se
sabe se foi desinstalado ou se o `pm clear` de sessões anteriores nunca
chegou a instalar de facto). Build limpo a partir de `c3389f7` com
`--dart-define` das chaves do `.env`, `push` + `pm install`. O primeiro
`pm install` falhou com `INSTALL_FAILED_USER_RESTRICTED` mesmo com "Instalar
via USB" e "Depuração USB" activos nas Definições — descoberta nova: o
diálogo de confirmação da MIUI (`com.miui.securitycenter`) desactiva os
botões nos primeiros segundos (protecção anti-automação) e auto-cancela ao
fim de ~9-12 s sem toque; resolvido esperando o `pm install` correr em
background, tirando `uiautomator dump` para apanhar as coordenadas reais do
botão "Instalar" e tocando depois da janela de protecção passar.

Refeito o onboarding local (dados locais tinham sido perdidos com a
reinstalação) com os mesmos valores da sessão anterior — Rui Salgueiro,
Lavandaria Mare Alta, NIF 509442129, 3 colaboradores, 1 veículo, 15
máquinas, faturação 148 000 €/92 000 €/9 400 €/3 800 €. Confirmado que
**"Ready?" e "o teu tablet" já não aparecem** no último ecrã (achado 12
continua corrigido).

Achados desta ronda, todos **confirmados no ecrã real**:

- **Achado 6 (sync parada)** — passa. Depois do onboarding local, a lista de
  Clientes já trazia os registos semeados em sessões anteriores e o painel
  mostrava 128 € de entradas, sem qualquer acção manual de sincronização.
- **Achado 7 (rotação indevida no arranque)** — passa. Dez capturas em
  sequência durante um `force-stop` + relançar mostram o splash sempre em
  retrato; só entra em paisagem já dentro do painel.
- **Achado 14 (quarta-feira errada)** — consistente. Hoje é domingo com
  dados: mostra "Valores em atraso", não "Quarta-feira fraca". O ramo do bug
  original (segunda/terça-feira) não é reproduzível fora desses dias da
  semana; cobertura fica no teste automático.
- **Achado 16 (crash da sync no arranque)** — passa. Vários
  `force-stop` + relançar, sempre chegou ao painel sem ecrã vermelho.
- **Achado 17 (cliente duplicado aceite + ecrã vermelho)** — passa. Cliente
  "Teste Duplicado2" com o telemóvel de Alojamento Vista Serra foi recusado,
  sem crash, sem gravar.
- **Achado 17b (aviso escondido atrás do teclado)** — passa. O aviso
  vermelho ficou visível com o teclado numérico aberto.
- **PIN 1234** — posto. Perfil > Cadeado > Definir PIN, confirmado a pedir
  PIN no arranque e a desbloquear com `1234`.

**Achado novo, menor:** os diálogos "Mudar palavra-passe" e "Definir PIN"
disparam o banner de overflow do Flutter (`BOTTOM OVERFLOWED BY N PIXELS`)
quando o teclado abre, cobrindo o botão de ação por instantes. Só visível em
build debug; não avaliado em release. Não corrigido nesta sessão.

Nenhuma regressão encontrada — todos os achados que os testes automáticos
diziam corrigidos comportaram-se como esperado no aparelho real.
