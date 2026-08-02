-- ============================================================================
-- Punho — editar o limite de colaboradores de uma empresa, pelo Control.
--
-- COMO APLICAR
--   Cola no SQL Editor do projeto Supabase partilhado (oefqbkhioncakojipqyx)
--   e carrega em Run. Tem de correr DEPOIS de:
--     * 20260725_punho_core.sql                     (cria punho_subscricoes)
--     * 20260801_punho_aprovacao_pelo_control.sql   (cria public.is_admin(),
--       punho_listar_empresas_admin())
--   É idempotente: pode correr as vezes que forem precisas.
--
-- O QUE FAZ
--   Uma RPC para o Control (admin global) editar o limite de colaboradores
--   activos de uma empresa já existente, fora do fluxo de criação:
--     punho_definir_limite()   muda punho_subscricoes.limite_colaboradores_ativos
--
--   Nenhuma tabela nova, nenhuma policy de escrita para `authenticated`. O
--   admin actua só por esta função `security definer`, que verifica
--   `public.is_admin()` à cabeça — mesmo padrão de
--   20260801_punho_aprovacao_pelo_control.sql.
--
-- NOTA SOBRE O LIMITE DE UTILIZADORES
--   `punho_empresas` não tem coluna de limite — quem o guarda é
--   `punho_subscricoes.limite_colaboradores_ativos`. Uma empresa pode ter mais
--   do que uma linha em `punho_subscricoes`; `punho_listar_empresas_admin()`
--   já lê o limite da subscrição mais antiga (`order by created_at limit 1`).
--   Esta RPC escreve nessa mesma linha, para não criar uma segunda fonte de
--   verdade.
--
-- NOTA SOBRE O EFEITO
--   Baixar o limite abaixo do número de colaboradores activos actuais não é
--   bloqueado aqui — não apaga nem desactiva ninguém. Só o acesso de novos
--   colaboradores fica condicionado à autorização do Cesar (regra de produto
--   já fechada: exceder o limite não impede o cadastro, impede o acesso).
-- ============================================================================

begin;

create or replace function public.punho_definir_limite(
  p_empresa_id uuid,
  p_novo_limite int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_subscricao_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global define o limite do Punho.'
      using errcode = 'P0001';
  end if;
  if p_novo_limite < 1 then
    raise exception 'O limite tem de ser pelo menos 1.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.punho_empresas where id = p_empresa_id) then
    raise exception 'Empresa indicada não existe.' using errcode = 'P0001';
  end if;

  update public.punho_subscricoes s
     set limite_colaboradores_ativos = p_novo_limite,
         updated_at = now()
   where s.id = (
     select id from public.punho_subscricoes
      where empresa_id = p_empresa_id
      order by created_at
      limit 1
   )
  returning s.id into v_subscricao_id;

  if v_subscricao_id is null then
    raise exception 'Empresa sem subscrição — não há linha para actualizar.'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'empresa_id', p_empresa_id,
    'limite_novo', p_novo_limite,
    'subscricao_id', v_subscricao_id
  );
end;
$$;
revoke all on function public.punho_definir_limite(uuid, int) from public;
revoke all on function public.punho_definir_limite(uuid, int) from anon;
grant execute on function public.punho_definir_limite(uuid, int)
  to authenticated;

commit;
