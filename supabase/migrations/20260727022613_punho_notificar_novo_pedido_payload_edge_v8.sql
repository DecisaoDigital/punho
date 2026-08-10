-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260727022613). Estava em
-- produção sem ficheiro no repo.

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

    nome_txt := coalesce(nullif(trim(new.nome), ''), new.email);
    perfil_txt := case
      when new.perfil = 'gestor' then 'gestor'
      else 'colaborador'
    end;
    corpo_msg := format('%s · %s · %s', nome_txt, new.empresa_indicada, perfil_txt);

    -- Nomes de campo conforme a enviar-push v8: title/body/data/app.
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
    return new;
  end;

  return new;
end;
$$;
