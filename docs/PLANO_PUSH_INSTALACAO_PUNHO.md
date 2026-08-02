# Plano — push de "instalação" para o Punho

**Conclusão adiantada: a cadeia já existe e já funciona tecnicamente para o Punho.
Não é preciso trigger novo nem alterações à Edge Function.** O que falta,
quando muito, é confirmação/polimento — ver secção 4.

---

## 1. WashInvoice — a cadeia que funciona

Evento "app instalada" = **primeiro `INSERT` em `licencas` para um
`(machine_id, app)` que ainda não existe**.

- **Quem insere:** Edge Function `registar-terminal` (`verify_jwt: true`,
  v6). Recebe `machine_id` + `app` (`'pos'` ou `'punho'`), é **idempotente**:
  se já existir linha para esse par, não insere nada e devolve
  `{criado: false}`. Só a primeira chamada por dispositivo insere.
- **Trigger real** (confirmado via `information_schema.triggers` no projecto
  `oefqbkhioncakojipqyx`):
  ```
  trg_notificar_novo_terminal  AFTER INSERT ON licencas
    EXECUTE FUNCTION notificar_novo_terminal()
  ```
- **Função** `notificar_novo_terminal()` (`pg_get_functiondef` real, sem
  `search_path` a `vault` explícito mas resolve por `SECURITY DEFINER`):
  - só age se `new.pendente_revisao = true` (é sempre `true` no insert do
    `registar-terminal`);
  - lê `edge_invoke_secret` de `vault.decrypted_secrets`;
  - `perform net.http_post(...)` para
    `https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push`
    com:
    ```json
    {
      "title": "Novo terminal registado",
      "body": "<hostname> — <machine_id curto>",
      "app": "<new.app>",
      "data": { "tipo": "novo_terminal", "machine_id": "...", "app": "<new.app>" }
    }
    ```
  - `exception when others then return new` — **falhas são engolidas em
    silêncio**, sem log visível.
- **Edge Function `enviar-push`** (v8, `verify_jwt: false`, autenticação por
  `Authorization: Bearer EDGE_INVOKE_SECRET`): já é multi-app — se
  `body.app` vier preenchido, prefixa o título com `[POS] ` ou `[PUNHO] `
  (`prefixarTituloPorApp`, sem alteração necessária). Busca tokens em
  `admin_dispositivos` por `user_id` (default = admin fixo, single-admin) e
  envia via FCM HTTP v1 a **todos** os tokens desse utilizador, sem filtrar
  por `app` — o Control recebe pushes de todas as apps no mesmo telemóvel.

## 2. Control — a recepção

- `lib/services/push_routing.dart:18-27` (`destinoDoPush`) — mapeia
  `data['tipo']`:
  - `'novo_terminal'` → `DestinoPush.instalacoes` (**genérico, não olha para
    `app`** — serve POS e Punho da mesma forma, comentário no próprio
    ficheiro linha 9-12 explica que `data['app']` não pode ser usado para
    isto).
  - `'novo_pedido'` → `DestinoPush.pedidosPunho`
  - `'pedido_ajuda'` → `DestinoPush.pedidosAjuda`
  - `'inicio_actividade'` → `DestinoPush.dashboard`
- **Canal Android / som — não existe canal custom nenhum.** Procurei
  `NotificationChannel`, `default_notification_channel_id`,
  `flutter_local_notifications` em todo o `washinvoice-control` (código e
  `android/app/src/main/AndroidManifest.xml`): não há nada. Isto significa:
  - **Todos** os tipos de push (`novo_terminal`, `novo_pedido`,
    `pedido_ajuda`, `inicio_actividade`) caem no **mesmo canal**, o que o
    Android/FCM cria automaticamente na app (`IMPORTANCE_DEFAULT`, que inclui
    som por omissão, a não ser que o Cesar o tenha silenciado manualmente
    nas definições do telefone).
  - **Não há canal silencioso à parte** — logo o `trg_notificar_novo_pedido_punho`
    (pedidos de acesso Punho, que o Cesar já recebe hoje) usa exactamente o
    mesmo canal/som que o `novo_terminal`. Não há diferença estrutural entre
    os dois.
  - **Importante:** o som só se ouve com a app em **background/fechada** —
    é o SO a desenhar a notificação nativa. Com a Control **aberta**,
    `main.dart:246` (`_FcmForegroundListener`) só mostra `SnackBar` +
    `HapticFeedback.mediumImpact()`, **sem som**. Isto é intencional
    (comentário na linha 254-255) e é igual para todos os tipos de push.

## 3. Punho — o evento equivalente a "instalada"

**Já é exactamente o mesmo mecanismo do WashInvoice — não um candidato
novo.** `lib/core/licenca/licenca_service.dart:38-49`
(`PunhoLicencaService.registarTerminal`) chama a **mesma** Edge Function
`registar-terminal`, sempre com `'app': 'punho'`, e é chamado:
- no arranque (`lib/main.dart:45,62-67`, `_registarTerminal()`);
- e outra vez a partir do banner de licença (`licenca_banner.dart:88`).

`machine_id` vem de `lib/core/licenca/machine_id.dart:18-27`
(`resolverMachineId`): hash SHA-256 de `ANDROID_ID` (Android) ou
MachineGuid (Windows), cacheado em `SharedPreferences`. Isto é o sinal
correcto:
- **Reinstalação (mesma app, mesma assinatura, mesmo dispositivo):**
  `ANDROID_ID` é estável por `(dispositivo, chave de assinagem da app)` desde
  o Android 8 — a reinstalação gera o **mesmo** `machine_id`. Como
  `registar-terminal` é idempotente por `(machine_id, app)`, **não** insere
  de novo e **não** dispara notificação. Sem falso positivo em reinstalação
  normal.
- **Segundo aparelho da mesma empresa:** `machine_id` diferente → nova linha
  → nova notificação. Correcto: é uma nova instalação física, tal como o
  WashInvoice trata dois PCs da mesma empresa como duas linhas em `licencas`.
- **Falso positivo possível:** troca de app/keystore (ex.: debug vs release,
  ou reassinar a app) muda o `ANDROID_ID` percebido → conta como "nova
  instalação" mesmo sendo o mesmo aparelho. É o mesmo comportamento que já
  existe para POS/Control — não é uma regressão introduzida agora.

**Prova de que já está a disparar, hoje:** consultei `licencas` (app='punho')
e há 2 linhas de trial (`pendente_revisao=true`) criadas hoje:

| machine_id (parcial) | created_at (UTC) |
|---|---|
| `339ed1626af8...` | 2026-08-01 15:21:44 |
| `ac0adda0da7c...` | 2026-08-02 00:42:01 |

E em `net._http_response` (histórico real de `net.http_post`), à mesma hora
exacta do segundo insert (`2026-08-02 00:42:01`), há uma chamada a
`enviar-push` que devolveu `200` com **6 tokens tentados, 5 `404
NotRegistered` (tokens antigos/expirados) e 1 `200` aceite pela FCM**
(`token_prefix "e8vqH2FOT42D"`). Ou seja: **o push de "novo terminal" para o
Punho já foi gerado, autenticado, enviado e aceite pela FCM hoje** — a
cadeia inteira (trigger → Edge Function → FCM) está viva.

## 4. O plano

**Não há trigger novo, não há alteração à Edge Function, não há tipo novo a
acrescentar ao `push_routing` — tudo isso já existe e já corre para
`app='punho'` porque `registar-terminal`, `notificar_novo_terminal()` e
`enviar-push` nunca foram escritos a pensar só no POS.** SQL de migração:
nenhum a aplicar.

O que **pode** estar a acontecer, dado que a cadeia dispara mas o Cesar diz
não a ter visto:

1. **Teste com a app em foreground.** Se a Control estiver aberta quando o
   push chega, não há som — só `SnackBar` (secção 2). Testar com a Control
   em background/fechada, tal como se testa o WashInvoice.
2. **Token morto.** Dos 6 tokens em `admin_dispositivos`, 5 estavam
   `NotRegistered` no envio de hoje — só 1 aparelho vivo recebeu. Se for o
   telefone errado (ex.: um Control antigo desinstalado, ou a app reinstalada
   sem novo login), o push nunca chega ao aparelho que o Cesar está a olhar.
   Vale a pena `SELECT * FROM admin_dispositivos` e confirmar que o telefone
   actual do Cesar lá está.
3. **Texto pouco distinguível.** O título é sempre `"Novo terminal
   registado"`, só com o prefixo `[PUNHO]` a diferenciar de `[POS]`
   (`prefixarTituloPorApp` em `enviar-push`). Se o Cesar recebe muitas
   notificações POS, pode ter passado uma `[PUNHO]` sem reparar.

### Polimento opcional (não bloqueia nada, é só se o Cesar quiser mais
sinal/distinção)

- **Canal Android dedicado com som próprio para instalações**, separado do
  canal genérico por omissão — a acrescentar em
  `washinvoice-control/android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="instalacoes_alta_prioridade" />
  ```
  e criar o canal no lado Kotlin (`MainActivity.kt` ou
  `Application.kt`) com `NotificationManager.IMPORTANCE_HIGH` e um som
  próprio — hoje não existe ficheiro Kotlin nenhum a criar canais, seria
  código novo, não SQL. Isto sobe a importância de **todas** as notificações
  (não só instalação), porque não há segmentação de canal por `tipo` — para
  segmentar por tipo seria preciso o Android channel ID vir no payload FCM
  (`android.notification.channel_id` na mensagem que `enviar-push` monta) e
  dois canais distintos no cliente.
- **SQL opcional, só se quiser confirmar rapidamente que chegou hoje** (não é
  migração, é consulta, seguro correr):
  ```sql
  select id, status_code, content::text, created
  from net._http_response
  where created > now() - interval '1 day'
  order by created desc;
  ```

## Resumo do que falta fazer

**Nada estrutural.** Sugiro: (a) confirmar `admin_dispositivos` tem o
telefone certo do Cesar; (b) testar com a Control em background; (c) se
mesmo assim não aparecer, correr a query de `net._http_response` acima logo
a seguir a uma instalação de teste do Punho para ver se o `net.http_post`
disparou e o que a FCM respondeu.

---

## Adenda — a causa real (2 de Agosto, sessão seguinte)

O push **chega**. O que não se percebe é o que ele diz. A função
`notificar_novo_terminal()` monta o corpo assim:

```sql
hostname_do_pc := coalesce(new.info_host->>'hostname', '(máquina sem nome)');
titulo := 'Novo terminal registado';
corpo  := hostname_do_pc || ' — ' || left(new.machine_id, 8) || '…';
```

`hostname` é chave que **só o POS escreve**. O Punho escreve outras:

| app | `info_host` |
|---|---|
| `pos` | `{"hostname": "Portatil-CD", "so": "...", "versao_pos": "2.0.6"}` |
| `punho` | `{"host": "M2101K6G", "fabricante": "Xiaomi", "versao_app": "0.1.0", ...}` |

Logo, para o Punho o Cesar recebeu **«Novo terminal registado —
(máquina sem nome) — 339ed162…»**: sem dizer que app é, sem dizer que
aparelho é. Aconteceu duas vezes — Redmi a 1 de Agosto às 15:21 e emulador a
2 de Agosto às 00:42, ambas com `pendente_revisao = true` e `http_post`
disparado.

Também confirmado: o título nunca menciona a app em caso nenhum, portanto o
mesmo texto serve POS e Punho. Não é regressão do Punho, é uma lacuna que só
se vê quando há mais do que uma app.

### Migração a aplicar (por autorizar)

`CREATE OR REPLACE` da função, sem tocar em tabelas nem em dados. Muda só o
texto: título passa a nomear a app, corpo aceita as duas formas de
`info_host` e acrescenta a versão.

```sql
CREATE OR REPLACE FUNCTION public.notificar_novo_terminal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  invoke_secret text;
  nome_app text;
  aparelho text;
  versao text;
  titulo text;
  corpo text;
begin
  if not coalesce(new.pendente_revisao, false) then
    return new;
  end if;

  select decrypted_secret into invoke_secret
  from vault.decrypted_secrets
  where name = 'edge_invoke_secret';
  if invoke_secret is null then return new; end if;

  nome_app := case new.app
    when 'punho' then 'Punho'
    when 'pos' then 'WashInvoice POS'
    else coalesce(nullif(new.app, ''), 'App')
  end;

  -- Telemóvel: "Xiaomi M2101K6G". Windows: o hostname de sempre.
  aparelho := coalesce(
    nullif(
      trim(
        coalesce(new.info_host->>'fabricante', '') || ' ' ||
        coalesce(new.info_host->>'host', '')
      ),
      ''
    ),
    nullif(new.info_host->>'hostname', ''),
    '(máquina sem nome)'
  );

  versao := coalesce(new.info_host->>'versao_app', new.info_host->>'versao_pos');

  titulo := nome_app || ' instalado';
  corpo := aparelho
    || case when versao is not null then ' · v' || versao else '' end
    || ' — ' || left(new.machine_id, 8) || '…';

  perform net.http_post(
    url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', '<anon key — copiar da definição actual da função>',
      'Authorization', 'Bearer ' || invoke_secret
    ),
    body := jsonb_build_object(
      'title', titulo,
      'body', corpo,
      'app', new.app,
      'data', jsonb_build_object(
        'tipo', 'novo_terminal',
        'machine_id', new.machine_id,
        'app', new.app
      )
    )
  );
  return new;
exception when others then
  return new;
end;
$function$;
```

Resultado esperado: **«Punho instalado» / «Xiaomi M2101K6G · v0.1.4 —
339ed162…»**.

### Tokens mortos em `admin_dispositivos`

Seis tokens, um só vivo (actualizado hoje). Os outros cinco têm 4, 7, 17, 17
e 17 dias e deram `NotRegistered` no último envio. Não impedem nada — a FCM
rejeita-os um a um — mas sujam os logs e vale a pena limpá-los. Apagar é acto
do Cesar.
