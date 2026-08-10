-- Duas coisas que trancavam pessoas de fora, e a mesma função a resolvê-las.
--
-- ── 1. "Já está na lista" nunca funcionou ────────────────────────────────────
--
-- O ecrã de decisão oferece duas saídas: criar ficha nova, ou ligar a uma que
-- já existe. A segunda estava morta desde que nasceu. A lista do dropdown vem
-- do estado da app, onde cada ficha tem o **id local** que a app lhe deu
-- (`col-servidor-…`, ou o que o telemóvel gerou). Esse id ia direito ao
-- parâmetro `p_colaborador_id uuid` — e o Postgres respondia `22P02`, com a
-- mensagem crua do erro de conversão à frente do gestor.
--
-- Quem sabe converter um id local no id da tabela é o servidor: é ele que tem
-- o `punho_id_estavel` e a projecção. O cliente não tem de conhecer a fórmula
-- do md5 — se a conhecesse, mudá-la um dia obrigava a actualizar todos os
-- telemóveis ao mesmo tempo.
--
-- **O parâmetro muda de tipo mas não de nome, de propósito.** Renomeá-lo
-- deixava as apps já instaladas sem função nenhuma para chamar (`PGRST202`), e
-- estas perdiam também o caminho que hoje funciona — o de criar ficha nova.
-- Mantendo o nome, um telemóvel que ainda não foi actualizado passa a acertar
-- nos dois: manda o id local, que é exactamente o que isto agora espera.
--
-- ── 2. Recusar trancava a pessoa para sempre ─────────────────────────────────
--
-- `recusar` era uma porta de sentido único: o pedido ficava `recusado` e a RPC
-- só aceita pedidos `pendente`. Um toque errado — ou uma pessoa que afinal foi
-- mesmo contratada — não tinha volta a dar pela app. E como há `unique
-- (user_id)` em `punho_pedidos_acesso`, inscrever-se outra vez também não era
-- saída: não nasce um segundo pedido.
--
-- Faltavam as duas transições que a versão antiga desta função — a do Control,
-- `punho_decidir_pedido` (20260801) — já tinha e que esta perdeu pelo caminho:
--   * `revogar`  aprovado           → revogado  (e o membro fica inactivo)
--   * `reabrir`  recusado/revogado  → pendente  (volta à fila de decisão)
--
-- Revogar nunca apaga nada: põe `ativo = false`. Quem trabalhou continua a
-- constar, com o custo que teve — apagar o membro fazia as contas do passado
-- mudar sozinhas.

-- -----------------------------------------------------------------------------
-- O tipo do parâmetro muda, portanto a assinatura muda: a antiga sai primeiro.
-- Deixar as duas a coexistir dava ambiguidade a quem chama com `null`.
-- -----------------------------------------------------------------------------
drop function if exists public.punho_gestor_decidir_pedido(uuid, text, uuid);

create or replace function public.punho_gestor_decidir_pedido(
  p_pedido_id uuid,
  p_decisao text,
  -- O **id local** da ficha de empregado, tal como a app o conhece. Nulo com
  -- `aprovar` continua a significar "criar ficha nova".
  p_colaborador_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pedido public.punho_pedidos_acesso%rowtype;
  v_empresa uuid;
  v_limite integer;
  v_activos integer;
  v_nome text;
  v_nif text;
  v_ficha text := nullif(btrim(p_colaborador_id), '');
  v_colaborador uuid;
  v_id_local text;
  v_perfil text;
begin
  if p_decisao not in ('aprovar', 'recusar', 'revogar', 'reabrir') then
    raise exception 'Decisão inválida.' using errcode = 'P0001';
  end if;

  select * into v_pedido
    from public.punho_pedidos_acesso where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;

  v_empresa := v_pedido.empresa_id;
  if v_empresa is null then
    raise exception
      'Este pedido não está ligado a nenhuma empresa. Só o suporte o pode decidir.'
      using errcode = 'P0001';
  end if;

  -- Quem decide tem de ser gestor activo DESTA empresa. Sem isto, um gestor
  -- de outra empresa aprovava pessoas para a casa alheia.
  if not exists (
    select 1 from public.punho_membros m
     where m.user_id = auth.uid() and m.ativo
       and m.perfil = 'gestor' and m.empresa_id = v_empresa
  ) then
    raise exception 'Só o gestor desta empresa pode decidir este pedido.'
      using errcode = 'P0001';
  end if;

  -- ── revogar ───────────────────────────────────────────────────────────────
  if p_decisao = 'revogar' then
    if v_pedido.estado <> 'aprovado' then
      raise exception 'Só se revoga o acesso a quem o tem (este pedido está %).',
        v_pedido.estado using errcode = 'P0001';
    end if;
    -- Um gestor a revogar-se a si próprio ficava de fora da sua própria
    -- empresa, sem ninguém lá dentro para o repor.
    if v_pedido.user_id = auth.uid() then
      raise exception 'Não pode revogar o seu próprio acesso.'
        using errcode = 'P0001';
    end if;

    update public.punho_membros
       set ativo = false, updated_at = now()
     where user_id = v_pedido.user_id and empresa_id = v_empresa;

    update public.punho_pedidos_acesso
       set estado = 'revogado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object('estado_novo', 'revogado');
  end if;

  -- ── reabrir ───────────────────────────────────────────────────────────────
  -- Volta à fila de decisão. Não devolve acesso nenhum por si só: quem o
  -- devolve é o `aprovar` que vem a seguir, com a escolha da ficha à frente do
  -- gestor como da primeira vez.
  if p_decisao = 'reabrir' then
    if v_pedido.estado not in ('recusado', 'revogado') then
      raise exception
        'Só se reabre um pedido recusado ou revogado (este está %).',
        v_pedido.estado using errcode = 'P0001';
    end if;
    update public.punho_pedidos_acesso
       set estado = 'pendente', decidido_em = null, decidido_por = null
     where id = p_pedido_id;
    return jsonb_build_object('estado_novo', 'pendente');
  end if;

  -- ── aprovar e recusar: só a partir de pendente ────────────────────────────
  if v_pedido.estado <> 'pendente' then
    raise exception 'Este pedido já foi decidido (está %).', v_pedido.estado
      using errcode = 'P0001';
  end if;

  if p_decisao = 'recusar' then
    update public.punho_pedidos_acesso
       set estado = 'recusado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object('estado_novo', 'recusado');
  end if;

  -- ── Limite de colaboradores ───────────────────────────────────────────────
  -- O limite é comercial e quem o define é o Control. O gestor não o pode
  -- exceder por muito que precise, e a mensagem diz-lhe o que fazer em vez de
  -- o deixar a olhar para um erro.
  select s.limite_colaboradores_ativos into v_limite
    from public.punho_subscricoes s where s.empresa_id = v_empresa;
  select count(*) into v_activos
    from public.punho_membros m
   where m.empresa_id = v_empresa and m.ativo and m.perfil = 'colaborador';

  if v_limite is not null and v_activos >= v_limite then
    raise exception
      'A empresa já tem % operadores activos, que é o limite contratado. Peça o alargamento ao suporte antes de aprovar mais.',
      v_activos using errcode = 'P0001';
  end if;

  -- ── Nome e contribuinte declarados ────────────────────────────────────────
  select
    coalesce(nullif(btrim(f.nome), ''), nullif(btrim(v_pedido.nome), '')),
    nullif(btrim(f.nif), '')
    into v_nome, v_nif
    from public.punho_perfis f where f.user_id = v_pedido.user_id;

  if v_nome is null then
    v_nome := nullif(btrim(v_pedido.nome), '');
  end if;

  -- ── A ficha de empregado ──────────────────────────────────────────────────
  if v_ficha is not null then
    -- **Aqui é que o id local se torna o id da tabela.** Procura-se pelo
    -- `id_local`, que é o que a app conhece; procurar em vez de derivar com o
    -- `punho_id_estavel` dá o mesmo id e ainda confirma, no mesmo gesto, que a
    -- ficha existe mesmo e é desta casa.
    select c.id into v_colaborador
      from public.punho_colaboradores c
     where c.empresa_id = v_empresa and c.id_local = v_ficha;

    -- Quem já tiver em mãos o id da tabela (o Control, uma correcção à mão)
    -- também acerta: não se manda ninguém traduzir ids para falar connosco.
    if v_colaborador is null and v_ficha ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select c.id into v_colaborador
        from public.punho_colaboradores c
       where c.empresa_id = v_empresa and c.id = v_ficha::uuid;
    end if;

    if v_colaborador is null then
      raise exception 'Essa ficha de empregado não é desta empresa.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1 from public.punho_membros m
       where m.colaborador_id = v_colaborador and m.user_id <> v_pedido.user_id
    ) then
      raise exception 'Essa ficha já está ligada a outra conta.'
        using errcode = 'P0001';
    end if;

    -- A ficha é vista sobre o registo: escreve-se uma operação nova e a vista
    -- passa a mostrar o NIF. O contribuinte declarado só preenche o que está
    -- em falta — se a ficha já tem um, é o da folha de salários que manda.
    if v_nif is not null then
      insert into public.punho_operacoes
        (id, empresa_id, entidade, entidade_id, payload, feito_em,
         por_utilizador, por_dispositivo)
      select gen_random_uuid(), v_empresa, 'collaborator', c.id_local,
             jsonb_set(c.dados, '{taxId}', to_jsonb(v_nif), true),
             now(), auth.uid(), 'aprovacao-do-gestor'
        from public.punho_colaboradores c
       where c.id = v_colaborador
         and coalesce(nullif(btrim(c.dados->>'taxId'), ''), '') = '';
    end if;
  else
    if v_nome is null then
      raise exception
        'Não há nome para criar a ficha. Peça à pessoa para o escrever na app, ou ligue a uma ficha existente.'
        using errcode = 'P0001';
    end if;

    v_id_local := 'col-servidor-' || replace(gen_random_uuid()::text, '-', '');

    insert into public.punho_operacoes
      (id, empresa_id, entidade, entidade_id, payload, feito_em,
       por_utilizador, por_dispositivo)
    values (
      gen_random_uuid(), v_empresa, 'collaborator', v_id_local,
      jsonb_build_object(
        'id', v_id_local, 'name', v_nome, 'status', 'active',
        'phone', null, 'role', null, 'costFrequency', 'monthly',
        -- Custo por apurar, e não zero. Um zero aqui dizia que a pessoa não
        -- custa nada à empresa, e isso entrava nas contas como verdade.
        'costCents', null, 'schedule', '{}'::jsonb, 'notes', '',
        'archived', false, 'employmentType', 'contrato',
        'socialSecurityNumber', null, 'taxId', v_nif,
        'maritalStatus', 'unmarried', 'dependents', 0
      ),
      now(), auth.uid(), 'aprovacao-do-gestor'
    );

    v_colaborador := public.punho_id_estavel(v_empresa, v_id_local);
  end if;

  -- ── O acesso ──────────────────────────────────────────────────────────────
  -- Pela app do operador é sempre colaborador, como no registo.
  v_perfil := case
    when v_pedido.app = 'punho_op' then 'colaborador'
    when v_pedido.perfil = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_membros
    (empresa_id, user_id, perfil, ativo, colaborador_id)
  values (v_empresa, v_pedido.user_id, v_perfil, true, v_colaborador)
  on conflict (user_id) do update
    set empresa_id = excluded.empresa_id,
        perfil = excluded.perfil,
        ativo = true,
        colaborador_id = excluded.colaborador_id,
        updated_at = now();

  update public.punho_pedidos_acesso
     set estado = 'aprovado', decidido_em = now(), decidido_por = auth.uid()
   where id = p_pedido_id;

  return jsonb_build_object(
    'estado_novo', 'aprovado',
    'colaborador_id', v_colaborador,
    'ficha_criada', v_ficha is null
  );
end;
$function$;

revoke all on function public.punho_gestor_decidir_pedido(uuid, text, text)
  from public, anon;
grant execute on function public.punho_gestor_decidir_pedido(uuid, text, text)
  to authenticated;

-- -----------------------------------------------------------------------------
-- Os que já foram decididos — para se poder voltar atrás
-- -----------------------------------------------------------------------------
--
-- Sem esta lista, reabrir era uma função sem ecrã: o gestor não tem por onde
-- ver quem recusou. `punho_pedidos_da_minha_empresa` só mostra pendentes, e é
-- para continuar assim — aquela é a fila de trabalho, esta é o arquivo.
create or replace function public.punho_pedidos_decididos_da_minha_empresa()
returns table(
  pedido_id uuid,
  nome text,
  email text,
  estado text,
  app text,
  decidido_em timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    p.id,
    coalesce(
      nullif(btrim(f.nome), ''),
      nullif(btrim(p.nome), '')
    ),
    p.email,
    p.estado,
    p.app,
    p.decidido_em
  from public.punho_pedidos_acesso p
  left join public.punho_perfis f on f.user_id = p.user_id
  where p.estado in ('aprovado', 'recusado', 'revogado')
    and p.empresa_id is not null
    and exists (
      select 1 from public.punho_membros m
       where m.user_id = auth.uid()
         and m.ativo
         and m.perfil = 'gestor'
         and m.empresa_id = p.empresa_id
    )
  order by p.decidido_em desc nulls last;
$function$;

revoke all on function public.punho_pedidos_decididos_da_minha_empresa()
  from public, anon;
grant execute on function public.punho_pedidos_decididos_da_minha_empresa()
  to authenticated;
