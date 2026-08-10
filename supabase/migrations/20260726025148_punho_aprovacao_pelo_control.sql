-- ============================================================================
-- Punho — aprovação de pedidos de acesso pelo Decisão Digital Control.
--
-- COMO APLICAR
--   Cola no SQL Editor do projeto Supabase partilhado (oefqbkhioncakojipqyx)
--   e carrega em Run. Tem de correr DEPOIS de:
--     * washinvoice_control/supabase/rls_policies.sql  (cria public.is_admin())
--     * 20260730_punho_pedidos_acesso.sql
--     * 20260731_punho_contas_organizacao.sql
--   É idempotente: pode correr as vezes que forem precisas.
--
-- O QUE FAZ
--   Três RPCs para o Control (admin global) decidir pedidos do Punho:
--     punho_decidir_pedido()        aprovar / recusar / revogar
--     punho_listar_pedidos_admin()  lista por estado, com dados do convite
--     punho_listar_empresas_admin() empresas + ocupação, para anexar a uma
--
--   Nenhuma tabela nova, nenhuma policy de escrita para `authenticated`. O
--   admin actua só por estas funções `security definer`, que verificam
--   `public.is_admin()` à cabeça.
--
-- NOTA SOBRE O LIMITE DE UTILIZADORES
--   `punho_empresas` não tem coluna de limite — quem o guarda é
--   `punho_subscricoes.limite_colaboradores_ativos`, criado em 20260725. Não se
--   acrescenta uma segunda fonte de verdade: `p_limite_utilizadores` vai para a
--   subscrição, e é de lá que `punho_listar_empresas_admin()` o lê.
-- ============================================================================

begin;

-- Quem decidiu. `decidido_em` já existia desde 20260730; faltava o autor.
alter table public.punho_pedidos_acesso
  add column if not exists decidido_por uuid references auth.users(id);

-- ---------------------------------------------------------------------------
-- Decidir um pedido
-- ---------------------------------------------------------------------------
-- Regras de transição:
--   aprovar  — a partir de qualquer estado (reaprovar um revogado é o caminho
--              normal de repor acesso). Nunca faz INSERT duplicado em
--              punho_membros: há índice único em (user_id), pelo que se usa
--              `on conflict (user_id) do update`.
--   recusar  — só de `pendente`. Depois de aprovado, tirar acesso é revogar.
--   revogar  — só de `aprovado`. Nunca apaga: põe `ativo = false`.
create or replace function public.punho_decidir_pedido(
  p_pedido_id uuid,
  p_decisao text,
  p_empresa_id uuid default null,
  p_limite_utilizadores int default 1
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pedido public.punho_pedidos_acesso%rowtype;
  v_empresa uuid;
  v_perfil text;
  v_membro uuid;
  v_estado text;
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global decide pedidos do Punho.'
      using errcode = 'P0001';
  end if;
  if p_decisao not in ('aprovar', 'recusar', 'revogar') then
    raise exception 'Decisão inválida: %', p_decisao using errcode = 'P0001';
  end if;

  select * into v_pedido from public.punho_pedidos_acesso
   where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;

  -- ---------------------------------------------------------------- recusar
  if p_decisao = 'recusar' then
    if v_pedido.estado <> 'pendente' then
      raise exception
        'Só um pedido pendente pode ser recusado (este está %). Para tirar o acesso a uma conta já aprovada, revogue.',
        v_pedido.estado using errcode = 'P0001';
    end if;
    update public.punho_pedidos_acesso
       set estado = 'recusado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object(
      'estado_novo', 'recusado', 'empresa_id', null, 'membro_id', null
    );
  end if;

  -- ---------------------------------------------------------------- revogar
  if p_decisao = 'revogar' then
    if v_pedido.estado <> 'aprovado' then
      raise exception 'Só um pedido aprovado pode ser revogado (este está %).',
        v_pedido.estado using errcode = 'P0001';
    end if;
    update public.punho_membros
       set ativo = false, updated_at = now()
     where user_id = v_pedido.user_id
    returning id into v_membro;

    update public.punho_pedidos_acesso
       set estado = 'revogado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object(
      'estado_novo', 'revogado',
      'empresa_id', v_pedido.empresa_id,
      'membro_id', v_membro
    );
  end if;

  -- ---------------------------------------------------------------- aprovar
  if v_pedido.origem = 'convite' then
    -- A empresa vem do convite e não é negociável: p_empresa_id é ignorado.
    select c.empresa_id into v_empresa
      from public.punho_convites c where c.id = v_pedido.convite_id;
    v_empresa := coalesce(v_empresa, v_pedido.empresa_id);
    if v_empresa is null then
      raise exception
        'Pedido por convite sem empresa associada — convite apagado? Trate à mão antes de aprovar.'
        using errcode = 'P0001';
    end if;
    -- O perfil também vem do convite, já gravado no pedido pelo trigger.
    v_perfil := v_pedido.perfil;
  else
    v_empresa := p_empresa_id;
    if v_empresa is null then
      -- Empresa nova, espelhando o que a antiga punho_criar_empresa_inicial
      -- fazia: empresa + subscrição + instalação.
      insert into public.punho_empresas (nome)
      values (coalesce(nullif(btrim(v_pedido.empresa_indicada), ''), 'Empresa sem nome'))
      returning id into v_empresa;

      insert into public.punho_subscricoes
        (empresa_id, dados, limite_colaboradores_ativos)
      values (
        v_empresa,
        jsonb_build_object('estado', 'aprovada-pelo-control'),
        greatest(coalesce(p_limite_utilizadores, 1), 1)
      );

      insert into public.punho_instalacoes (empresa_id, dados)
      values (v_empresa, jsonb_build_object('origem', 'aprovacao-control'));
    else
      if not exists (select 1 from public.punho_empresas where id = v_empresa) then
        raise exception 'Empresa indicada não existe.' using errcode = 'P0001';
      end if;
    end if;
    -- Quem pede acesso livre e é aprovado fica gestor da empresa.
    v_perfil := 'gestor';
  end if;

  -- Índice único em punho_membros(user_id): reaprovar é UPDATE, nunca um
  -- segundo INSERT.
  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (v_empresa, v_pedido.user_id, v_perfil, true)
  on conflict (user_id) do update
    set empresa_id = excluded.empresa_id,
        perfil = excluded.perfil,
        ativo = true,
        updated_at = now()
  returning id into v_membro;

  update public.punho_pedidos_acesso
     set estado = 'aprovado',
         empresa_id = v_empresa,
         decidido_em = now(),
         decidido_por = auth.uid()
   where id = p_pedido_id;

  v_estado := 'aprovado';
  return jsonb_build_object(
    'estado_novo', v_estado, 'empresa_id', v_empresa, 'membro_id', v_membro
  );
end;
$$;
revoke all on function public.punho_decidir_pedido(uuid, text, uuid, int) from public;
revoke all on function public.punho_decidir_pedido(uuid, text, uuid, int) from anon;
grant execute on function public.punho_decidir_pedido(uuid, text, uuid, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Listar pedidos para o Control
-- ---------------------------------------------------------------------------
-- Traz já o contexto do convite para o ecrã poder dizer "vem do convite da
-- empresa X", sem uma segunda ida à base.
create or replace function public.punho_listar_pedidos_admin(
  p_estado text default 'pendente'
) returns table (
  id uuid,
  user_id uuid,
  nome text,
  email text,
  organizacao_indicada text,
  perfil text,
  origem text,
  estado text,
  criado_em timestamptz,
  decidido_em timestamptz,
  convite_id uuid,
  convite_empresa_id uuid,
  convite_empresa_nome text,
  convite_criado_em timestamptz,
  empresa_id uuid,
  empresa_nome text
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global lista pedidos do Punho.'
      using errcode = 'P0001';
  end if;
  return query
    select p.id, p.user_id, p.nome, p.email,
           p.empresa_indicada, p.perfil, p.origem, p.estado,
           p.criado_em, p.decidido_em,
           p.convite_id, c.empresa_id, ce.nome, c.criado_em,
           p.empresa_id, pe.nome
      from public.punho_pedidos_acesso p
      left join public.punho_convites c on c.id = p.convite_id
      left join public.punho_empresas ce on ce.id = c.empresa_id
      left join public.punho_empresas pe on pe.id = p.empresa_id
     where p_estado is null or p.estado = p_estado
     order by p.criado_em desc;
end;
$$;
revoke all on function public.punho_listar_pedidos_admin(text) from public;
revoke all on function public.punho_listar_pedidos_admin(text) from anon;
grant execute on function public.punho_listar_pedidos_admin(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Listar empresas para o Control
-- ---------------------------------------------------------------------------
-- `limite_utilizadores` sai da subscrição — ver nota no cabeçalho.
create or replace function public.punho_listar_empresas_admin()
returns table (
  id uuid,
  nome text,
  limite_utilizadores int,
  ativos_count int
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global lista empresas do Punho.'
      using errcode = 'P0001';
  end if;
  return query
    select e.id,
           e.nome,
           coalesce((
             select s.limite_colaboradores_ativos
               from public.punho_subscricoes s
              where s.empresa_id = e.id
              order by s.created_at
              limit 1
           ), 0)::int,
           (
             select count(*)
               from public.punho_membros m
              where m.empresa_id = e.id and m.ativo
           )::int
      from public.punho_empresas e
     order by e.nome;
end;
$$;
revoke all on function public.punho_listar_empresas_admin() from public;
revoke all on function public.punho_listar_empresas_admin() from anon;
grant execute on function public.punho_listar_empresas_admin() to authenticated;

commit;
