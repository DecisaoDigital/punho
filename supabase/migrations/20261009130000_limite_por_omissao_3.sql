-- Plano criado na aprovação sem número indicado nasce com 3 vagas (como o
-- aviso do onboarding), e não com 1. Reescreve a função viva por substituição
-- para não repetir o corpo inteiro.
do $$
declare v_def text;
begin
  select pg_get_functiondef('public.punho_decidir_pedido(uuid,text,uuid,integer)'::regprocedure) into v_def;
  v_def := replace(v_def, 'p_limite_utilizadores, 1), 1)', 'p_limite_utilizadores, 3), 1)');
  execute v_def;
end $$;
