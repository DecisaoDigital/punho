-- O operador só vê as leads que lhe foram atribuídas (ou que ele próprio criou).
--
-- Decisão do César (9/10/2026): «o colaborador não vê todas as leads, vê todos
-- os clientes, todas as máquinas disponíveis e as leads fechadas e abertas
-- feitas por si». O gestor continua a ver tudo.
--
-- «Atribuída» = `collaboratorResponsibleId` do payload é a ficha de pessoal do
-- operador (`punho_membros.colaborador_id`) — ou, por compatibilidade com o que
-- as apps antigas escreveram, o uid da conta. As vistas `punho_leads` etc.
-- herdam esta política (lêem `punho_operacoes`).
--
-- Aditiva e reversível: só muda a expressão da política de leitura e cria uma
-- função de apoio.

create or replace function public.punho_minha_ficha(p_empresa uuid)
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select m.colaborador_id::text
    from punho_membros m
   where m.empresa_id = p_empresa
     and m.user_id = auth.uid()
     and m.ativo
   limit 1
$fn$;

revoke all on function public.punho_minha_ficha(uuid) from public, anon;
grant execute on function public.punho_minha_ficha(uuid) to authenticated;

alter policy punho_operacoes_membro_le on public.punho_operacoes
  using (
    case public.punho_perfil_na_empresa(empresa_id)
      when 'gestor' then true
      when 'colaborador' then
        case
          when entidade = 'expense' then por_utilizador = auth.uid()
          when entidade in ('vehicle', 'collaborator') then false
          when entidade = 'lead' then
            por_utilizador = auth.uid()
            or (payload ->> 'collaboratorResponsibleId')
               in (auth.uid()::text, public.punho_minha_ficha(empresa_id))
          else true
        end
      else false
    end
  );
