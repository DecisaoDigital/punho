-- ============================================================================
-- Guarda: nenhuma função de `public` está aberta a mais ninguém do que o
-- previsto — e uma função nova nasce fechada.
--
-- PORQUE EXISTE
--   O Postgres dá EXECUTE a PUBLIC em cada `create function`. Isso abriu, em
--   três dias, as funções de projecção (8 Ago), a `punho_colaborador_pode_
--   escrever` (9 Ago) e a `punho_migrar_entidades_do_instantaneo` (10 Ago) —
--   esta última `security definer`, a receber `p_empresa` como argumento, ou
--   seja: qualquer sessão autenticada a mandá-la correr sobre a empresa de
--   outra pessoa. Correr os advisors depois de cada migration apanha-o **depois
--   de estar em produção**. Este ficheiro apanha-o antes.
--
-- COMO CORRER
--   SQL Editor do Supabase (service_role), ou MCP. É só leitura, com uma
--   excepção que se limpa sozinha (bloco D cria e apaga uma função).
--
-- RESULTADO
--   Cinco `notice` a dizer PASSOU => passou.
--   Excepção => alguém abriu uma porta. Ler a mensagem: diz qual e a quem.
--
-- ── SE ESTE TESTE TE ESTIVER A CHATEAR ──────────────────────────────────────
--
-- A tentação é acrescentar o nome à lista. Antes disso: uma função de `public`
-- executável por `anon` ou por `authenticated` é chamável por qualquer pessoa
-- com a chave pública da app, que está dentro do APK. Se for `security
-- definer`, corre sem RLS. Se receber um id como argumento, o argumento é dela.
--
-- Só entra na lista o que um cliente chama mesmo. O gate de negócio vai
-- **dentro** da função; o grant é o mínimo.
--
-- ── ANTES DE FECHAR UMA FUNÇÃO, PROCURA-A NOS QUATRO SÍTIOS ─────────────────
--
-- Já apareceram dois. O terceiro será noutro sítio qualquer.
--
--   with alvo as (select oid, proname from pg_proc p
--                 join pg_namespace n on n.oid=p.pronamespace
--                 where n.nspname='public' and proname = 'A_FUNCAO')
--   select 'politica: '||tablename||'.'||policyname from pg_policies, alvo
--     where schemaname='public'
--       and (coalesce(qual,'')||' '||coalesce(with_check,'')) ~ ('\m'||proname||'\M')
--   union all
--   select 'vista: '||c.relname||' ('||
--          case when c.reloptions::text like '%security_invoker%'
--               then 'INVOKER — precisa do grant' else 'definer' end||')'
--     from pg_class c join pg_namespace n on n.oid=c.relnamespace, alvo
--     where n.nspname='public' and c.relkind in ('v','m')
--       and pg_get_viewdef(c.oid) ~ ('\m'||proname||'\M')
--   union all
--   select 'corpo de '||f.proname||' ('||
--          case when f.prosecdef then 'definer — nao precisa'
--               else 'INVOKER — precisa do grant' end||')'
--     from pg_proc f join pg_namespace n on n.oid=f.pronamespace, alvo
--     where n.nspname='public' and f.oid <> alvo.oid
--       and f.prosrc ~ ('\m'||proname||'\M')
--   union all
--   select 'constraint: '||c.conrelid::regclass||'.'||c.conname
--     from pg_constraint c, alvo where pg_get_constraintdef(c.oid) ~ ('\m'||proname||'\M');
--
--   Uma política ou uma vista `security_invoker` avaliam-se com os privilégios
--   de QUEM CONSULTA. Fechar a função aí dá `permission denied for function`
--   em vez de «vazio» — e não é um bocado da app que morre, é a app.
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco 0 — a comparação por nome é válida?
--
-- Os blocos B e C comparam listas de NOMES. Isso só é sólido enquanto não
-- houver sobrecargas: duas funções com o mesmo nome e assinaturas diferentes
-- passariam pelo mesmo item da lista, e uma delas escapava à revisão.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare v text;
begin
  select string_agg(proname, ', ') into v from (
    select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prorettype <> 'trigger'::regtype
    group by p.proname having count(*) > 1
  ) t;
  if v is not null then
    raise exception
      'Sobrecargas em public (%). As listas deste teste são por nome: passa-as '
      'a nome+assinatura antes de continuar, ou uma delas escapa.', v;
  end if;
  raise notice 'Bloco 0 — sem sobrecargas, comparação por nome é válida: PASSOU.';
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco A — ninguém, em circunstância nenhuma, por PUBLIC
--
-- Sem lista de excepções de propósito. PUBLIC nunca foi uma decisão: é o valor
-- de fábrica do Postgres. Quem quiser abrir uma função abre-a a um papel com
-- nome, e esse nome aparece no bloco B ou no C, onde se vê.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare v text;
begin
  select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', E'\n  ')
    into v
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and has_function_privilege('public', p.oid, 'execute');

  if v is not null then
    raise exception
      E'FALHA: funções de public executáveis por PUBLIC:\n  %\n'
      'Se são novas, o gatilho de evento punho_funcao_nova_nasce_fechada não '
      'as apanhou — ver o bloco E. Fechar com: '
      'revoke execute on routine public.NOME(ARGS) from public;', v;
  end if;
  raise notice 'Bloco A — nada aberto a PUBLIC: PASSOU.';
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco B — a lista do `anon`
--
-- Cinco, e a razão de cada uma:
--
--   punho_validar_convite   é chamada ANTES do signUp, em registo_screen.dart,
--                           para dar a razão concreta de um código imprestável
--                           em vez do erro genérico do gatilho. Fechá-la parte
--                           o registo com convite.
--
--   as outras quatro        estão em políticas com `roles = {public}`. Enquanto
--                           a política servir PUBLIC, `anon` tem de poder
--                           executar o que ela chama, ou qualquer consulta
--                           anónima dá 42501 em vez de devolver vazio. Não
--                           recebem argumentos e derivam tudo de auth.uid():
--                           para uma sessão anónima devolvem null ou false.
--
-- PENDENTE: passar essas políticas a `to authenticated` fecha as quatro de uma
-- vez. Mexe em políticas e exige o smoke de isolamento por cima — tarefa
-- própria, não um remendo a meio de outra coisa.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare
  aprovadas text[] := array[
    'punho_validar_convite',
    'punho_empresa_atual', 'punho_e_gestor', 'punho_membro_ativo', 'punho_perfil_na_empresa'
  ];
  a_mais text;
  em_falta text;
begin
  select string_agg(proname, ', ' order by proname) into a_mais
  from (select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname='public' and p.prorettype <> 'trigger'::regtype
          and has_function_privilege('anon', p.oid, 'execute')) t
  where proname <> all (aprovadas);

  if a_mais is not null then
    raise exception
      'FALHA: o `anon` ganhou funções que não estão na lista: %. '
      'Ou entram na lista deste ficheiro com a razão escrita ao lado, ou '
      'saem: revoke execute on routine public.NOME(ARGS) from anon;', a_mais;
  end if;

  select string_agg(x, ', ') into em_falta from unnest(aprovadas) x
  where not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname = x
      and has_function_privilege('anon', p.oid, 'execute'));

  if em_falta is not null then
    raise exception
      'FALHA: o `anon` perdeu funções que a app precisa: %. '
      'O registo com convite e as políticas {public} deixam de funcionar.', em_falta;
  end if;
  raise notice 'Bloco B — as cinco do anon, nem mais nem menos: PASSOU.';
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco C — a lista do `authenticated`
--
-- Esta lista é a fronteira pública da base de dados. Trinta e cinco funções, e
-- **três clientes**: o Punho, o Punho OP e o Control, todos no mesmo projecto
-- Supabase e no mesmo schema. Fechar aqui por distracção parte um deles.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare
  aprovadas text[] := array[
    -- as cinco que o anon também tem
    'punho_validar_convite', 'punho_empresa_atual', 'punho_e_gestor',
    'punho_membro_ativo', 'punho_perfil_na_empresa',

    -- Punho (gestor), por RPC
    'punho_meu_acesso', 'punho_pedir_acesso', 'punho_criar_convite',
    'punho_guardar_estado_operacional', 'punho_painel_gravar',
    'punho_pedidos_da_minha_empresa', 'punho_pedidos_decididos_da_minha_empresa',
    'punho_gestor_decidir_pedido', 'punho_criar_convite_contabilista',
    'punho_lacunas_contabilista', 'punho_guardar_resposta_gestor',

    -- Punho OP (operador), por RPC
    'punho_guardar_o_meu_perfil', 'punho_reservas_em_dia',

    -- Control (admin), por RPC
    'is_admin', 'meu_estado_acesso', 'criar_convite_organizacao',
    'decidir_pedido_acesso', 'apagar_pedido_acesso', 'apagar_licenca',
    'licenca_dependentes', 'punho_apagar_pedido', 'punho_decidir_pedido',
    'punho_definir_limite', 'punho_listar_empresas_admin',
    'punho_listar_pedidos_admin', 'punho_nomes_por_terminal',

    -- ninguém as chama; se fecharem, a RLS deixa de poder ser avaliada
    'punho_colaborador_pode_escrever',  -- política em punho_operacoes
    'punho_nome_empresa_atual',         -- política em punho_pedidos_acesso
    'punho_id_estavel',                 -- SETE vistas security_invoker do painel

    -- compatibilidade: substituída por punho_meu_acesso a 5 Ago, mas um APK
    -- que já esteja num telemóvel pode ser da versão anterior
    'punho_meu_estado_acesso'
  ];
  a_mais text;
  em_falta text;
begin
  select string_agg(proname, ', ' order by proname) into a_mais
  from (select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname='public' and p.prorettype <> 'trigger'::regtype
          and has_function_privilege('authenticated', p.oid, 'execute')) t
  where proname <> all (aprovadas);

  if a_mais is not null then
    raise exception
      'FALHA: o `authenticated` ganhou funções fora da lista: %. '
      'Se um cliente as chama mesmo, entram aqui com o ficheiro que as chama '
      'escrito ao lado. Se não, saem: '
      'revoke execute on routine public.NOME(ARGS) from authenticated;', a_mais;
  end if;

  select string_agg(x, ', ') into em_falta from unnest(aprovadas) x
  where not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname = x
      and has_function_privilege('authenticated', p.oid, 'execute'));

  if em_falta is not null then
    raise exception
      'FALHA: o `authenticated` perdeu funções que um dos três clientes chama: '
      '%. Ver qual em supabase/migrations/20260810160000.', em_falta;
  end if;
  raise notice 'Bloco C — as 35 do authenticated, nem mais nem menos: PASSOU.';
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco D — uma função nova nasce fechada
--
-- É o assert que impede tudo o resto de ser uma limpeza pontual. Sem ele, o
-- ficheiro só diz que hoje está arrumado.
--
-- Nota para quem lê o histórico: `alter default privileges in schema public
-- revoke execute on functions from public` é aceite sem erro e NÃO FUNCIONA. O
-- Postgres parte dos valores de fábrica e faz `aclmerge`, que só soma
-- (`ACL_MODECHG_ADD`). O que fecha o PUBLIC é o gatilho de evento do bloco E.
-- Foi este assert que deu por isso, a 10 Ago 2026.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_anon boolean;
  v_auth boolean;
  v_public boolean;
  v_acl text;
begin
  execute 'create function public.zzz_prova_nasce_fechada(p integer) '
          'returns int language sql as ''select p''';

  select has_function_privilege('anon',          p.oid, 'execute'),
         has_function_privilege('authenticated', p.oid, 'execute'),
         has_function_privilege('public',        p.oid, 'execute'),
         coalesce(array_to_string(p.proacl, ' | '), '(nulo)')
    into v_anon, v_auth, v_public, v_acl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'zzz_prova_nasce_fechada';

  execute 'drop function public.zzz_prova_nasce_fechada(integer)';

  if v_anon or v_auth or v_public then
    raise exception
      'FALHA: uma função nova nasceu ABERTA (anon=%, authenticated=%, public=%). '
      'ACL: %. Confirmar o gatilho de evento punho_funcao_nova_nasce_fechada e '
      'o pg_default_acl de `postgres` para o schema public.',
      v_anon, v_auth, v_public, v_acl;
  end if;
  raise notice 'Bloco D — função nova nasce fechada (ACL: %): PASSOU.', v_acl;
end $$;

-- ────────────────────────────────────────────────────────────────────────────
-- Bloco E — o gatilho de evento está de pé e ligado
--
-- É melhor-esforço por desenho: engole os próprios erros para nunca bloquear
-- DDL na base inteira. Um `drop event trigger` por distracção não dá erro
-- nenhum — só volta a deixar as funções nascerem abertas, em silêncio, até
-- alguém correr este ficheiro.
-- ────────────────────────────────────────────────────────────────────────────
do $$
declare v_estado char;
begin
  select evtenabled into v_estado
  from pg_event_trigger where evtname = 'punho_funcao_nova_nasce_fechada';

  if v_estado is null then
    raise exception
      'FALHA: o gatilho de evento punho_funcao_nova_nasce_fechada desapareceu. '
      'Reaplicar supabase/migrations/20260810161000.';
  end if;
  if v_estado = 'D' then
    raise exception
      'FALHA: o gatilho de evento punho_funcao_nova_nasce_fechada está '
      'DESACTIVADO. `alter event trigger punho_funcao_nova_nasce_fechada enable;`';
  end if;
  raise notice 'Bloco E — gatilho de evento de pé (evtenabled=%): PASSOU.', v_estado;
end $$;
