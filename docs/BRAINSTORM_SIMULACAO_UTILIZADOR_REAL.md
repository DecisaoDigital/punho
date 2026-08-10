# Brainstorm vivo — Testar as apps como um utilizador real durante 3 meses

> Documento de memória futura. Nasceu do brainstorm de **9/8/2026**: como testar a
> fundo o Punho (gestor) e o Punho OP (operador) **como se fossem usados por pessoas
> reais durante 3 meses**. Aqui decide-se *o quê* e *como*. É para **continuar a
> escrever** — cada execução acrescenta achados no fim.

---

## 1. Objectivo

Provar as apps não com um teste de sorriso, mas com o peso de uma empresa que abriu
**há 3 meses** e as usa a sério. Encenam-se **três papéis** ao mesmo tempo:

- **Empresário** (Sr Alfredo) — inscreve-se, mete máquinas, reservas, entregas,
  recolhas e cobranças; vê os KPIs.
- **Contabilista** — recebe o convite, abre o portal, declara os números fiscais dos
  meses anteriores.
- **Auditor** — a cada ecrã: *sei o que devia acontecer*; comparo com o que a app faz
  e altera; se diverge, **corrijo (se o fix é meu) ou tomo nota** e sigo.

O critério de sucesso é a **reconciliação**: os KPIs e o dinheiro que a app mostra têm
de bater com o que o empresário lançou e com o que o contabilista declarou.

---

## 2. Decisões de método (o *o quê*)

- **Cenário temporal**: empresa aberta há 3 meses. Preenchem-se os **3 meses
  anteriores** (histórico) **+ alguma actividade no mês corrente**.
- **Entrada dos dados operacionais = toque a toque na app real**, em 1ª pessoa.
  Porquê e não semear pelo servidor: ver §5 (offline-first). Entrando pela app,
  aparece pela app por construção, e testa-se o caminho de escrita verdadeiro.
- **Contabilista = portal por `curl`** (cadeia provada). Aqui **não** é preciso
  caráter a caráter; valores pré-preenchidos coerentes servem.
- **Valores inventados mas coerentes**: o que o empresário lança nos meses tem de
  ser compatível com o que o contabilista declara nesses mesmos meses.
- **Servidor pristino antes de arrancar** (não herdar dados de corridas anteriores).
- **Lente de auditor sempre ligada** — o objectivo não é a app "responder", é
  fazer o que devia. Mudar de lente (dados feios, perfil trocado, rede desligada)
  quando a persona bem-comportada já não descobre nada.
- **Regra do César (sem colaboradores)**: as empresas registam-se **sem
  funcionários** — o empresário é o **único trabalhador** (`n_colaboradores = 0`).
  Não criar nem convidar contas de colaborador na simulação.

---

## 3. Como executar (descobertas mecânicas) — o núcleo

### 3.1 Ponto de partida virgem (os dois lados)

**Local (telemóvel):** `pm clear` apaga sessão + dados locais da app. Só o telemóvel,
nada no servidor.
```bash
ADB="/home/cesar/Android/platform-tools/adb -s 94c906b9"   # Redmi M2101K6G (MIUI)
$ADB shell pm clear pt.decisaodigital.punho
$ADB shell monkey -p pt.decisaodigital.punho -c android.intent.category.LAUNCHER 1
```

**Servidor (Supabase `oefqbkhioncakojipqyx`):** apagar **só o domínio Punho**. NÃO tocar
em WashInvoice/Control (`clientes`, `licencas`, `versoes_apps`, `admins`, `chaves_mestre`,
`aceites_termos`…). **Preservar** `punho_rubricas_contabilista` (config, 10 rubricas) e
`auth.users` (para haver login). **Gotcha de FK:** os backups `punho_*_copia_YYYY_MM_DD`
apontam para `punho_empresas`, portanto ou entram no mesmo `TRUNCATE` ou é preciso
`CASCADE`. Lista que funciona (9/8/2026):
```sql
TRUNCATE TABLE
  punho_empresas, punho_membros, punho_operacoes, punho_reservas,
  punho_reserva_maquinas, punho_respostas_contabilista, punho_convites_contabilista,
  punho_alteracoes_contabilista, punho_mensagens_contabilista, punho_pedidos_acesso,
  punho_convites, punho_perfis, punho_projeccao_posicao, punho_estado_operacional,
  punho_instalacoes, punho_subscricoes, punho_conflitos_pendentes, punho_erros,
  punho_documentos, punho_campanhas, punho_eventos_auditoria, punho_leads_entrada,
  punho_clientes_copia_2026_08_09, punho_leads_copia_2026_08_09,
  punho_colaboradores_copia_2026_08_09, punho_maquinas_copia_2026_08_09,
  punho_veiculos_copia_2026_08_09, punho_recebimentos_copia_2026_08_09,
  punho_despesas_copia_2026_08_09
  RESTART IDENTITY;
```
Confirmar a zero com `select count(*)` em cada. `TRUNCATE` **não dispara triggers de
linha** (bom: não gera projecções fantasma).

### 3.2 Contas (sem gastar emails)

- Creds de teste vivem em `scratchpad/credenciais.env` e `scratchpad/contas_teste.env`
  (chmod 600). Ex.: `cesarmendes78+punhoteste@gmail.com` / `PunhoOP2026!`.
- Depois de limpar `punho_membros`, **qualquer conta auth fica sem empresa** → ao entrar
  cai no onboarding do zero. Não é preciso conta nova.
- Criar contas sem esbarrar no SMTP (~3/hora): inserir em `auth.users` com
  `extensions.crypt(senha, gen_salt('bf'))` **e pôr a `''`** (nunca NULL) os campos
  `confirmation_token`, `recovery_token`, `email_change*`, `phone_change*`,
  `reauthentication_token`. Ver memória `reference_ambiente-de-ensaio-punho`.

### 3.3 Conduzir a app (toque a toque, com auditoria)

- **Orientação é por activity.** O **login é portrait** (1080×2400, ROTATION_0); o
  dashboard força landscape. **Reverificar `dumpsys window | grep Rotation` a cada
  transição** — as coordenadas viram ao contrário.
- **SelectToSpeakService** (não TalkBack) expõe a árvore de semântica do Flutter sem
  partir os toques. Confirmar/ligar:
  ```bash
  $ADB shell settings get secure enabled_accessibility_services   # ver se já lá está
  # se preciso:
  $ADB shell settings put secure enabled_accessibility_services \
    com.google.android.marvin.talkback/com.google.android.accessibility.selecttospeak.SelectToSpeakService
  $ADB shell settings put secure accessibility_enabled 1
  ```
- **Coordenadas por `bounds`, nunca a olho.** `uiautomator dump` → cada nó traz
  `bounds="[x1,y1][x2,y2]"`; o alvo é o centro. Botões vêm por `content-desc`
  (ex. "Entrar", "Criar conta"); campos por `class="android.widget.EditText"`
  (`password="true"` distingue a palavra-passe).
  ```bash
  $ADB shell uiautomator dump /sdcard/ui.xml && $ADB pull /sdcard/ui.xml .
  tr '<' '\n<' < ui.xml | grep -oE 'content-desc="[^"]*"[^>]*bounds="\[[0-9,]+\]\[[0-9,]+\]"'
  ```
- **O dump NÃO devolve o texto escrito** nos campos Flutter (`text`/`content-desc`
  vêm vazios). Para auditar "o dado ficou no campo certo?" → **screenshot** e leitura à
  vista. Botões e existência de campos: pela árvore. Conteúdo: pelos olhos.
- **Screenshots nunca no thread principal** — delegar a leitura do PNG a um subagente
  `explore` (custaram 793 M tokens uma vez). Pedir-lhe posições em pix['] e textos.
- **`adb input tap/text`** conduz, mas o **MIUI revoga INJECT_EVENTS a meio** → os
  toques passam a falhar em silêncio (sintoma: toque "não faz nada", ecrã não muda).
  **Verificar sempre que landou** (dump/vista) antes de seguir. Duas saídas antes do
  último recurso: (1) **`adb shell input keyevent KEYCODE_BACK` continua a funcionar**
  mesmo quando o tap já caiu — é um caminho de permissão diferente, serve para fechar
  diálogos/bottom-sheets; (2) repetir o toque uma vez (por vezes recupera sozinho). Só
  depois disso, via de recurso: `integration_test` para carregar em botões Flutter
  (memória `feedback_integration-test-em-vez-de-adb-input`).
- **`input text` e caracteres especiais**: `@ . +` normalmente passam entre aspas
  simples; espaço tem de ser `%s`; confirmar `+`/`!` pela vista antes de submeter.
- **Cold-start pós `pm clear` é lento** (splash primeiro). O `sleep` de foreground está
  bloqueado no harness → **pacing por round-trips adb** (um ciclo de `dumpsys`/`echo`
  dá a espera natural) ou `Monitor` com condição.

### 3.4 Contabilista: navegar, convidar, preencher, verificar (portal provado)

#### 3.4.1 Navegação até ao contabilista (rail scrollável)

A barra lateral esquerda do dashboard **é scrollável** — os itens de baixo (Empresa,
KPIs, Tarefas) ficam fora do viewport inicial:
```bash
$ADB shell input swipe 200 950 200 350 300
```
Caminho: rail → **"Empresa"** (ícone *domain*) → página com **7 tabs**: Dados, Regime,
Histórico, Custos fixos, Veículos, Finanças, Estado. O contabilista vive na tab
**"Histórico"** (`historico_contabilista_page.dart`). Aí: botão **"Convidar
contabilista"**; a tab também lista as rubricas — tocar numa abre `RubricaMesesPage`
com os valores por mês (é onde o gestor vê o que foi submetido).

#### 3.4.2 Diálogo "Convidar o contabilista"

- 2 campos no topo: **Nome** (esquerdo, "só para o reconhecer") + **Email** (direito).
- Selector "Quantos anos pedir": **1 / 3 / 5**, default **5**. Para empresa de poucos
  meses escolher **1** (o período termina sempre no mês passado, ex. empresa de 3
  meses → cobre Ago do ano anterior a Jul deste ano).
- Botão **"Criar link"** (topo direito) — é aí que o token aparece, uma única vez.

#### 3.4.3 Arquitetura do link (Tailscale → edge)

O link mostrado já **não é o edge direto**, é um domínio Tailscale que serve de fachada:
```
https://decisaodigital.tailb66396.ts.net/portal/?t=<TOKEN>
```
Essa landing (HTML ~2,5 KB) faz `fetch` ao edge com `&formato=json` e injeta o HTML no
documento — existe porque o Supabase reescreve `text/html`→`text/plain` em
`*.supabase.co` (senão o contabilista via o código-fonte em vez da página). O **portal
real e o destino dos POST é sempre o edge**, função **pública** (sem header de
`Authorization`):
```
https://oefqbkhioncakojipqyx.supabase.co/functions/v1/portal-contabilista?t=<TOKEN>
```
O token só aparece **uma vez** no ecrã (a base guarda só `token_hash`) → apanhar do nó
de texto do `uiautomator dump` no momento em que "Criar link" mostra o link, e guardar
já em ficheiro no scratchpad (`echo "$TOKEN" > scratchpad/token_contabilista.txt`).

#### 3.4.4 Preencher por `curl` (papel do contabilista)

```bash
API="https://oefqbkhioncakojipqyx.supabase.co/functions/v1/portal-contabilista?t=$TOK"
curl -s "$API" -o portal.html                      # GET marca `aberto_em`
curl -s -X POST "$API" -H 'Content-Type: application/json' \
  -d '{"accao":"guardar","rubrica":"facturacao","mes":"2026-07-01","ano":null,"valor":"5.100,00"}'
# -> {"formatado":"5100,00"}
# ... uma chamada POST por rubrica/mês ...
curl -s -X POST "$API" -H 'Content-Type: application/json' -d '{"accao":"submeter"}'
# -> {"ok":true}   (entrega definitiva — fecha o convite)
```
- Rubricas **mensais** (`mes:"YYYY-MM-01"`, `ano:null`): `facturacao`, `resultado`,
  `compras_e_servicos`, `custos_com_pessoal`, `iva_liquidado`, `retencao_irs`.
- Rubricas de **configuração** (`mes:null`, `ano:null`): `cae` (código, ex "77320"),
  `inicio_actividade` (data, ex "2026-05-01"), `periodicidade_iva` (select: "Mensal" /
  "Trimestral" / "Isento / não aplicável"), `regime_contabilidade` (select: "Regime
  simplificado" / "Contabilidade organizada").
- Valor sempre em formato PT: `"3.200,00"` (o servidor faz parse e guarda
  `valor_centavos` + `valor_texto`).
- `"accao":"submeter"` é o passo final — sem ele o convite fica só "aberto", não
  "entregue".

#### 3.4.5 Verificação server-side (SQL)

```
punho_convites_contabilista: id, empresa_id, nome, email, token_hash, mes_inicial,
  mes_final, criado_por, criado_em, expira_em, aberto_em, submetido_em, revogado_em,
  mes_inicial_efectivo
```
Não há coluna "estado" — deriva-se de `aberto_em` / `submetido_em` / `revogado_em`.
```
punho_respostas_contabilista: id, empresa_id, rubrica, mes, ano, valor_centavos,
  valor_texto, origem, convite_id, actualizado_por, criado_em, actualizado_em
```
Confirmar batidas com uma query simples, ex.: `select rubrica, mes, valor_centavos,
valor_texto from punho_respostas_contabilista where empresa_id = '<ID>' order by
rubrica, mes;`.

#### 3.4.6 Refrescar estado na app (autoDispose)

O provider do contabilista é **`autoDispose`**: não relê sozinho. Para ver o estado
atualizado ("Entregue") depois do `submeter` por curl, é preciso **sair da página
Empresa** (tocar outro destino do rail, ex. Clientes) **e voltar** (Empresa →
Histórico). Só aí mostra "Manuela Sousa · Entregue · Ago/2025 a Jul/2026". Não é bug,
mas engana quem testa achando que o POST falhou.

### 3.5 Caminhos e ferramentas

- ADB: `/home/cesar/Android/platform-tools/adb`; device Redmi `94c906b9` (há também
  `emulator-5554` ligado → **sempre `-s 94c906b9`**).
- Pacote gestor: `pt.decisaodigital.punho`; operador: `pt.decisaodigital.punho_operador`.
- Supabase MCP: `execute_sql`/`list_tables` no projecto `oefqbkhioncakojipqyx`.
- Scratchpad da sessão: `.../02b4064b-.../scratchpad` (api.sh, creds, dumps, PNGs).

### 3.6 Editar um campo da empresa de forma fiável (reset + ficha-pull)

Contexto: o gestor é **offline-first**; um telemóvel já onboarded **manda no
local** e a base nunca se sobrepõe — logo editar `empresa.dados` na base **não
chega**. E editar o campo à mão pode ser inviável quando o MIUI está a dropar
toques (§3.3, §4). Solução determinística (funcionou 9/8/2026 para pôr
`n_colaboradores` de 2→0):

1. `adb shell pm clear pt.decisaodigital.punho` — o local passa a
   "não-onboarded".
2. SQL:
   ```sql
   update punho_empresas
   set dados = jsonb_set(dados,'{n_colaboradores}','0'::jsonb),
       updated_at = now(), revision = revision + 1
   where nome = 'Aluguer Nogueira';
   ```
3. Re-login → o `fichaRecebidaProvider`
   (`lib/core/empresa_sync/ficha_recebida_provider.dart`) **puxa a ficha do
   servidor e aplica** (`ficha.aplicarEm`, que mapeia `n_colaboradores`, NIF,
   morada, custos fixos, etc.) — mas **só o faz quando não há nada local**, por
   isso o `pm clear` tem de vir **primeiro**.

- **Bónus**: isto exercita e prova a feature "trocar de telemóvel/reinstalar" —
  após `pm clear` + login a app repôs o perfil do servidor e foi **direta ao
  dashboard, sem repetir o onboarding**. ✓
- **Cuidado**: perde-se o que fosse só local e ainda não sincronizado (ex.: as
  6 linhas de máquina do onboarding — que se reconfiguram a seguir de qualquer
  forma). **Correcção (ver §4)**: para operações já sincronizadas isto não é
  risco — o log append-only repõe tudo sozinho num login novo.

### 3.7 Verificação por SQL em vez de screenshots (grande ganho)

As operações do gestor sincronizam para `punho_operacoes` **quase em tempo real**
(append-only). Colunas: `seq, id, empresa_id, entidade, entidade_id, payload(jsonb),
feito_em`. Entidades: `machine`, `customer`, `booking`, `receipt`. Cada mudança de
estado gera **nova op** (ex.: booking confirmed→rented→completed são 3 ops; contar ops
≠ contar entidades distintas). **Por isso: criar tap-a-tap na app e VERIFICAR por SQL**
(barato), reservando screenshots só para os KPIs (onde o conteúdo não sai por SQL).
```sql
select payload->>'reference', payload->>'name', (payload->>'dailyRateCents')::int
from punho_operacoes o join punho_empresas e on e.id = o.empresa_id
where e.nome = 'Aluguer Nogueira' and entidade = 'machine';
```

### 3.8 Criar máquinas

Máquinas → **"Adicionar máquina"**. Campos (grelha): Nome (esq-cima), "Preço diário de
aluguer (€)" (centro-cima), "Número interno ou série" (esq-baixo), "Valor de compra
(€)-opcional", Estado (dropdown, default Disponível). Categoria/Data não são
obrigatórias. **Preço em euros → guardado ×100 em `dailyRateCents`** (80 → 8000).
Guardar (topo-dir). Lote: reabrir "Adicionar máquina" a cada uma.

### 3.9 Criar clientes

Clientes → **"Novo cliente"**. Só **Nome*** é obrigatório (+ Email, Localidade,
Telemóvel, Morada, CIF opcionais). Entidade `customer`. Lote igual.

### 3.10 Criar reserva (calendário por slots)

Reservas é um calendário semana (Manhã/Tarde por dia). Sequência:
1. dropdown **Máquina** → escolher.
2. tocar célula(s) **"+"** → cada toque adiciona um slot ("Reservar (N)").
3. **"Reservar (N)"** → diálogo "Confirmar reserva": **Cliente** (dropdown, default 1º
   cliente), **Estado inicial** (dropdown: Pedido / Proposta enviada / Confirmada),
   **Valor previsto (€)** (manual, euros → `expectedValueCents`), Notas.
4. **"Gravar reserva"** (topo-dir).

Entidade `booking`. Navegar meses passados: "Período anterior" (uma semana de cada vez)
ou vista "Mês".

### 3.11 Ciclo entrega→recolha→cobrança (em "A minha semana")

O trabalho aparece como cartão. Botões em sequência: **Entregar** (booking→`rented`),
**Fechar trabalho** (→`completed`), **Registar recebimento**. No diálogo de
recebimento: montante **pré-preenchido** com o em dívida, Cliente, "Associar a
reserva", método (default `transfer`), e o botão **Guardar** fica **abaixo** — é
preciso **scroll no bottom-sheet** para o revelar. Entidade `receipt`.

### 3.12 LIMITAÇÃO-CHAVE: recebimentos são sempre de HOJE

`finance_pages.dart:495` cria o `Receipt` com `date: DateTime.now()` — **não há escolha
de data**. Consequência para o modelo de receita (`kpis.dart:244-250`):
- **Meses passados**: receita = **declaração do contabilista**
  (`historicalMonth.revenueReceivedCents`), usada quando não há recebimentos nesse mês.
- **Mês corrente+**: receita = **recebimentos reais** (datados hoje).

Logo NÃO se devem cobrar reservas "no passado" pela app (cairia tudo no mês corrente e
inflava-o). O passado financeiro entra pelo **contabilista**; a app regista dinheiro só
para a frente. Decisão do César (9/8): seguir o modelo da app.

### 3.13 Verificação dos KPIs (reconciliação) — o que é comportamento CORRETO

- CAIXA / "DINHEIROS QUE ENTRARAM" do mês corrente = soma dos recebimentos desse mês.
- **"Sem histórico para comparar" / "primeiro mês com registos" é CORRETO e esperado**
  quando o homólogo (mesmo mês do ano anterior) está em branco — a "cegueira de 12
  meses" que a app avisa. **Não é bug.**
- Nuance de desenho: a comparação da **CAIXA** usa só recebimentos (`kpis.dart:211`),
  enquanto a **tendência de faturação** usa o histórico do contabilista
  (`kpis.dart:250`) — métricas diferentes (dinheiro recebido vs faturado), ambas
  corretas.
- A lista "KPIs (todos)" tem 12 cartões; se o **scroll estiver bloqueado** por input a
  falhar (§3.3/§4), o **Painel** (navegação por toque em "Slide seguinte") é mais
  fiável para ler KPIs no MIUI do que fazer scroll na lista.

### 3.14 Método fiável: emulador como sandbox de 1ª pessoa

- O MIUI (Redmi) revoga `INJECT_EVENTS` a meio (§3.3/§4) → toques falham em silêncio.
  O **emulador** (`emulator-5554`, Android 15) é muito mais fiável: `input tap`/`swipe`
  nunca falham.
- **Build**: tem de ser **UNIVERSAL debug** —
  ```bash
  flutter build apk --debug \
    --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  ```
  (**sem** `--target-platform`). Um APK **arm64-only crasha** no emulador x86 com
  `dlopen failed: libflutter.so is for EM_AARCH64 instead of EM_X86_64` — o `abilist`
  do emulador diz `arm64-v8a` mas engana. O universal (arm64+armeabi+x86_64) corre no
  emulador **e** no Redmi.
- **Instalar**: `adb -s emulator-5554 install -r <apk>` — como o build é debug (mesma
  debug keystore), o `-r` **mantém** a sessão e os dados locais; só troca o código.
  (No Redmi a app instalada é **release**, assinatura `3fcf1935`, sem flag
  `DEBUGGABLE` → `-r` com um APK debug falha por assinatura, obriga a desinstalar
  primeiro.)
- **Login do Alfredo**: `cesarmendes78+punhoteste@gmail.com` / `PunhoOP2026!` (em
  `scratchpad/credenciais.env`). Validar headless antes de tocar no ecrã:
  ```bash
  curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -d '{"email":"...","password":"..."}'   # -> tem access_token?
  ```
- **Auditar o estado ao certo**: o emulador é *debuggable* →
  ```bash
  adb -s emulator-5554 shell run-as pt.decisaodigital.punho \
    cat /data/data/pt.decisaodigital.punho/shared_prefs/FlutterSharedPreferences.xml
  ```
  A chave `flutter.punho.operations.v1` tem o JSON com `machines`/`customers`/
  `bookings`/`receipts`/`historicalMonths`/`sync`. É a forma **determinística** de
  confirmar o que a app tem, em vez de screenshots (§3.3).
- Helper de condução: `scratchpad/tap_emu.sh` (`dump`/`tap_desc`/`tap_edit`/etc,
  sempre contra `emulator-5554`).

---

## 4. Riscos e limitações conhecidas

- **SMTP do Supabase trava o onboarding** (~3 registos/hora) → usar contas já criadas
  ou o truque do `auth.users`.
- **INJECT_EVENTS revogado pelo MIUI** a meio da sessão → toques mudos; mitigação
  parcial: `KEYCODE_BACK` continua a funcionar (fecha diálogos); plano B
  `integration_test`.
- **Instalação por USB no MIUI expira em ~2s** e não se deve intercalar `uiautomator
  dump` no meio (memória `feedback_miui-instalacao-usb-expira`).
- **Offline-first do gestor**: o gestor lê o armazém **local**; semear o servidor pode
  **não aparecer** na vista dele. Por isso a entrada é pela app. (Só o operador lê a
  projecção do servidor.)
- **`punho_projeccao_posicao`**: a projecção pode perder linhas em silêncio (20 vs 8);
  há query de deteção + `punho_reprojectar_empresa`.
- **Input a falhar pode tirar-te da app**: com o INJECT_EVENTS revogado, além
  dos toques caírem, `KEYCODE_BACK` para fechar teclado faz **scroll-to-top**
  do formulário, e swipes/BACK repetidos chegaram a **sair da app do gestor e
  cair na app do operador (Punho OP)**. Mitigações: confirmar sempre o
  foreground com `adb shell dumpsys window | grep mCurrentFocus` depois de
  gestos; para fechar teclado preferir **tocar numa zona vazia** (defocus) em
  vez de BACK; relançar o gestor com
  `monkey -p pt.decisaodigital.punho -c android.intent.category.LAUNCHER 1`
  se saíste.
- **Correcção (9/8/2026): reinstalar/`pm clear` NÃO arrisca perder operações**
  — o `punho_estado_operacional` (snapshot do gestor) fica **vazio** (revisão
  1, zero de tudo; a app só faz *push* para lá, nunca lê de volta), o que
  parecia significar que reinstalar apagava tudo (alarme registado em §3.6).
  Na prática o Punho **re-hidrata do log append-only `punho_operacoes`** num
  login novo (`lib/core/sync/sincronizacao_operacional_por_operacoes.dart`, cursor
  por `seq` desde 0) — provado: 6 máquinas / 4 clientes / 2 reservas / €2.200
  voltaram sozinhas após login num emulador limpo (§3.14). Só
  `historicalMonths` é puramente local (não vai a log) e perde-se no
  reinstall — mas a ponte do contabilista (§5) volta a materializá-lo a
  partir das respostas já submetidas. Continua a valer confirmar antes de
  desinstalar em **release** (o `-r` falhar por assinatura em §3.6 é um
  problema de instalação, não de dados).

---

## 5. Registo de execução (achados) — appendable

### Corrida 1 — Sr Alfredo (Aluguer Nogueira), 9/8/2026 (em curso)

**Persona**: Alfredo Nogueira, empresa *Aluguer Nogueira* (aluguer de máquinas),
NIF 248193066, Loures. Login pelo alias `cesarmendes78+punhoteste@gmail.com`.

**Partida virgem** confirmada dos dois lados (reset total + pm clear).

**Fluxo de entrada de um empresário do zero** (todo provado nesta corrida):
1. **Login** (ecrã portrait) → conta existe mas sem empresa.
2. **"Falta pedir acesso"** → formulário (nome + empresa + papel *Gestor*) → submete →
   **"Pedido em análise"** (fica `pendente` em `punho_pedidos_acesso`).
3. **Aprovação (papel do César/admin)** — pela RPC real, não à mão. Como corro como
   `postgres`, faço-me passar pelo admin numa transação:
   ```sql
   do $$ begin
     perform set_config('request.jwt.claims',
       json_build_object('sub','<ADMIN_UID>','role','authenticated')::text, true);
     perform public.punho_decidir_pedido('<PEDIDO_ID>','aprovar');  -- decisão: 'aprovar'
   end $$;
   ```
   Admin = linha única de `admins` (`9e1bfae1…`). `is_admin()` lê `auth.uid()` das
   claims. A RPC cria `punho_empresas` (nome = empresa_indicada), `punho_subscricoes`,
   `punho_instalacoes`, o `punho_membros` gestor, e marca o pedido `aprovado`.
4. **Reiniciar a app** (force-stop + launch) para reler o acesso → "Bem-vindo, Alfredo".
5. **Onboarding: 11 passos** (forma jurídica+NIF, nº funcionários, nº veículos, contacto,
   morada, porta operacional, nº máquinas, faturação ano passado, faturação este ano,
   manutenção ano passado, custos fixos mensais) → "Está tudo pronto" → **roda p/ landscape**
   → Painel.

**Descobertas de entrada de dados nos formulários:**
- **Steppers** (funcionários/veículos/máquinas): dois botões sem `content-desc`; o da
  **direita é `+`**. Confirmar o número pelo nó de texto do dígito.
- **Campos de dinheiro** (€): recebem **euros inteiros**; a app multiplica ×100 para
  cêntimos ao gravar (12800 → `1280000`; 1800 → `180000`). Confirmado em `empresa.dados`.
- **"Ano passado"**: numa empresa de 3 meses fica **em branco** (é o cenário certo —
  sem homólogo — e exercita o fallback dos KPIs).
- **Verificação de persistência**: `select e.dados from punho_empresas` mostra tudo no
  sítio e nas unidades certas → auditoria do onboarding **passou**.
- `operacoes=0` no servidor logo após onboarding: as 6 máquinas ficaram **locais**
  (offline-first); o perfil sincroniza (`sincronizado_em`), as operações ainda não.

**Achados (a decidir com o César):**
- **#A1 (UX, onboarding passo 6)**: o card "Continuar com os dados operacionais?" mostra
  a *opção já selecionada* e **inverte ao toque**. O default é "Sim"; tocar nele (gesto
  natural de escolher) vira para "Não" e **corta os passos operacionais em silêncio**
  (contador 11→6). Um empresário real salta os dados sem perceber.
- **#A2 (subscrição/trial)**: empresa acabada de aprovar mostra **"Trial termina em 1
  dia — contactar já."** A subscrição criada por `punho_decidir_pedido` **não define
  janela de trial** (`dados` só tem `estado`), e o cálculo cai para 1 dia. Um novo
  cliente aprovado não devia entrar já em fim de trial. A investigar.

**Convite ao contabilista e preenchimento do portal** (9/8/2026, continuação):

- Navegação: rail (scroll) → **Empresa** → tab **Histórico** → **"Convidar
  contabilista"** → diálogo com Nome/Email + selector de anos (1/3/5) → **"Criar
  link"**. Ver §3.4 para o passo a passo completo (navegação, diálogo, arquitetura do
  link Tailscale→edge, curl, SQL, refresh).
- Contabilista desta corrida: **Manuela Sousa** / `manuela.sousa@contabilidade.pt`,
  janela de **1 ano** (Ago/2025 → Jul/2026 — correto para empresa de 3 meses).
- Preenchimento por curl das rubricas mensais de Mai/Jun/Jul/2026 + rubricas de
  configuração (`cae`, `inicio_actividade`, `periodicidade_iva`,
  `regime_contabilidade`), seguido de `{"accao":"submeter"}` → `{"ok":true}`.
- **Reconciliação confirmada**: a facturação mensal declarada pelo contabilista
  (3.200 + 4.500 + 5.100 = **12.800 €**) bate certo com o "faturação este ano 12.800 €"
  que o Alfredo tinha lançado no onboarding (passo 3.2/#A). Primeira reconciliação
  ponta a ponta da corrida — **passou**.
- SQL de confirmação usado: `punho_respostas_contabilista` com
  `valor_centavos` = 320000 / 450000 / 510000 para `facturacao` de Mai/Jun/Jul.
- Depois do `submeter`, a app só mostrou "Entregue" após sair de Empresa e voltar
  (achado #3.4.6, `autoDispose` — não é bug, mas custou um ciclo de dúvida "porque é
  que o POST não teve efeito?").

**Dados canónicos desta corrida** (para reproduzir igual, ou para retomar do ponto
onde ficou):
- Persona empresário: **Alfredo Nogueira**; empresa **Aluguer Nogueira** (aluguer de
  máquinas); NIF 248193066; contacto 912345678 / geral@aluguernogueira.pt; morada "Rua
  das Oliveiras 45", 2670-320 Loures; forma jurídica ENI; 2 funcionários, 2 veículos,
  6 máquinas; faturação este ano 12.800 €; custos fixos 1.800 €/mês; ano passado em
  branco (empresa de 3 meses, sem homólogo).
- Login: `cesarmendes78+punhoteste@gmail.com` / `PunhoOP2026!`.
- Contabilista: **Manuela Sousa** / `manuela.sousa@contabilidade.pt`; janela 1 ano
  (Ago/2025→Jul/2026).
- **Fonte de verdade da receita mensal** (o Alfredo terá de reconciliar dentro da
  app): Mai **3.200** / Jun **4.500** / Jul **5.100** €. Rubricas por mês declaradas:
  `compras_e_servicos` (900/1.300/1.500), `custos_com_pessoal` (1.400/1.400/1.400),
  `iva_liquidado` (736/1.035/1.173), `resultado` (100/800/1.200).

**Achados novos (a decidir com o César):**
- **#A3**: nenhum achado de UX/bug nesta fase — a cadeia convite→link→curl→submeter→
  refresh correu como esperado. O único atrito foi de *quem testa* (autoDispose), não
  da app em si.

**Correcção de persona (regra do César, sem colaboradores)**, 9/8/2026: a
persona original tinha entrado com 2 funcionários no onboarding, mas a regra é
o empresário ser o **único trabalhador** (`n_colaboradores = 0`, sem contas de
colaborador). Corrigido pelo método de §3.6 (`pm clear` + SQL
`jsonb_set(...,'{n_colaboradores}','0')` + re-login), que fez o
`fichaRecebidaProvider` repor o perfil do servidor e ir **direta ao dashboard
sem repetir o onboarding** — prova, de caminho, a feature "trocar de
telemóvel/reinstalar". Durante a manobra, os toques a falhar (INJECT_EVENTS
revogado) levaram a app a **sair para o Punho OP** duas vezes; recuperado com
`dumpsys window | grep mCurrentFocus` + relançar por `monkey` (achado de
método registado em §4).

- **#A4 (UX / texto enganador)**: o campo "Colaboradores" (Definições da
  Empresa) tem a ajuda *"A zero, a área de Funcionários desaparece do menu."*
  — mas `visibleOperationalDestinations`
  (`lib/core/navigation/navigation_controller.dart:57`) devolve uma **lista
  CONSTANTE que inclui sempre `AppDestination.employees`**. Logo o destino
  "Colaboradores" fica no rail mesmo com 0. A ajuda promete um comportamento
  que não existe.

**Fase operacional — máquinas, clientes, reservas, ciclo entrega/recolha/cobrança e
KPIs de Agosto** (9/8/2026, continuação):

- **6 máquinas** criadas tap-a-tap (§3.8), verificadas por SQL em `punho_operacoes`
  (entidade `machine`): ME-01 Mini-escavadora 80€/dia, BT-02 Betoneira 350L 20€/dia,
  MD-03 Martelo demolidor Hilti 40€/dia, GE-04 Gerador 5kVA 30€/dia, PE-05 Plataforma
  elevatória 90€/dia, MR-06 Roçadora 25€/dia. `dailyRateCents` confirmado ×100 em todas
  (ex. 80 → 8000).
- **4 clientes** criados (§3.9), verificados por SQL (entidade `customer`): Construções
  Silva, Obras Loures, João Martins, Jardins Verde — telemóveis 912111222 / 913222333 /
  914333444 / 915444555.
- **2 reservas de Agosto** criadas pelo calendário de slots (§3.10), estado inicial
  Confirmada: Construções Silva × Mini-escavadora (ME-01) e Obras Loures × Plataforma
  elevatória (PE-05).
- **Ciclo completo entrega→recolha→cobrança** (§3.11) corrido para as duas reservas em
  "A minha semana": Entregar → Fechar trabalho → Registar recebimento. Recebimentos
  gravados: **1.300 €** (Construções Silva / Mini-escavadora) e **900 €** (Obras Loures
  / Plataforma) = **2.200 €**. Confirmado por SQL em `punho_operacoes` (entidade
  `receipt`) e reconciliado com o ecrã de KPIs: CAIXA / "DINHEIROS QUE ENTRARAM" de
  Agosto = **+2.200 €** ✓.
- **Descoberta de arquitetura** (§3.12): recebimentos gravam sempre com a data de hoje
  (`finance_pages.dart:495`, sem selector de data) — por isso as duas cobranças desta
  corrida foram feitas **no mês corrente**, nunca simulando cobranças "no passado"; o
  histórico financeiro dos meses anteriores entra só pelo contabilista (§3.4), não pela
  app. Decisão do César: manter este modelo (é o que a app já faz).
- **Reconciliação de KPIs passou** com a nuance de desenho documentada em §3.13: a
  comparação da CAIXA usa só recebimentos, a tendência de faturação usa o histórico do
  contabilista — são métricas diferentes, ambas corretas, e o "sem histórico para
  comparar" de Agosto/2025 é esperado (empresa de 3 meses, sem homólogo).

**Achados novos (a decidir com o César):**
- **#A5 (usabilidade de teste, não bug)**: o botão **"Guardar"** do diálogo de
  recebimento fica **abaixo da dobra** do bottom-sheet — é preciso scroll para o
  revelar. Não impede o utilizador real (o bottom-sheet é scrollável), mas atrasou a
  automação por toque porque o botão não aparecia no dump inicial.
- **#A6 (confirmado como correto, registar para não reinvestigar)**: a lista "KPIs
  (todos)" com scroll bloqueado por falha de input do MIUI **não é um problema da app**
  — é limitação do ambiente de automação (§3.3/§4); o Painel por "Slide seguinte" é o
  caminho de leitura fiável nesta configuração de teste.

**Dados canónicos desta fase** (para reproduzir):
- 6 máquinas: ME-01 Mini-escavadora 80€, BT-02 Betoneira 350L 20€, MD-03 Martelo
  demolidor Hilti 40€, GE-04 Gerador 5kVA 30€, PE-05 Plataforma elevatória 90€, MR-06
  Roçadora 25€.
- 4 clientes: Construções Silva, Obras Loures, João Martins, Jardins Verde (telemóveis
  912111222 / 913222333 / 914333444 / 915444555).
- Agosto: 2 reservas Confirmadas, ciclo completo → recebimentos €1.300 (Construções
  Silva/Mini-escavadora) + €900 (Obras Loures/Plataforma) = **€2.200**.

**Bug do KPI de tendência e a ponte contabilista→histórico** (9/8/2026, mesma
corrida, continuação — corrida a partir do emulador, §3.14):

- Sintoma: "DINHEIROS QUE ENTRARAM" mostrava "Sem histórico para comparar" para o
  Alfredo (empresa de 3 meses) mesmo com o contabilista a ter preenchido
  Mai/Jun/Jul 2026.
- **Causa raiz, dois níveis**:
  1. Simetria (fix A) — em `kpis.dart`, `recebidoMesAnteriorCents` usava
     `receiptTotal` cru enquanto o homólogo passava por
     `_recebidoDoMesComHistorico`. Corrigido: ambos passam pela mesma função.
  2. O verdadeiro — os meses do contabilista vivem em
     `punho_respostas_contabilista` (rubrica `facturacao`) e **nunca chegavam**
     a `historicalMonths`, que é o que o KPI lê. `historicalMonths` só era
     preenchido pelo onboarding (ano passado, divisão anual/12) e pelo editor
     manual; empresa nova sem ano passado → `historicalMonths` vazio →
     tendência cega mesmo com o contabilista já preenchido.
- **Fix**: ponte nova
  `lib/features/contabilista/historico_do_contabilista_provider.dart` — ao
  arrancar (observada na shell do gestor, `app_shell.dart`), lê
  `respostasDe('facturacao')` e materializa cada mês em `historicalMonths`
  (`revenueReceivedCents` = faturação declarada, mesma convenção do
  onboarding), com o **gestor a sobrepor-se ao contabilista** e a preservar
  outros campos de um mês já existente.
- **Validado no emulador** (§3.14): tendência passou de "sem histórico" →
  **▼57%** (previsto 2.200 vs Jul 5.100) → **▼11%** depois de lançar 3
  reservas futuras (previsto 4.550). Reservas em estado "Pedido" **contam**
  para o previsto (`_porReceberDeReservasDoMes`).
- **Dados canónicos desta fase** (id oficial): empresa
  `42644046-5a13-40fe-9e9b-eb9e0a6a5c9b` "Aluguer Nogueira", gestor Alfredo
  Nogueira, NIF 248193066. Contabilista Manuela Sousa (rubricas: `facturacao`
  Mai 3.200 / Jun 4.500 / Jul 5.100; + `compras_e_servicos`,
  `custos_com_pessoal`, `iva_liquidado`, `resultado`). 6 máquinas (ME-01,
  BT-02, MD-03, GE-04, PE-05, MR-06), 4 clientes, 2 reservas concluídas
  (€2.200) + 3 futuras "Pedido" (11/8·800, 13/8·650, 14/8·900).
- **Ficheiros mexidos (NÃO committados)**: `lib/core/operations/kpis.dart`,
  `lib/features/contabilista/historico_do_contabilista_provider.dart` (novo),
  `lib/features/shell/presentation/app_shell.dart`,
  `test/features/dashboard/kpis_test.dart`,
  `test/features/contabilista/historico_do_contabilista_test.dart` (novo).
  Testes: 40/40 `kpis` + 6/6 ponte.
- **Pendente**: acrescentar o KPI de tendência como cartão em "KPIs (todos)" —
  hoje só aparece no Painel; `kpis_page.dart` só tem `CartaoCaixa`.

(continua: 3 meses de operação do empresário → reservas/entregas/cobranças → KPIs →
reconciliação final gestor×contabilista)
