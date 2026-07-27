-- ============================================================================
-- Punho — push ao Cesar quando entra um novo pedido de acesso.
--
-- O pedido já é criado pelo trigger `punho_criar_pedido_ao_registar` em
-- `auth.users` (migrations 20260730/20260731). O que faltava era o aviso: sem
-- ele o pedido fica em `punho_pedidos_acesso (estado='pendente')` e só aparece
-- se o Cesar abrir a Control por iniciativa própria.
--
-- Reutiliza o que o Control já tem: a Edge Function `enviar-push`
-- (`verify_jwt: false`, autenticada pelo `edge_invoke_secret` do vault) e a
-- tabela `admin_dispositivos`. Nada de novo do lado da infra.
--
-- Idempotente: pode correr as vezes que forem precisas.
-- ============================================================================

begin;

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
  -- Só pedidos por decidir. Reabrir um pedido também passaria por INSERT — não
  -- é o caso hoje, mas assim não avisa por algo já resolvido.
  if new.estado <> 'pendente' then return new; end if;

  begin
    select decrypted_secret
      into invoke_secret
      from vault.decrypted_secrets
     where name = 'edge_invoke_secret'
     limit 1;
    if invoke_secret is null then return new; end if;

    nome_txt := coalesce(nullif(trim(new.nome), ''), new.email);
    perfil_txt := case
      when new.perfil = 'gestor' then 'gestor'
      else 'colaborador'
    end;
    corpo_msg := format(
      '%s · %s · %s',
      nome_txt,
      new.empresa_indicada,
      perfil_txt
    );

    -- Assíncrono (pg_net): o INSERT não espera pela Edge Function.
    --
    -- Os nomes dos campos são os que a `enviar-push` v8 exige — `title`, `body`,
    -- `data`, `app` — e não `titulo`/`corpo`/`dados`. Com os nomes em português
    -- a função responde `400 {"erro":"Faltam campos obrigatórios: title,
    -- body."}` (verificado na sonda). O prefixo `[PUNHO]` no título é posto pela
    -- própria Edge Function a partir do `app`, não pelo cliente.
    --
    -- Sem `user_id`, a Edge envia para os dispositivos do admin por omissão —
    -- que nesta fase é o Cesar.
    perform net.http_post(
      url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || invoke_secret
      ),
      body := jsonb_build_object(
        'title', 'Novo pedido Punho',
        'body', corpo_msg,
        'app', 'punho',
        'data', jsonb_build_object(
          'app', 'punho',
          'route', '/punho/pedidos',
          'pedido_id', new.id::text
        )
      )
    );
  exception when others then
    -- Best-effort: sem secret, sem pg_net, ou com a Edge em baixo, o pedido
    -- tem de entrar de qualquer maneira. Perder o aviso é mau; perder o pedido
    -- de um cliente é pior.
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

commit;
