-- =============================================================================
-- As funções de trigger deixam de estar ao alcance do anon.
-- =============================================================================
--
-- APLICADA EM PRODUÇÃO A 2026-08-08 00:10 UTC, com o nome
-- `punho_revogar_funcoes_trigger_de_anon_2026_08_07`. Este ficheiro traz para o
-- repo o que já lá estava.
--
-- Uma função que devolve `trigger` não tem razão nenhuma para estar executável
-- por anon ou authenticated: quem a invoca é o motor de triggers, por dentro,
-- como dono da tabela, e sem depender destes GRANT. Estarem abertas é só
-- superfície de ataque — e algumas delas escrevem em tabelas de outra empresa
-- se forem chamadas com os argumentos certos.
--
-- Vai em bloco de propósito, e não com uma lista de nomes: a lista fica
-- desactualizada à primeira função nova, e o que interessa é a regra. Como só
-- revoga o que ainda está aberto, correr isto outra vez não faz nada.
-- =============================================================================

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure::text as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype = 'trigger'::regtype
      and (has_function_privilege('anon', p.oid, 'EXECUTE')
        or has_function_privilege('authenticated', p.oid, 'EXECUTE'))
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
