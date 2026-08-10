-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805143623). Estava em
-- produção sem ficheiro no repo. O número no nome é a ordem em que
-- correu nesse dia — por ordem alfabética ficaria trocada com a que
-- lhe acrescenta a coluna que usa.

-- **Um pedido de autorização de uso identifica-se sempre da mesma maneira.**
--
-- As duas apps pedem de forma diferente e por boa razão: o WashInvoice é um
-- terminal só, e quem pede é a máquina; o Punho é multi-utilizador, e quem pede
-- é uma pessoa. O que não havia motivo para ser diferente era a **chave**.
--
-- No POS o par `(machine_id, app)` de `licencas` já era a identidade canónica
-- de um terminal. O pedido do Punho não a levava — nascia de um trigger sobre
-- auth.users, onde não existe informação nenhuma sobre o aparelho —, e por isso
-- ninguém conseguia dizer de que terminal veio um pedido, nem cruzá-lo com a
-- instalação que aparece em Instalações.
--
-- Passa a levá-la. A pessoa continua a ser `user_id`; o terminal é o mesmo par
-- que o POS usa. Onde a app é multi-utilizador somam-se os dois.
alter table public.punho_pedidos_acesso
  add column if not exists machine_id text,
  add column if not exists app text not null default 'punho';

comment on column public.punho_pedidos_acesso.machine_id is
  'Terminal de onde partiu o pedido. Com `app`, forma o mesmo par que '
  'identifica um terminal em `licencas` — a identidade canónica multi-app. '
  'Nulo nos pedidos anteriores a 5/8/2026 e em clientes por actualizar.';

comment on column public.punho_pedidos_acesso.app is
  'A app cujo uso está a ser pedido. Existe para o pedido ser lido pela mesma '
  'chave em qualquer app, não porque esta tabela venha a ter outras.';

create index if not exists punho_pedidos_acesso_terminal_idx
  on public.punho_pedidos_acesso (machine_id, app);

-- O trigger do registo passa a gravar o terminal, quando a app o envia.
create or replace function public.punho_criar_pedido_ao_registar()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_codigo text := nullif(trim(coalesce(new.raw_user_meta_data->>'convite', '')), '');
  v_convite public.punho_convites%rowtype;
  v_empresa text;
  v_perfil text;
  v_maquina text := nullif(trim(coalesce(new.raw_user_meta_data->>'machine_id', '')), '');
begin
  if coalesce(new.raw_user_meta_data->>'app', '') <> 'punho' then
    return new;
  end if;

  if v_codigo is not null then
    select * into v_convite
      from public.punho_convites
     where upper(codigo) = upper(v_codigo)
       and not usado
       and expira_em > now()
       and lower(email) = lower(new.email)
     for update;

    if not found then
      raise exception 'Código de convite inválido, expirado ou já utilizado.'
        using errcode = 'P0001';
    end if;

    update public.punho_convites
       set usado = true, usado_por = new.id, usado_em = now()
     where id = v_convite.id;

    select nome into v_empresa from public.punho_empresas where id = v_convite.empresa_id;

    insert into public.punho_pedidos_acesso
      (user_id, nome, email, empresa_indicada, empresa_id, perfil, origem,
       convite_id, machine_id, app)
    values
      (new.id, new.raw_user_meta_data->>'nome', new.email,
       coalesce(v_empresa, 'Empresa por confirmar'), v_convite.empresa_id,
       v_convite.perfil, 'convite', v_convite.id, v_maquina, 'punho');

    return new;
  end if;

  v_perfil := case
    when new.raw_user_meta_data->>'perfil' = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app)
  values
    (new.id, new.raw_user_meta_data->>'nome', new.email,
     coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa por confirmar'),
     v_perfil, 'livre', v_maquina, 'punho');

  return new;
end;
$function$;

-- E o pedido feito com sessão aberta leva o terminal pelo mesmo caminho.
create or replace function public.punho_pedir_acesso(
  p_nome text,
  p_empresa text,
  p_perfil text default 'gestor',
  p_machine_id text default null
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_estado text;
begin
  if v_user is null then
    raise exception 'É preciso ter sessão iniciada para pedir acesso.'
      using errcode = 'P0001';
  end if;

  if exists (select 1 from public.punho_membros m
              where m.user_id = v_user and m.ativo) then
    return 'membro';
  end if;

  select estado into v_estado
    from public.punho_pedidos_acesso where user_id = v_user;
  if found then
    return v_estado;
  end if;

  select email into v_email from auth.users where id = v_user;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app)
  values
    (v_user,
     nullif(trim(coalesce(p_nome, '')), ''),
     v_email,
     coalesce(nullif(trim(coalesce(p_empresa, '')), ''), 'Empresa por confirmar'),
     case when p_perfil = 'gestor' then 'gestor' else 'colaborador' end,
     'livre',
     nullif(trim(coalesce(p_machine_id, '')), ''),
     'punho');

  return 'pendente';
end;
$function$;

-- A versão de 3 argumentos deixa de fazer falta: nenhuma app instalada chegou
-- a chamá-la (nasceu hoje, nesta mesma sessão).
drop function if exists public.punho_pedir_acesso(text, text, text);

revoke all on function public.punho_pedir_acesso(text, text, text, text) from public, anon;
grant execute on function public.punho_pedir_acesso(text, text, text, text) to authenticated;
