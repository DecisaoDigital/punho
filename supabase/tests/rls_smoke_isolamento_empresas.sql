-- ============================================================================
-- Smoke test de RLS — isolamento entre empresas
--
-- NÃO é auditoria de RLS. Verifica o mínimo indispensável, em dois blocos:
--   1. um utilizador da empresa B não vê nem toca nas máquinas da empresa A;
--   2. uma conta comum não lê as tabelas partilhadas com o WashInvoice.
--
-- COMO CORRER
--   Cola no SQL Editor do Supabase (role service_role) e carrega em Run.
--   Corre inteiro dentro de uma transacção que termina em ROLLBACK: não deixa
--   nada na base.
--
--   ATENÇÃO a quem o correr por fora do SQL Editor: nem toda a ferramenta
--   respeita o `begin`/`rollback` deste ficheiro. O MCP da Supabase, por
--   exemplo, executa e faz commit — a 10/08/2026 correu-se o bloco 1 por lá e
--   ficaram na base duas contas, duas empresas e uma operação, que houve que
--   apagar à mão. Ou se corre no SQL Editor, ou se limpa a seguir:
--
--     delete from punho_operacoes where entidade_id like 'maquina-de-teste-%'
--                                    or entidade_id like 'intruso-maquina-de-teste-%';
--     delete from punho_membros where user_id in
--       (select id from auth.users where email in ('alice@a.pt','bruno@b.pt'));
--     delete from punho_empresas where nome in ('Empresa A','Empresa B');
--     delete from auth.users where email in
--       ('alice@a.pt','bruno@b.pt','ninguem@lado-nenhum.pt');
--
-- RESULTADO
--   Duas linhas de `notice` a dizer PASSOU => passou.
--   Excepção com a mensagem do cenário que falhou => P0, parar tudo.
--
-- ============================================================================
-- PORQUE FOI REESCRITO — 10 de Agosto de 2026
--
-- A versão anterior morria a 07/08 no setup, antes do primeiro assert:
--
--   ERROR: 55000: cannot insert into view "punho_maquinas"
--
-- Não era um bug do teste: era o teste a ficar para trás do modelo. As
-- `punho_maquinas` deixaram de ser uma tabela e passaram a ser uma **vista**
-- sobre `punho_operacoes` — a última operação de cada `entidade='machine'`,
-- por `(empresa_id, entidade_id)`. Escreve-se no log; lê-se pela vista.
--
-- Isso muda o teste para melhor. Antes escrevia-se directamente na tabela que
-- se ia ler a seguir, o que só provava a política dessa tabela. Agora a escrita
-- entra pelo caminho de verdade — o log, com os quatro triggers dele — e a
-- leitura sai pela vista. Se a vista deixasse de ser `security_invoker`, a RLS
-- de `punho_operacoes` deixava de se aplicar a quem lê e a vista passava a
-- mostrar tudo a toda a gente: é precisamente isso que o bloco 1 apanha.
--
-- A Alice também deixou de ser criada por `insert` de service_role e passou a
-- escrever a máquina dela **como ela própria**, autenticada. Assim o teste
-- prova as duas metades da mesma política: que ela escreve, e que o Bruno não.
-- ============================================================================

begin;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco 1 — uma empresa não vê a outra
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_alice uuid := gen_random_uuid();
  v_bruno uuid := gen_random_uuid();
  v_empresa_a uuid;
  v_empresa_b uuid;
  v_id_local text := 'maquina-de-teste-' || substr(gen_random_uuid()::text, 1, 8);
  v_visiveis integer;
  v_escreveu boolean := false;
begin
  -- ---------------------------------------------------------------- setup --
  -- Corre como service_role: a RLS não se aplica, e é isso que se quer para
  -- montar o cenário. Os asserts é que correm todos como `authenticated`.
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_alice, 'alice@a.pt', '{"app":"punho"}'::jsonb),
         (v_bruno, 'bruno@b.pt', '{"app":"punho"}'::jsonb);

  insert into public.punho_empresas (nome) values ('Empresa A') returning id into v_empresa_a;
  insert into public.punho_empresas (nome) values ('Empresa B') returning id into v_empresa_b;

  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (v_empresa_a, v_alice, 'gestor', true),
         (v_empresa_b, v_bruno, 'gestor', true);

  -- ------------------------------------------- a Alice escreve, como Alice --
  -- Pelo log, que é o caminho real. Se a política de INSERT de
  -- `punho_operacoes` estiver mal, isto rebenta aqui — e é um resultado tão
  -- válido como qualquer outro assert.
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_alice, 'role', 'authenticated')::text, true);

  -- O `id` vai explícito: `punho_operacoes.id` não tem `default`. É a app que
  -- carimba o id da operação, para poder reenviá-la sem duplicar. Foi aqui que
  -- a primeira versão desta reescrita rebentou, com 23502.
  insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em)
  values (gen_random_uuid(), v_empresa_a, 'machine', v_id_local,
          '{"name":"Mini escavadora da Alice"}'::jsonb, now());

  select count(*) into v_visiveis
  from public.punho_maquinas where empresa_id = v_empresa_a and id_local = v_id_local;
  if v_visiveis <> 1 then
    raise exception
      'FALHA P0: a Alice escreveu a máquina mas a vista mostra-lhe % linhas.', v_visiveis;
  end if;

  -- ------------------------------------------------- o Bruno não vê nada --
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bruno, 'role', 'authenticated')::text, true);

  select count(*) into v_visiveis
  from public.punho_maquinas where empresa_id = v_empresa_a;
  if v_visiveis <> 0 then
    raise exception
      'FALHA P0: o Bruno (empresa B) vê % máquina(s) da empresa A.', v_visiveis;
  end if;

  -- Sem filtro nenhum: a empresa dele não tem máquinas, logo não pode ver uma.
  -- É este o assert que apanha uma vista que deixe de ser `security_invoker`.
  select count(*) into v_visiveis from public.punho_maquinas;
  if v_visiveis <> 0 then
    raise exception
      'FALHA P0: o Bruno vê % máquina(s) e a empresa dele não tem nenhuma.', v_visiveis;
  end if;

  -- O mesmo pelo log, que é de onde a vista lê. Uma vista pode estar certa e a
  -- tabela por baixo aberta — quem souber o nome dela lê à mesma.
  select count(*) into v_visiveis
  from public.punho_operacoes where empresa_id = v_empresa_a;
  if v_visiveis <> 0 then
    raise exception
      'FALHA P0: o Bruno lê % operação(ões) da empresa A directamente no log.', v_visiveis;
  end if;

  -- ------------------------------------------ nem escreve na empresa alheia --
  begin
    insert into public.punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em)
    values (gen_random_uuid(), v_empresa_a, 'machine', 'intruso-' || v_id_local,
            '{"name":"intruso"}'::jsonb, now());
    v_escreveu := true;
  exception
    when insufficient_privilege then null;  -- esperado: a RLS recusou
  end;
  if v_escreveu then
    raise exception 'FALHA P0: o Bruno conseguiu escrever no log da empresa A.';
  end if;

  -- --------------------------------------------------------- contraprova --
  -- Sem isto, uma RLS que bloqueie tudo a toda a gente passava por sucesso.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_alice, 'role', 'authenticated')::text, true);

  select count(*) into v_visiveis
  from public.punho_maquinas where empresa_id = v_empresa_a and id_local = v_id_local;
  if v_visiveis <> 1 then
    raise exception
      'FALHA P0: a Alice não vê a máquina da própria empresa (% linhas).', v_visiveis;
  end if;

  reset role;
  raise notice 'Bloco 1 — isolamento entre empresas: PASSOU.';
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco 2 — as tabelas partilhadas com o WashInvoice
--
-- Guarda o que a migration `fechar_tabelas_partilhadas_do_pos` fez. Estas sete
-- estiveram abertas a qualquer conta autenticada até 10/08/2026: a carteira de
-- clientes com NIF, os IP públicos e o GPS dos terminais, as provas de
-- aceitação de termos. O predicado era `auth.role() = 'authenticated'`, que só
-- diz que alguém fez login.
--
-- Uma conta acabada de criar, sem empresa nenhuma, é o pior caso e o mais
-- barato de montar.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_ninguem uuid := gen_random_uuid();
  t text;
  v_visiveis integer;
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_ninguem, 'ninguem@lado-nenhum.pt', '{"app":"punho"}'::jsonb);

  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ninguem, 'role', 'authenticated')::text, true);

  foreach t in array array[
    'clientes', 'pings', 'aceites_termos', 'pedidos_renovacao',
    'licencas_audit', 'company_signature_settings', 'invoice_signature_logs'
  ] loop
    execute format('select count(*) from public.%I', t) into v_visiveis;
    if v_visiveis <> 0 then
      raise exception
        'FALHA P0: uma conta sem empresa nenhuma vê % linha(s) em %.', v_visiveis, t;
    end if;
  end loop;

  -- `clientes` tinha uma política `FOR ALL` sem `with_check`, e nesse caso o
  -- Postgres usa o `using` também para escrever. Ler zero não prova que não
  -- escreve.
  update public.clientes set nome = nome || ' (invadido)';
  get diagnostics v_visiveis = row_count;
  if v_visiveis <> 0 then
    raise exception 'FALHA P0: uma conta sem empresa alterou % linha(s) em clientes.', v_visiveis;
  end if;

  reset role;
  raise notice 'Bloco 2 — tabelas partilhadas com o WashInvoice: PASSOU.';
end $$;

rollback;
