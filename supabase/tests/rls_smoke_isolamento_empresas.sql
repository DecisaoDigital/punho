-- ============================================================================
-- Smoke test de RLS — isolamento entre empresas (Fase 5 da v0.0.3)
--
-- NÃO é auditoria de RLS. Verifica uma coisa só, a mais importante: um
-- utilizador da empresa B não vê as máquinas da empresa A.
--
-- COMO CORRER
--   Cola no SQL Editor do Supabase (role service_role) e carrega em Run.
--   Corre inteiro dentro de uma transacção que termina em ROLLBACK: não deixa
--   nada na base. Mesmo assim, corre num branch/projeto de testes, não em
--   produção.
--
-- RESULTADO
--   Termina em silêncio => passou.
--   Levanta excepção com a mensagem do cenário que falhou => P0, parar tudo.
--
-- ESTADO: por correr. Ver docs/AUDITORIA_BUGS_v0.0.3.md, Fase 5.
-- ============================================================================

begin;

do $$
declare
  v_alice uuid := gen_random_uuid();
  v_bruno uuid := gen_random_uuid();
  v_empresa_a uuid;
  v_empresa_b uuid;
  v_maquina_a uuid;
  v_visiveis integer;
begin
  -- --------------------------------------------------------------------
  -- Cenário: duas empresas, um utilizador aprovado em cada uma.
  -- --------------------------------------------------------------------
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_alice, 'alice@a.pt', '{"app":"punho"}'::jsonb),
         (v_bruno, 'bruno@b.pt', '{"app":"punho"}'::jsonb);

  insert into public.punho_empresas (nome) values ('Empresa A') returning id into v_empresa_a;
  insert into public.punho_empresas (nome) values ('Empresa B') returning id into v_empresa_b;

  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (v_empresa_a, v_alice, 'gestor', true),
         (v_empresa_b, v_bruno, 'gestor', true);

  -- A Alice regista uma máquina na empresa dela.
  insert into public.punho_maquinas (empresa_id, created_by, dados)
  values (v_empresa_a, v_alice, '{"nome":"Mini escavadora da Alice"}'::jsonb)
  returning id into v_maquina_a;

  -- --------------------------------------------------------------------
  -- O Bruno autenticado consulta punho_maquinas.
  -- --------------------------------------------------------------------
  set local role authenticated;
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_bruno, 'role', 'authenticated')::text,
    true
  );

  select count(*) into v_visiveis from public.punho_maquinas where id = v_maquina_a;
  if v_visiveis <> 0 then
    raise exception
      'FALHA P0: o Bruno (empresa B) vê % máquina(s) da empresa A.', v_visiveis;
  end if;

  select count(*) into v_visiveis from public.punho_maquinas;
  if v_visiveis <> 0 then
    raise exception
      'FALHA P0: o Bruno vê % máquina(s) e a empresa dele não tem nenhuma.',
      v_visiveis;
  end if;

  -- Escrever na empresa alheia também tem de ser recusado.
  begin
    insert into public.punho_maquinas (empresa_id, created_by, dados)
    values (v_empresa_a, v_bruno, '{"nome":"intruso"}'::jsonb);
    raise exception 'FALHA P0: o Bruno conseguiu escrever na empresa A.';
  exception
    when insufficient_privilege then null;  -- esperado
  end;

  -- --------------------------------------------------------------------
  -- Contraprova: a Alice tem de ver a sua própria máquina. Sem isto, um
  -- "não vê nada" por a RLS estar a bloquear tudo passaria por sucesso.
  -- --------------------------------------------------------------------
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_alice, 'role', 'authenticated')::text,
    true
  );

  select count(*) into v_visiveis from public.punho_maquinas where id = v_maquina_a;
  if v_visiveis <> 1 then
    raise exception
      'FALHA P0: a Alice não vê a máquina da própria empresa (% linhas).',
      v_visiveis;
  end if;

  reset role;
  raise notice 'Smoke de isolamento entre empresas: PASSOU.';
end $$;

rollback;
