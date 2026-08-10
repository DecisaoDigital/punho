-- A inscrição feita a partir do Punho OP passa a criar pedido de acesso.
--
-- Até aqui o gatilho `punho_criar_pedido_ao_registar` saía cedo para tudo o
-- que não fosse `app = 'punho'`. Uma conta criada pela app do operador ficava
-- em `auth.users` e mais nada: sem pedido, o Control não a via, ninguém a
-- podia aprovar, e a pessoa ficava presa no "ainda não tem acesso a nenhuma
-- empresa" para sempre, sem nada que denunciasse porquê.
--
-- Passa a aceitar `punho_op` e a guardar a app que a pessoa usou. Guardar qual
-- foi importa: é o mesmo par (`machine_id`, `app`) que identifica um terminal
-- em `licencas`, e é o que permite dizer "este pedido veio da app do operador,
-- daquele aparelho".
--
-- O perfil de quem se inscreve pela OP é sempre `colaborador`. A app do
-- operador não é caminho para fundar uma empresa nem para se promover a
-- gestor: quem cria a empresa é o gestor, no Punho. Inscrever-se continua a
-- não dar acesso nenhum — cria um pedido pendente, e a aprovação é que decide.
--
-- O nome viaja com o registo porque é ele que identifica a pessoa dentro da
-- empresa. `punho_meu_acesso()` já o devolve a quem tem sessão; o que faltava
-- era a app do operador poder criá-lo.

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
  v_app text := coalesce(new.raw_user_meta_data->>'app', '');
begin
  if v_app not in ('punho', 'punho_op') then
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

    -- Pelo convite o perfil é o que o convite diz — excepto na OP, onde um
    -- convite de gestor não pode transformar a app do operador em app de
    -- gestão. Nesse caso entra como colaborador e o gestor promove-o depois,
    -- no Punho, se for isso que quer.
    insert into public.punho_pedidos_acesso
      (user_id, nome, email, empresa_indicada, empresa_id, perfil, origem,
       convite_id, machine_id, app)
    values
      (new.id, new.raw_user_meta_data->>'nome', new.email,
       coalesce(v_empresa, 'Empresa por confirmar'), v_convite.empresa_id,
       case when v_app = 'punho_op' then 'colaborador' else v_convite.perfil end,
       'convite', v_convite.id, v_maquina, v_app);

    return new;
  end if;

  v_perfil := case
    when v_app = 'punho_op' then 'colaborador'
    when new.raw_user_meta_data->>'perfil' = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app)
  values
    (new.id, new.raw_user_meta_data->>'nome', new.email,
     coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa por confirmar'),
     v_perfil, 'livre', v_maquina, v_app);

  return new;
end;
$function$;

-- `punho_pedir_acesso` gravava `app = 'punho'` à força. Quem já tem sessão
-- aberta na OP e pede acesso ficava registado como vindo do Punho — o pedido
-- mentia sobre a sua origem.
--
-- A versão de quatro argumentos é APAGADA, não deixada ao lado: um
-- `create or replace` com um parâmetro novo cria uma sobrecarga, e uma chamada
-- com os quatro argumentos antigos passaria a servir as duas assinaturas —
-- o PostgREST responde "function is not unique" e o registo deixava de
-- funcionar em toda a gente. O `p_app` fica com valor por omissão para que
-- todos os clientes já instalados continuem a chamar com quatro.
drop function if exists public.punho_pedir_acesso(text, text, text, text);

create or replace function public.punho_pedir_acesso(
  p_nome text,
  p_empresa text,
  p_perfil text default 'gestor',
  p_machine_id text default null,
  p_app text default 'punho'
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
  v_app text := case when p_app = 'punho_op' then 'punho_op' else 'punho' end;
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
     -- Pela OP é sempre colaborador, pela mesma razão do gatilho.
     case
       when v_app = 'punho_op' then 'colaborador'
       when p_perfil = 'gestor' then 'gestor'
       else 'colaborador'
     end,
     'livre',
     nullif(trim(coalesce(p_machine_id, '')), ''),
     v_app);

  return 'pendente';
end;
$function$;

-- O `drop` levou consigo as permissões da função antiga. Repô-las tal como
-- estavam: `authenticated` executa, o `anon` não — pedir acesso exige ter
-- sessão, e a própria função recusa sem `auth.uid()`.
revoke all on function public.punho_pedir_acesso(text, text, text, text, text) from public;
revoke all on function public.punho_pedir_acesso(text, text, text, text, text) from anon;
grant execute on function public.punho_pedir_acesso(text, text, text, text, text) to authenticated;
grant execute on function public.punho_pedir_acesso(text, text, text, text, text) to service_role;
