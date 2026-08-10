-- =============================================================================
-- A fronteira: o instantâneo deixa de escrever entidades.
-- =============================================================================
--
-- Aplicar **depois** de 20260810151000 (a transição). Esta migration não move
-- dados nenhuns — corta um caminho de escrita que a transição já esvaziou.
--
-- ── O que estava mal ─────────────────────────────────────────────────────────
--
-- `punho_estado_operacional_projectar` pegava no instantâneo inteiro e
-- projectava as oito listas de entidades para as tabelas, com `p_quando =
-- now()` e sem guarda de ordem. A consequência, na prática:
--
--   o operador entrega a máquina e a reserva passa a `rented`; o gestor, com a
--   cópia local ainda atrasada, grava os custos fixos; o instantâneo sobe
--   inteiro, o gatilho reprojecta, e a reserva volta a `confirmed`.
--
-- Sem erro, sem aviso. É a avaria de 4 de Agosto de 2026, corrigida do lado da
-- app (que deixou de importar entidades do instantâneo) e mantida aberta do
-- lado do servidor. E viola a invariante que a migration da projecção declara
-- na sua linha 36: **o registo manda, as tabelas são a sua leitura**.
--
-- O `now()` era o que a tornava sempre vencedora: qualquer reprojecção da
-- ficha carimbava as entidades com o instante da subida, mais recente do que
-- qualquer facto real. O `where dados is distinct from excluded.dados` que lá
-- está não protege disto — só evita reescritas idênticas, não reescritas
-- velhas.
--
-- ── Porque é que o gatilho desaparece em vez de ser corrigido ───────────────
--
-- Depois desta fase o instantâneo tem exactamente duas coisas: o onboarding
-- (com os custos fixos) e o histórico mensal. Nenhuma delas se projecta para
-- tabela nenhuma — `punho_empresas.dados` é preenchido pelo caminho do
-- onboarding, com gatilho próprio para a licença. O gatilho do instantâneo
-- ficava sem nada para fazer.
--
-- `punho_projectar_ficha` sai com ele. O nome sempre foi enganador: nunca
-- projectou ficha nenhuma, projectava entidades a partir da ficha.
--
-- ── E a reconstrução ────────────────────────────────────────────────────────
--
-- `punho_reprojectar_empresa` semeava-se do instantâneo antes de aplicar o
-- registo. Passa a ser só do registo, que é o que a invariante diz que ela
-- deve ser — e, depois da transição, o registo tem tudo o que o instantâneo
-- tinha.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
-- Reaplicar 20260807211049_punho_projeccao_das_tabelas.sql, que recria
-- `punho_projectar_ficha`, `punho_estado_operacional_projectar`, o gatilho e a
-- versão anterior de `punho_reprojectar_empresa`. É idempotente (tudo `create
-- or replace` / `drop trigger if exists`) e não toca em dados.
--
-- Nada se perde a desfazer: as entidades que o gatilho projectava continuam
-- todas no registo, e é de lá que as tabelas vivem.
-- =============================================================================

drop trigger if exists punho_estado_operacional_projectar on public.punho_estado_operacional;
drop function if exists public.punho_estado_operacional_projectar();
drop function if exists public.punho_projectar_ficha(uuid, jsonb, timestamptz);

-- -----------------------------------------------------------------------------
-- Reconstruir: só do registo
-- -----------------------------------------------------------------------------
create or replace function public.punho_reprojectar_empresa(p_empresa uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_op    record;
  v_conta integer := 0;
begin
  -- Sem semente do instantâneo. O registo é a história completa: reaplicá-lo
  -- por ordem de `seq` reconstrói as tabelas tal como aconteceram.
  for v_op in
    select empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador
    from punho_operacoes
    where empresa_id = p_empresa
    order by seq
  loop
    perform punho_projectar_entidade(
      v_op.empresa_id, v_op.entidade, v_op.entidade_id,
      v_op.payload, v_op.feito_em, v_op.por_utilizador
    );
    v_conta := v_conta + 1;
  end loop;

  return v_conta;
end;
$$;

comment on function public.punho_reprojectar_empresa(uuid) is
  'Reconstrói as tabelas a partir do registo, por ordem de seq. Só do registo: '
  'o instantâneo deixou de ser dono de entidades na Fase 3.';
