-- =============================================================================
-- Limpar seed de demonstração — empresa de ALUGUER DE MÁQUINAS (Punho)
-- =============================================================================
--
-- Apaga TUDO o que scripts/semear_demonstracao.sql tenha inserido para a
-- empresa indicada: basta que a linha tenha por_dispositivo =
-- 'semente-demonstracao' (a marca que aquele script usa em todas as linhas
-- que grava, sejam máquinas, clientes, leads, reservas, despesas ou
-- recebimentos). Não toca em nenhum outro dado — nem noutros seeds (ex.
-- 'seed-mare-alta'), nem em registos reais criados pela app.
--
-- COMO SE CORRE
-- --------------
-- 1. Edita `v_empresa` abaixo com o mesmo uuid que usaste em
--    scripts/semear_demonstracao.sql.
-- 2. Corre com psql:
--      psql "$SUPABASE_DB_URL" -f scripts/limpar_demonstracao.sql
--    ou cola o conteúdo no SQL Editor do Supabase.
--
-- É seguro correr isto mesmo que o seed nunca tenha sido aplicado, ou já
-- tenha sido apagado antes — o delete simplesmente não encontra nada e não
-- faz nada.
--
-- =============================================================================

do $$
declare
  v_empresa uuid := '37b847eb-de1c-4f29-820d-814e069806ee'; -- <-- põe aqui o mesmo uuid usado em semear_demonstracao.sql
  v_tag     text := 'semente-demonstracao';
  v_apagadas int;
begin
  delete from public.punho_operacoes
   where empresa_id = v_empresa
     and por_dispositivo = v_tag;

  get diagnostics v_apagadas = row_count;
  raise notice 'punho: % linha(s) de punho_operacoes apagada(s) para a empresa % (tag %)', v_apagadas, v_empresa, v_tag;
end $$;
