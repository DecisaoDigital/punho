-- ============================================================================
-- O operador cobra, não altera preços — Fase 2.2
--
-- Um caso por campo proibido, com sessão de colaborador a sério (role
-- `authenticated` + `request.jwt.claims`), que é o que faz as políticas e o
-- gatilho correrem como correm em produção. Ligado como `postgres` isto passa
-- sempre: o dono salta o RLS e responde que sim a tudo.
--
-- COMO CORRER
--   Cola no SQL Editor do Supabase e carrega em Run. Corre inteiro dentro de
--   uma transacção que acaba em ROLLBACK: não deixa nada na base.
--
-- RESULTADO
--   `PASSOU` no fim => está fechado.
--   Excepção com o cenário que falhou => o buraco voltou.
--
-- A prova gémea, pela API REST e com token de sessão verdadeiro, está em
-- `punho_campos_do_colaborador_rest.sh` — esta cobre a matriz, essa cobre o
-- caminho por onde a app fala mesmo.
-- ============================================================================

begin;

do $$
declare
  v_gestor    uuid := gen_random_uuid();
  v_operador  uuid := gen_random_uuid();
  v_empresa   uuid;
  v_maquina   jsonb;
  v_reserva   jsonb;
  v_recibo    jsonb;
  v_cliente   jsonb;

begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_gestor,   'gestor@prova.pt',   '{"app":"punho"}'::jsonb),
         (v_operador, 'operador@prova.pt', '{"app":"punho"}'::jsonb);

  insert into public.punho_empresas (nome) values ('Prova 2.2')
  returning id into v_empresa;

  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (v_empresa, v_gestor,   'gestor', true),
         (v_empresa, v_operador, 'colaborador', true);

  v_maquina := jsonb_build_object(
    'id', 'maq-1', 'name', 'Giratória 3T', 'reference', 'REF-1',
    'category', 'Escavadoras', 'status', 'available',
    'dailyRateCents', 5000, 'acquiredOn', null,
    'purchasePriceCents', 900000, 'notes', '',
    'photoPaths', '[]'::jsonb, 'archived', false
  );
  v_cliente := jsonb_build_object(
    'id', 'cli-1', 'name', 'Casa Ferreira', 'phone', '912000000',
    'taxId', null, 'email', null, 'address', null, 'postalCode', null,
    'locality', null, 'notes', '', 'companyId', 'local-company',
    'archived', false
  );
  v_reserva := jsonb_build_object(
    'id', 'res-1', 'customerId', 'cli-1', 'machineIds', '["maq-1"]'::jsonb,
    'startsAt', (now() + interval '1 day')::text,
    'endsAt',   (now() + interval '3 days')::text,
    'status', 'confirmed', 'expectedValueCents', 20000,
    'collaboratorResponsibleId', null, 'companyId', 'local-company',
    'customerNameSnapshot', 'Casa Ferreira', 'collaboratorNameSnapshot', '',
    'notes', ''
  );
  v_recibo := jsonb_build_object(
    'id', 'rec-1', 'date', now()::text, 'amountCents', 20000,
    'customerId', 'cli-1', 'bookingId', 'res-1', 'method', 'cash',
    'note', '', 'recordedByCollaboratorId', null, 'archived', false
  );

  -- ------------------------------------------------------------------
  -- O gestor põe o inventário de pé.
  -- ------------------------------------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_gestor, 'role', 'authenticated')::text, true);

  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine',  'maq-1', v_maquina),
         (gen_random_uuid(), v_empresa, 'customer', 'cli-1', v_cliente),
         (gen_random_uuid(), v_empresa, 'booking',  'res-1', v_reserva);

  -- ------------------------------------------------------------------
  -- Passa a ser o operador.
  -- ------------------------------------------------------------------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador, 'role', 'authenticated')::text, true);

  -- POSITIVO: entregar a máquina é o trabalho dele.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine', 'maq-1',
          jsonb_set(v_maquina, '{status}', '"rented"'));

  -- POSITIVO: notas de obra.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine', 'maq-1',
          jsonb_set(jsonb_set(v_maquina, '{status}', '"rented"'),
                    '{notes}', '"Óleo a meio"'));

  -- POSITIVO: reenviar o mesmo (carga inicial de um aparelho novo).
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine', 'maq-1',
          jsonb_set(jsonb_set(v_maquina, '{status}', '"rented"'),
                    '{notes}', '"Óleo a meio"'));

  -- POSITIVO: mudar o estado da reserva.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'booking', 'res-1',
          jsonb_set(v_reserva, '{status}', '"rented"'));

  -- POSITIVO: corrigir o contacto do cliente.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'customer', 'cli-1',
          jsonb_set(v_cliente, '{phone}', '"913111111"'));

  -- POSITIVO: cobrar.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'receipt', 'rec-1', v_recibo);

  -- POSITIVO: uma máquina antiga, gravada antes de `purchasePriceCents`
  -- existir, entregue por uma app que já manda a chave a `null`. Ausente e
  -- nulo são a mesma coisa — se não fossem, a entrega ia para a quarentena.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_gestor, 'role', 'authenticated')::text, true);
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine', 'maq-velha', (v_maquina - 'purchasePriceCents')
          || '{"id":"maq-velha"}'::jsonb);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador, 'role', 'authenticated')::text, true);
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
  values (gen_random_uuid(), v_empresa, 'machine', 'maq-velha',
          jsonb_set(v_maquina || '{"id":"maq-velha","purchasePriceCents":null}'::jsonb,
                    '{status}', '"rented"'));

  reset role;
  raise notice 'positivos: passaram todos.';
end $$;

-- ---------------------------------------------------------------------------
-- Os negativos, um por campo. Cada um tem de morrer com 42501.
-- ---------------------------------------------------------------------------
do $$
declare
  v_empresa  uuid;
  v_operador uuid;
  v_maquina  jsonb;
  v_cliente  jsonb;
  v_reserva  jsonb;
  v_recibo   jsonb;
  v_caso     record;
  v_falhou   text[] := array[]::text[];
begin
  select id into v_empresa from public.punho_empresas where nome = 'Prova 2.2';
  select user_id into v_operador from public.punho_membros
   where empresa_id = v_empresa and perfil = 'colaborador';

  select payload into v_maquina from public.punho_operacoes
   where empresa_id = v_empresa and entidade_id = 'maq-1' order by seq limit 1;
  select payload into v_cliente from public.punho_operacoes
   where empresa_id = v_empresa and entidade_id = 'cli-1' order by seq limit 1;
  select payload into v_reserva from public.punho_operacoes
   where empresa_id = v_empresa and entidade_id = 'res-1' order by seq limit 1;
  select payload into v_recibo from public.punho_operacoes
   where empresa_id = v_empresa and entidade_id = 'rec-1' order by seq limit 1;

  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador, 'role', 'authenticated')::text, true);

  for v_caso in
    select * from (values
      ('baixar o preço por dia',      'machine',  'maq-1',
        jsonb_set(v_maquina, '{dailyRateCents}', '100')),
      ('mexer no valor de compra',    'machine',  'maq-1',
        jsonb_set(v_maquina, '{purchasePriceCents}', '1')),
      ('apagar o preço por dia',      'machine',  'maq-1',
        jsonb_set(v_maquina, '{dailyRateCents}', 'null')),
      ('mudar a referência',          'machine',  'maq-1',
        jsonb_set(v_maquina, '{reference}', '"REF-9"')),
      ('mudar a categoria',           'machine',  'maq-1',
        jsonb_set(v_maquina, '{category}', '"Martelos"')),
      ('mudar o nome da máquina',     'machine',  'maq-1',
        jsonb_set(v_maquina, '{name}', '"A minha"')),
      ('arquivar a máquina',          'machine',  'maq-1',
        jsonb_set(v_maquina, '{archived}', 'true')),
      ('inventar uma máquina',        'machine',  'maq-nova',
        v_maquina || '{"id":"maq-nova"}'::jsonb),
      ('arquivar o cliente',          'customer', 'cli-1',
        jsonb_set(v_cliente, '{archived}', 'true')),
      ('descontar no trabalho',       'booking',  'res-1',
        jsonb_set(v_reserva, '{expectedValueCents}', '5000')),
      ('trocar o cliente do trabalho','booking',  'res-1',
        jsonb_set(v_reserva, '{customerId}', '"cli-9"')),
      ('trocar a máquina do trabalho','booking',  'res-1',
        jsonb_set(v_reserva, '{machineIds}', '["maq-velha"]'::jsonb)),
      ('esticar a data contratada',   'booking',  'res-1',
        jsonb_set(v_reserva, '{endsAt}',
          to_jsonb((now() + interval '9 days')::text))),
      ('reduzir o recebido',          'receipt',  'rec-1',
        jsonb_set(v_recibo, '{amountCents}', '5000')),
      ('trocar o método de pagamento','receipt',  'rec-1',
        jsonb_set(v_recibo, '{method}', '"transfer"')),
      ('anular o recebimento',        'receipt',  'rec-1',
        jsonb_set(v_recibo, '{archived}', 'true')),
      ('abrir uma ficha de pessoal',  'collaborator', 'col-9',
        '{"id":"col-9","name":"Eu","costCents":250000}'::jsonb),
      ('inventar uma viatura',        'vehicle',  'via-9',
        '{"id":"via-9","plate":"AA-00-AA","purchasePriceCents":1}'::jsonb)
    ) as t(nome, entidade, id_local, payload)
  loop
    begin
      insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload)
      values (gen_random_uuid(), v_empresa, v_caso.entidade, v_caso.id_local, v_caso.payload);
      -- Chegou aqui: passou, e não devia.
      v_falhou := v_falhou || v_caso.nome;
    exception
      when insufficient_privilege then null;  -- 42501, o que se espera
    end;
  end loop;

  if cardinality(v_falhou) > 0 then
    raise exception 'FALHA: o operador conseguiu — %',
      array_to_string(v_falhou, '; ');
  end if;

  reset role;
  raise notice 'negativos: recusados todos (42501).';
  raise notice 'Campos do colaborador: PASSOU.';
end $$;

rollback;
