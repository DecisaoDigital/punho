-- =============================================================================
-- O `alter default privileges` não fecha o PUBLIC. Isto fecha.
-- =============================================================================
--
-- Aplicar **depois** de 20260810160000.
--
-- ── O que a prova mostrou ────────────────────────────────────────────────────
--
-- A migration anterior acaba com
--
--   alter default privileges in schema public
--     revoke execute on functions from public, anon, authenticated;
--
-- Criou-se a seguir uma função de teste. Nasceu com
--
--   =X/postgres | postgres=X/postgres | service_role=X/postgres
--                                     ^^^^^^^^^^^^ o `=X` é PUBLIC
--
-- `anon` e `authenticated` saíram — essa metade funcionou, e vê-se em
-- `pg_default_acl`, que passou a `postgres=X | service_role=X`. Mas o `=X` de
-- PUBLIC ficou, e `anon` é membro de PUBLIC: a função nova continuava
-- executável por qualquer sessão anónima.
--
-- ── Porquê, e porque é que não há volta a dar por ali ───────────────────────
--
-- Ao criar um objecto, o Postgres faz (`aclchk.c`, `get_user_default_acl`):
--
--   result = acldefault(objtype, ownerId);      -- os valores de fábrica
--   result = aclmerge(result, defacl, ownerId); -- o que está em pg_default_acl
--
-- e `aclmerge` chama `aclupdate` com `ACL_MODECHG_ADD`. **Só soma.** O que está
-- em `pg_default_acl` pode acrescentar privilégios aos de fábrica; nunca lhos
-- pode tirar. E EXECUTE a PUBLIC nas funções é de fábrica.
--
-- Ou seja: `alter default privileges ... revoke ... from public` é aceite sem
-- erro nenhum, fica registado, e não faz nada. É exactamente a forma de
-- «ficares a pensar que serve» — só se apanha criando uma função e olhando
-- para o ACL, que é o passo 3(d) desta tarefa.
--
-- ── A alternativa ───────────────────────────────────────────────────────────
--
-- Um gatilho de evento em `ddl_command_end`. O papel `postgres` da Supabase não
-- é superuser mas pode criar gatilhos de evento — confirmado nesta base a 10
-- Ago 2026.
--
-- Desenho defensivo, por esta ordem de prioridades:
--
--   1. **Nunca bloquear DDL.** Um gatilho de evento que rebenta impede
--      `create function` em toda a base, incluindo as migrações internas da
--      plataforma. O `revoke` vai dentro de um bloco com `exception when
--      others`, que degrada para `warning`. Uma porta que não fechou é mau; a
--      base inteira parada é pior.
--   2. **Só o schema `public`.** Nada de auth, storage, realtime, extensions.
--   3. **Só PUBLIC.** Os grants explícitos a `anon` e `authenticated` — os da
--      lista aprovada em 20260810160000 — não são tocados. Quem fecha esses é
--      o `pg_default_acl`, que já não os dá a ninguém.
--
-- Como o gatilho é melhor-esforço e não garantia, quem garante é o teste:
-- `supabase/tests/rls_funcoes_fechadas.sql` falha se aparecer uma função
-- executável por PUBLIC ou por `anon` fora da lista aprovada. O gatilho evita o
-- erro; o teste prova que ele não aconteceu.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
--   drop event trigger if exists punho_funcao_nova_nasce_fechada;
--   drop function if exists public.punho_fechar_funcao_nova();
--
-- Não toca em dados nem repõe privilégio nenhum já revogado: a partir daí é que
-- as funções **novas** voltam a nascer abertas a PUBLIC.
-- =============================================================================

create or replace function public.punho_fechar_funcao_nova()
returns event_trigger
language plpgsql
-- Sem `security definer` de propósito: corre como quem executou o DDL, que é o
-- dono da função acabada de criar e portanto tem sempre o direito de revogar
-- sobre ela. Com `definer` fixo em `postgres`, uma função criada por
-- `supabase_admin` ficava fora do alcance.
as $$
declare
  r record;
begin
  for r in
    select object_identity
    from pg_event_trigger_ddl_commands()
    where schema_name = 'public'
      and object_type in ('function', 'procedure', 'aggregate')
  loop
    begin
      -- `routine` cobre funções, procedimentos e agregados numa só sintaxe.
      execute format('revoke execute on routine %s from public', r.object_identity);
    exception when others then
      raise warning
        'punho: não consegui fechar %s a PUBLIC (%). Confirmar com '
        'supabase/tests/rls_funcoes_fechadas.sql.', r.object_identity, sqlerrm;
    end;
  end loop;
end;
$$;

comment on function public.punho_fechar_funcao_nova() is
  'Gatilho de evento: tira o EXECUTE de PUBLIC a cada função criada em public. '
  'Existe porque `alter default privileges ... revoke ... from public` é aceite '
  'e não faz nada — aclmerge só soma aos valores de fábrica. Melhor-esforço: '
  'nunca bloqueia DDL. Quem garante é rls_funcoes_fechadas.sql.';

drop event trigger if exists punho_funcao_nova_nasce_fechada;

create event trigger punho_funcao_nova_nasce_fechada
  on ddl_command_end
  when tag in ('CREATE FUNCTION', 'CREATE PROCEDURE', 'CREATE AGGREGATE')
  execute function public.punho_fechar_funcao_nova();

-- -----------------------------------------------------------------------------
-- E o que já cá estava
-- -----------------------------------------------------------------------------
-- O gatilho só apanha o que nascer daqui para a frente. As funções que já
-- existem levam o mesmo tratamento agora, incluindo as de gatilho — que a
-- 20260810160000 também limpou, e que não precisam de EXECUTE para disparar.
revoke execute on all functions in schema public from public;
