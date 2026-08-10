-- =============================================================================
-- `punho_fechar_funcao_nova` com search_path fixo.
-- =============================================================================
--
-- Os advisors, corridos a seguir a 20260810161000, apanharam um WARN novo — e
-- era meu: `function_search_path_mutable` na função do gatilho de evento.
--
-- Aqui o risco é pequeno (a função é `security invoker`, corre com os
-- privilégios de quem faz o DDL, e não há escalada a ganhar). Mas uma tarefa
-- que existe para as funções deixarem de nascer mal feitas não pode deixar
-- atrás de si uma função mal feita.
--
-- `pg_catalog` primeiro porque é de lá que vêm `format` e
-- `pg_event_trigger_ddl_commands`. `public` fica para o `revoke` conseguir
-- resolver o nome do objecto, embora o `object_identity` já venha qualificado.
--
-- Nota: substituir a função dispara o próprio gatilho — o tag de `create or
-- replace function` é `CREATE FUNCTION`. Ele revoga PUBLIC de si mesmo, que já
-- estava revogado. `revoke` é idempotente e não há recursão: o gatilho só
-- responde a `CREATE FUNCTION/PROCEDURE/AGGREGATE`, não a `REVOKE`.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
-- Reaplicar 20260810161000, que recria a função sem o `set search_path`.
-- =============================================================================

create or replace function public.punho_fechar_funcao_nova()
returns event_trigger
language plpgsql
set search_path = pg_catalog, public
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
      execute format('revoke execute on routine %s from public', r.object_identity);
    exception when others then
      raise warning
        'punho: não consegui fechar %s a PUBLIC (%). Confirmar com '
        'supabase/tests/rls_funcoes_fechadas.sql.', r.object_identity, sqlerrm;
    end;
  end loop;
end;
$$;
