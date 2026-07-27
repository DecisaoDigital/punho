# Punho — trigger push "novo pedido de acesso"

**Objectivo:** quando um novo empresário faz signUp na Punho, a Control recebe
um push no telemóvel do Cesar. Hoje não recebe — o pedido cai em
`punho_pedidos_acesso (estado='pendente')` e só aparece se ele abrir o app.

Fecha o Task #196.

---

## Diagnóstico (para não recomeçar do zero)

Já existe em produção:

- Trigger `punho_criar_pedido_ao_registar` em `auth.users` insere linha em
  `public.punho_pedidos_acesso` sempre que `raw_user_meta_data->>'app' = 'punho'`.
  Migration: `supabase/migrations/20260730_punho_pedidos_acesso.sql`.
- Control tem `PunhoPedidosScreen` que lista pendentes.
- Edge Function `enviar-push` (`verify_jwt: false`, header
  `Authorization: Bearer <EDGE_INVOKE_SECRET>`) já envia FCM para
  `admin_dispositivos`, e o cliente Flutter prefixa `[Punho]` via `tituloComApp`.
- Padrão-modelo testado: `notificar_inicio_actividade()` no repo do Control
  (`docs/design/prompt_trigger_push_backend.md`). Lê o secret do
  `supabase_vault` (id `186e626e50b31e4806bfac3ff8b5d9b30a3aa91cbbdf2a7efe8e989222df5470`)
  e chama `net.http_post`.

Falta apenas o gatilho no lado da Punho: quando entra pedido novo, disparar
push.

---

## O que fazer

Cria migration `supabase/migrations/20260728_punho_notificar_novo_pedido.sql`
com uma função `public.notificar_novo_pedido_punho()` e um trigger
`AFTER INSERT ON public.punho_pedidos_acesso`.

Regras não negociáveis:

1. **Só notifica pedidos com `estado='pendente'`.** Reabrir um pedido também
   passa por INSERT (não é o caso hoje, mas defensivo).
2. **Silêncio em falha.** Se o vault não tiver o secret, se `pg_net` estiver
   down, se a Edge devolver erro — o INSERT do pedido *tem que passar*. `begin
   ... exception when others then return new; end;` à volta do bloco de push.
3. **Payload do push:**
   - `titulo`: `"Novo pedido Punho"` (o cliente prefixa `[Punho]`).
   - `corpo`: `<nome ou email> · <empresa_indicada> · gestor|colaborador`.
   - `dados`: `{ "app": "punho", "route": "/punho/pedidos",
     "pedido_id": "<uuid>" }`.
   - Destinatário: **todos** os `admin_dispositivos` activos (a Edge já filtra
     por admin — nesta fase o admin é o Cesar). Não precisas de escolher
     admin_id na função; a Edge trata disso.
4. **Não mexer em nada mais.** Sem `UPDATE` a `punho_pedidos_acesso`. Sem
   novas colunas. Sem novas tabelas.

Estrutura da função (adapta do `notificar_inicio_actividade` do Control):

```sql
create or replace function public.notificar_novo_pedido_punho()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  invoke_secret text;
  corpo_msg text;
  perfil_txt text;
  nome_txt text;
begin
  if new.estado <> 'pendente' then return new; end if;

  begin
    select decrypted_secret
      into invoke_secret
      from vault.decrypted_secrets
     where name = 'edge_invoke_secret'
     limit 1;
    if invoke_secret is null then return new; end if;

    nome_txt   := coalesce(nullif(trim(new.nome), ''), new.email);
    perfil_txt := case when new.perfil = 'gestor' then 'gestor' else 'colaborador' end;
    corpo_msg  := format('%s · %s · %s', nome_txt, new.empresa_indicada, perfil_txt);

    perform net.http_post(
      url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || invoke_secret
      ),
      body := jsonb_build_object(
        'titulo', 'Novo pedido Punho',
        'corpo', corpo_msg,
        'dados', jsonb_build_object(
          'app', 'punho',
          'route', '/punho/pedidos',
          'pedido_id', new.id::text
        )
      )
    );
  exception when others then
    -- best-effort: nunca bloquear o INSERT do pedido
    return new;
  end;

  return new;
end;
$$;

drop trigger if exists trg_notificar_novo_pedido_punho
  on public.punho_pedidos_acesso;
create trigger trg_notificar_novo_pedido_punho
  after insert on public.punho_pedidos_acesso
  for each row execute function public.notificar_novo_pedido_punho();
```

---

## Verificação (obrigatória antes de fechar)

1. Aplicar via Supabase MCP no projecto `oefqbkhioncakojipqyx` (é o mesmo do
   Control; Punho partilha).
2. `list_migrations` confirma que a migration aparece.
3. Confirmar que o vault tem `edge_invoke_secret`:
   ```sql
   select name from vault.decrypted_secrets where name = 'edge_invoke_secret';
   ```
   Se não tiver, **pára e avisa o Cesar** — significa que o vault do POS não
   está partilhado ou que o secret nunca foi importado. Não inventes.
4. Teste ponta-a-ponta manual:
   ```sql
   insert into public.punho_pedidos_acesso
     (user_id, nome, email, empresa_indicada, perfil, origem)
   values
     (gen_random_uuid(), 'Teste Push', 'teste-push@exemplo.pt',
      'Empresa Teste', 'gestor', 'livre');
   ```
   O Cesar tem de receber `[Punho] Novo pedido Punho — Teste Push · Empresa
   Teste · gestor` no Redmi (com a Control 1.8.1 já instalada e token FCM
   registado). Se não recebe, ver:
   ```sql
   select * from net._http_response order by created desc limit 5;
   ```
5. Limpar a linha de teste (`delete from public.punho_pedidos_acesso where
   email = 'teste-push@exemplo.pt';`) — o cascade em `auth.users` não se aplica
   ao contrário.

---

## Reconciliação

Depois de verificado, escreve resultado no fim deste ficheiro em secção nova
`## Verificação`:

- data + hora do teste
- push recebido ✅ / ❌
- se ❌: última linha de `net._http_response` (status + resposta)

---

## Rollback (emergência)

```sql
alter table public.punho_pedidos_acesso disable trigger trg_notificar_novo_pedido_punho;
-- ou nuclear:
-- drop trigger trg_notificar_novo_pedido_punho on public.punho_pedidos_acesso;
-- drop function public.notificar_novo_pedido_punho();
```

---

## NÃO tocar em

- Edge Function `enviar-push` — funciona, não mudar.
- Trigger `punho_criar_pedido_ao_registar` — o gatilho de inserção do pedido é
  este, ele **precede** o novo trigger e é o que garante que a linha existe.
- Secret `edge_invoke_secret` no vault — só ler.
- `admin_dispositivos`, `punho_membros`, `punho_empresas` — nenhuma escrita.

---

## Nota de âmbito

Este trigger cobre o momento **"pedido pendente criado"** — o gate onde o
Cesar tem de decidir. Um segundo sinal ("empresário aprovado + concluiu
onboarding + primeira revisão do estado operacional") pode fazer sentido mais
tarde para métricas de activação, mas fica fora deste ficheiro. Não misturar.

---

## Verificação

**Data:** 27 de Julho de 2026, 02:26 UTC. Aplicado por Claude Code via Supabase
MCP no projecto `oefqbkhioncakojipqyx`.

**Secret no vault:** presente. `select name from vault.decrypted_secrets where
name = 'edge_invoke_secret'` devolveu uma linha, portanto não foi preciso parar.

**Migrations aplicadas** (duas, ver abaixo o porquê):

- `20260727022420_punho_notificar_novo_pedido`
- `20260727022613_punho_notificar_novo_pedido_payload_edge_v8`

**O payload deste prompt estava errado.** Com `titulo`/`corpo`/`dados`, a Edge
Function respondeu:

```
status_code 400 — {"erro":"Faltam campos obrigatórios: title, body."}
```

A `enviar-push` v8 (lida com `get_edge_function`) exige `title`, `body`, `data`
opcional e `app` opcional. Também é **ela** que prefixa `[PUNHO]` ao título a
partir do `app` — não o cliente Flutter, como este prompt dizia. Corrigido o
payload em vez da Edge Function, que ficou intocada como manda a regra.

**Sonda, segunda tentativa:**

```
status_code 200 — {"ok":true,"enviados":5,"resultados":[…]}
```

Dos 5 dispositivos registados em `admin_dispositivos`: **1 aceitou o push (FCM
200)** e 4 devolveram `NotRegistered`/`UNREGISTERED` — tokens velhos de
instalações anteriores. Esperado, com a Control 1.8.1 ainda por instalar no
Redmi. O caminho `INSERT → trigger → pg_net → Edge → FCM` está confirmado
ponta-a-ponta.

**Nota sobre a sonda:** o `insert` deste prompt não corre como está —
`punho_pedidos_acesso.user_id` tem FK para `auth.users` e um
`gen_random_uuid()` viola-a (`23503`). Foi preciso criar um utilizador
descartável (`00000000-0000-4000-8000-0000000000aa`, sem metadata `app: punho`
para não disparar o trigger de registo) e apagá-lo no fim. Há também um índice
único em `user_id`, portanto duas sondas seguidas exigem apagar a primeira.

**Limpeza:** confirmada por contagem — 0 pedidos com
`teste-push@exemplo.pt`, 0 utilizadores de teste, trigger activo (1 linha em
`pg_trigger`).

**Título redundante:** com `app: 'punho'` a notificação sai como
`[PUNHO] Novo pedido Punho`. Mantive o título que este prompt pedia; se o Cesar
preferir, mudar para `Novo pedido de acesso` é uma palavra na função.
