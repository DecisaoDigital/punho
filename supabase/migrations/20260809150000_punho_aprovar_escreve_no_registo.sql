-- Duas funções ainda tratavam as vistas como tabelas.
--
-- Encontrado a correr o inventário de dependências logo a seguir a
-- 20260809130000. Nenhuma delas tinha teste, e ambas partiam em produção:
--
-- 1. `punho_gestor_decidir_pedido` fazia `update punho_colaboradores set dados`
--    para gravar o NIF declarado na inscrição. `punho_colaboradores` é agora uma
--    vista com funções de janela — não é actualizável, e nenhum gatilho INSTEAD
--    OF a torna. **Aprovar um operador cuja ficha já existisse rebentava.**
--
--    A correcção não é pôr um INSTEAD OF: é escrever onde se deve escrever. Uma
--    alteração à ficha é um facto novo, e vai para o registo como qualquer
--    outro. Ganha-se de borla o que a `update` deitava fora — quem mudou o NIF,
--    quando, e o valor anterior.
--
-- 2. `punho_reprojectar_empresa` começava por replicar
--    `punho_estado_operacional` — a terceira cópia, vazia e parada desde
--    5/8/2026 — **por cima** do registo, antes de o ler.
--
--    Só não fez estragos porque está vazia: `punho_projectar_ficha` salta as
--    chaves que não são arrays, e não há nenhuma. Bastava alguém gravar lá um
--    estado antigo para a reprojecção passar a repor reservas velhas. Uma
--    reprojecção lê o registo e mais nada.

-- ---------------------------------------------------------------------------
-- 1. O NIF da inscrição entra pelo registo
-- ---------------------------------------------------------------------------
create or replace function public.punho_gestor_decidir_pedido(
  -- O `default null` faz parte da assinatura: sem ele o Postgres recusa o
  -- `create or replace` («cannot remove parameter defaults»), e a app chama-a
  -- com dois argumentos quando não há ficha para ligar.
  p_pedido_id uuid, p_decisao text, p_colaborador_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_pedido public.punho_pedidos_acesso%rowtype;
  v_empresa uuid;
  v_limite integer;
  v_activos integer;
  v_nome text;
  v_nif text;
  v_colaborador uuid := p_colaborador_id;
  v_id_local text;
  v_perfil text;
begin
  if p_decisao not in ('aprovar', 'recusar') then
    raise exception 'Decisão inválida.' using errcode = 'P0001';
  end if;

  select * into v_pedido
    from public.punho_pedidos_acesso where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if v_pedido.estado <> 'pendente' then
    raise exception 'Este pedido já foi decidido (está %).', v_pedido.estado
      using errcode = 'P0001';
  end if;

  v_empresa := v_pedido.empresa_id;
  if v_empresa is null then
    raise exception
      'Este pedido não está ligado a nenhuma empresa. Só o suporte o pode decidir.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.punho_membros m
     where m.user_id = auth.uid() and m.ativo
       and m.perfil = 'gestor' and m.empresa_id = v_empresa
  ) then
    raise exception 'Só o gestor desta empresa pode decidir este pedido.'
      using errcode = 'P0001';
  end if;

  if p_decisao = 'recusar' then
    update public.punho_pedidos_acesso
       set estado = 'recusado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object('estado_novo', 'recusado');
  end if;

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

  select
    coalesce(nullif(btrim(f.nome), ''), nullif(btrim(v_pedido.nome), '')),
    nullif(btrim(f.nif), '')
    into v_nome, v_nif
    from public.punho_perfis f where f.user_id = v_pedido.user_id;

  if v_nome is null then
    v_nome := nullif(btrim(v_pedido.nome), '');
  end if;

  if v_colaborador is not null then
    if not exists (
      select 1 from public.punho_colaboradores c
       where c.id = v_colaborador and c.empresa_id = v_empresa
    ) then
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

    -- Era `update punho_colaboradores`. A ficha é uma vista sobre o registo:
    -- escreve-se uma operação nova, e a vista passa a mostrar o NIF. Só quando
    -- a ficha ainda não tem nenhum — o gestor manda sobre o que já escreveu.
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
        'id', v_id_local,
        'name', v_nome,
        'status', 'active',
        'phone', null,
        'role', null,
        'costFrequency', 'monthly',
        'costCents', null,
        'schedule', '{}'::jsonb,
        'notes', '',
        'archived', false,
        'employmentType', 'contrato',
        'socialSecurityNumber', null,
        'taxId', v_nif,
        'maritalStatus', 'unmarried',
        'dependents', 0
      ),
      now(), auth.uid(), 'aprovacao-do-gestor'
    );

    v_colaborador := public.punho_id_estavel(v_empresa, v_id_local);
  end if;

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
    'ficha_criada', p_colaborador_id is null
  );
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 2. Reprojectar é ler o registo. Mais nada.
-- ---------------------------------------------------------------------------
create or replace function public.punho_reprojectar_empresa(p_empresa uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_op    record;
  v_conta integer := 0;
  v_ate   bigint  := 0;
begin
  -- Nada de `punho_projectar_ficha` aqui. Ver o cabeçalho.
  for v_op in
    select empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, seq
    from punho_operacoes
    where empresa_id = p_empresa
    order by seq
  loop
    perform punho_projectar_entidade(
      v_op.empresa_id, v_op.entidade, v_op.entidade_id,
      v_op.payload, v_op.feito_em, v_op.por_utilizador
    );
    v_conta := v_conta + 1;
    if v_op.entidade = 'booking' then
      v_ate := v_op.seq;
    end if;
  end loop;

  -- Uma reprojecção que não deixasse a posição em dia obrigava a próxima
  -- leitura a refazer o mesmo trabalho.
  if v_ate > 0 then
    insert into punho_projeccao_posicao (empresa_id, entidade, ultimo_seq, actualizado_em)
    values (p_empresa, 'booking', v_ate, now())
    on conflict (empresa_id, entidade) do update
      set ultimo_seq     = greatest(punho_projeccao_posicao.ultimo_seq, excluded.ultimo_seq),
          actualizado_em = now();
  end if;

  return v_conta;
end;
$fn$;

revoke all on function public.punho_reprojectar_empresa(uuid) from public, anon, authenticated;

comment on function public.punho_projectar_ficha(uuid, jsonb, timestamptz) is
  'MORTA. Replicava punho_estado_operacional por cima do registo. Nao chamar.';
