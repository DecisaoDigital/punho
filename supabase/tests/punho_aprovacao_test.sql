-- ============================================================================
-- Testes da aprovação de pedidos Punho pelo Control.
--
-- COMO CORRER
--   SQL Editor do Supabase, com role service_role, depois de aplicar
--   20260801_punho_aprovacao_pelo_control.sql. Corre inteiro dentro de uma
--   transacção que termina em ROLLBACK: não deixa nada na base. Ainda assim,
--   corre num branch/projeto de testes, não em produção.
--
-- RESULTADO
--   Termina com "TODOS OS CENÁRIOS PASSARAM" => passou.
--   Levanta excepção com o cenário que falhou => corrigir antes de aplicar.
--
-- ESTADO: CORRIDO EM PRODUÇÃO em 2026-07-26, todos os cenários passaram.
--         Estado confrontado antes/depois: admins 1 -> 1 (mesmo UUID), zero
--         sobras de utilizadores de teste, zero linhas punho. O rollback
--         aguentou. Ver docs/design/control_aprova_punho.md (repo Control).
-- ============================================================================

begin;

do $$
declare
  v_admin uuid := gen_random_uuid();
  v_livre uuid := gen_random_uuid();
  v_convidado uuid := gen_random_uuid();
  v_gestor uuid := gen_random_uuid();
  v_empresa_convite uuid;
  v_convite uuid;
  v_pedido_livre uuid;
  v_pedido_convite uuid;
  v_resultado jsonb;
  v_empresa_nova uuid;
  v_ativo boolean;
  v_estado text;
  v_membros int;
  v_limite int;
begin
  -- ------------------------------------------------------------------
  -- Cenário base
  -- ------------------------------------------------------------------
  insert into auth.users (id, email) values
    (v_admin, 'admin@decisaodigital.pt'),
    (v_livre, 'livre@empresa.pt'),
    (v_convidado, 'convidado@empresa.pt'),
    (v_gestor, 'gestor@empresa.pt');

  insert into public.admins (user_id) values (v_admin);

  -- Empresa já existente, com um gestor, que emitiu um convite.
  insert into public.punho_empresas (nome) values ('Empresa do Convite')
    returning id into v_empresa_convite;
  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
    values (v_empresa_convite, v_gestor, 'gestor', true);
  insert into public.punho_convites
    (empresa_id, email, perfil, codigo, criado_por, expira_em, usado, usado_por)
  values
    (v_empresa_convite, 'convidado@empresa.pt', 'colaborador', 'TESTE12345',
     v_gestor, now() + interval '14 days', true, v_convidado)
  returning id into v_convite;

  -- Dois pedidos pendentes: um livre, um por convite.
  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem)
  values (v_livre, 'Ana Livre', 'livre@empresa.pt', 'Terraplanagens Ana',
          'gestor', 'livre')
  returning id into v_pedido_livre;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, empresa_id, perfil, origem, convite_id)
  values (v_convidado, 'Bruno Convidado', 'convidado@empresa.pt',
          'Empresa do Convite', v_empresa_convite, 'colaborador', 'convite',
          v_convite)
  returning id into v_pedido_convite;

  -- ------------------------------------------------------------------
  -- 3. Não-admin é recusado. (Primeiro, para garantir que a guarda existe
  --    antes de qualquer escrita.)
  -- ------------------------------------------------------------------
  -- Muda-se só a identidade (`request.jwt.claims`), NÃO o role. As RPCs são
  -- `security definer` e a guarda delas é `is_admin()`, que lê `auth.uid()`
  -- das claims — não depende do role. Com `set local role authenticated` as
  -- verificações a seguir liam as tabelas através da RLS e falhavam: o admin
  -- global não é membro de empresa nenhuma, logo `punho_empresa_atual()` é
  -- nulo e ele não vê `punho_empresas`. Isso mascarava uma RPC que estava
  -- correcta. Quem testa a RLS é rls_smoke_isolamento_empresas.sql.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_livre, 'role', 'authenticated')::text, true);
  begin
    perform public.punho_decidir_pedido(v_pedido_livre, 'aprovar');
    raise exception 'FALHA 3: um não-admin conseguiu decidir um pedido.';
  exception
    when sqlstate 'P0001' then null;  -- esperado
  end;

  -- Passa a admin para o resto dos cenários.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  -- ------------------------------------------------------------------
  -- 1. Aprovar origem='livre' cria empresa + membro gestor.
  -- ------------------------------------------------------------------
  v_resultado := public.punho_decidir_pedido(
    v_pedido_livre, 'aprovar', null, 5
  );
  v_empresa_nova := (v_resultado->>'empresa_id')::uuid;

  if v_resultado->>'estado_novo' <> 'aprovado' then
    raise exception 'FALHA 1: estado devolvido foi %', v_resultado->>'estado_novo';
  end if;
  if v_empresa_nova is null then
    raise exception 'FALHA 1: não devolveu empresa_id.';
  end if;
  if not exists (
    select 1 from public.punho_empresas
     where id = v_empresa_nova and nome = 'Terraplanagens Ana'
  ) then
    raise exception 'FALHA 1: empresa nova não foi criada com o nome indicado.';
  end if;
  if not exists (
    select 1 from public.punho_membros
     where user_id = v_livre and empresa_id = v_empresa_nova
       and perfil = 'gestor' and ativo
  ) then
    raise exception 'FALHA 1: membro gestor não foi criado.';
  end if;
  select s.limite_colaboradores_ativos into v_limite
    from public.punho_subscricoes s where s.empresa_id = v_empresa_nova;
  if v_limite <> 5 then
    raise exception 'FALHA 1: limite de utilizadores ficou % em vez de 5.', v_limite;
  end if;

  -- ------------------------------------------------------------------
  -- 2. Aprovar origem='convite' só cria membro; não cria empresa nova.
  -- ------------------------------------------------------------------
  select count(*) into v_membros from public.punho_empresas;
  v_resultado := public.punho_decidir_pedido(
    -- p_empresa_id propositadamente errado: tem de ser ignorado.
    v_pedido_convite, 'aprovar', v_empresa_nova, 99
  );
  if (v_resultado->>'empresa_id')::uuid <> v_empresa_convite then
    raise exception
      'FALHA 2: o convite devia mandar na empresa, mas ficou %',
      v_resultado->>'empresa_id';
  end if;
  if (select count(*) from public.punho_empresas) <> v_membros then
    raise exception 'FALHA 2: foi criada uma empresa que não devia.';
  end if;
  if not exists (
    select 1 from public.punho_membros
     where user_id = v_convidado and empresa_id = v_empresa_convite
       and perfil = 'colaborador' and ativo
  ) then
    raise exception 'FALHA 2: membro do convite não ficou activo com o perfil certo.';
  end if;

  -- ------------------------------------------------------------------
  -- 6. Recusar um pedido já aprovado tem de falhar.
  -- ------------------------------------------------------------------
  begin
    perform public.punho_decidir_pedido(v_pedido_livre, 'recusar');
    raise exception 'FALHA 6: recusou um pedido já aprovado.';
  exception
    when sqlstate 'P0001' then null;  -- esperado
  end;

  -- ------------------------------------------------------------------
  -- 4. Revogar um aprovado põe o membro inactivo (não apaga).
  -- ------------------------------------------------------------------
  v_resultado := public.punho_decidir_pedido(v_pedido_livre, 'revogar');
  if v_resultado->>'estado_novo' <> 'revogado' then
    raise exception 'FALHA 4: estado devolvido foi %', v_resultado->>'estado_novo';
  end if;
  select ativo into v_ativo from public.punho_membros where user_id = v_livre;
  if v_ativo is null then
    raise exception 'FALHA 4: a linha de punho_membros foi apagada em vez de desactivada.';
  end if;
  if v_ativo then
    raise exception 'FALHA 4: o membro continua activo depois de revogado.';
  end if;

  -- ------------------------------------------------------------------
  -- 5. Reaprovar um revogado reactiva o mesmo membro (UPDATE, não INSERT).
  --    O índice único em punho_membros(user_id) rebentaria com um insert.
  -- ------------------------------------------------------------------
  select count(*) into v_membros from public.punho_membros where user_id = v_livre;
  v_resultado := public.punho_decidir_pedido(v_pedido_livre, 'aprovar', v_empresa_nova);
  if v_resultado->>'estado_novo' <> 'aprovado' then
    raise exception 'FALHA 5: não reaprovou.';
  end if;
  select ativo into v_ativo from public.punho_membros where user_id = v_livre;
  if not v_ativo then
    raise exception 'FALHA 5: o membro não voltou a activo.';
  end if;
  if (select count(*) from public.punho_membros where user_id = v_livre) <> v_membros then
    raise exception 'FALHA 5: foi criada uma segunda linha em punho_membros.';
  end if;

  -- ------------------------------------------------------------------
  -- Extra: as listagens só respondem ao admin.
  -- ------------------------------------------------------------------
  if (select count(*) from public.punho_listar_pedidos_admin('aprovado')) < 2 then
    raise exception 'FALHA extra: a listagem de aprovados não traz os dois pedidos.';
  end if;
  if not exists (
    select 1 from public.punho_listar_empresas_admin()
     where id = v_empresa_convite and ativos_count >= 2
  ) then
    raise exception 'FALHA extra: a contagem de activos da empresa do convite está errada.';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_livre, 'role', 'authenticated')::text, true);
  begin
    perform public.punho_listar_pedidos_admin('pendente');
    raise exception 'FALHA extra: um não-admin conseguiu listar pedidos.';
  exception
    when sqlstate 'P0001' then null;  -- esperado
  end;

  raise notice 'TODOS OS CENÁRIOS PASSARAM.';
end $$;

rollback;
