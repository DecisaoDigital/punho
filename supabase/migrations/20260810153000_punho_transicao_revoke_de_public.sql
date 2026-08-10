-- =============================================================================
-- Correcção: o revoke da transição não tirou o EXECUTE de PUBLIC.
-- =============================================================================
--
-- `20260810151000` termina com
--
--   revoke execute on function public.punho_migrar_entidades_do_instantaneo(uuid)
--     from authenticated, anon;
--
-- e isso não chega. O Postgres dá EXECUTE a **PUBLIC** por omissão em cada
-- `create function`; revogar dos dois papéis nominais deixa o de PUBLIC de pé,
-- e `authenticated` continua a poder executar por ser membro de PUBLIC. No ACL
-- via-se como `=X/postgres` — um `=X` sem papel à esquerda é PUBLIC.
--
-- A função é `security definer` e recebe `p_empresa` como argumento: qualquer
-- sessão autenticada podia mandá-la correr sobre a empresa de outra pessoa e
-- injectar-lhe operações no registo. As outras funções `security definer` do
-- Punho (`punho_projectar_entidade`, `punho_reprojectar_empresa`) já revogavam
-- de PUBLIC e estavam bem — foi só esta.
--
-- Apanhado pelos advisors do Supabase minutos depois de aplicar, a 10 Ago 2026.
--
-- ── Porque é que a 151000 não foi editada ───────────────────────────────────
--
-- Porque foi ela que correu em produção, tal como está. Editá-la punha o
-- repositório a dizer uma coisa e o `schema_migrations` a ter outra — que é
-- exactamente a deriva que a reconciliação de 10 de Agosto veio arrumar. O
-- histórico fica com o erro e com a correcção, por esta ordem, que é o que
-- aconteceu.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
--   grant execute on function public.punho_migrar_entidades_do_instantaneo(uuid) to public;
--   grant execute on function public.punho_painel_gravar(jsonb, timestamptz) to anon;
--
-- (Não há razão nenhuma para desfazer isto. Fica escrito porque é a regra da
-- fase, e uma regra que só se cumpre quando é cómoda não é uma regra.)
-- =============================================================================

revoke execute on function public.punho_migrar_entidades_do_instantaneo(uuid) from public;

-- Pelo mesmo motivo, e por higiene: o painel é do gestor autenticado e o `anon`
-- não tem nada que lhe tocar. É `security invoker` e a RLS já o barrava, mas
-- uma porta fechada é melhor do que uma porta com guarda.
revoke execute on function public.punho_painel_gravar(jsonb, timestamptz) from public, anon;
grant  execute on function public.punho_painel_gravar(jsonb, timestamptz) to authenticated;
