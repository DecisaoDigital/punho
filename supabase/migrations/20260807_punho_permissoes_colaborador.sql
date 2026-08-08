-- O que o colaborador pode fazer.
--
-- Até aqui, nada o limitava. As duas políticas de `punho_operacoes` pediam
-- apenas "ser membro activo da empresa" — e é por `punho_operacoes` que passa
-- **tudo** o que a app grava. Na prática, um colaborador podia arquivar
-- clientes, e lia despesas e recebimentos da empresa inteira. O canal do
-- instantâneo (`punho_estado_operacional`) diz na primeira linha que "um
-- colaborador não pode descarregar finanças" — e dizia-o enquanto o outro
-- canal lhas entregava.
--
-- A app não ajuda: nunca lê o perfil de ninguém. Mostra os mesmos botões a
-- toda a gente. Portanto a barreira tem de estar aqui, no servidor, como no
-- portal do contabilista — validar no cliente é cortesia, não segurança.
--
-- O que o colaborador faz, dito pelo Cesar: **adiciona clientes** (não os
-- apaga), **recebe pedidos de aluguer e faz a reserva**, **entrega e recolhe
-- máquinas**, **aceita pagamentos**, e **vê a disponibilidade de todas as
-- máquinas**.

-- O perfil de quem está a escrever, na empresa daquela linha.
--
-- `security definer` porque isto corre dentro de políticas: sem ele, ler
-- `punho_membros` ficaria sujeito às políticas de `punho_membros`, e isso
-- fecha-se em círculo.
create or replace function public.punho_perfil_na_empresa(p_empresa uuid)
returns text
language sql
security definer
stable
set search_path = public
as $$
  select m.perfil
  from public.punho_membros m
  where m.empresa_id = p_empresa
    and m.user_id = auth.uid()
    and m.ativo
  limit 1
$$;

-- Se aquela operação, daquela entidade, é coisa de colaborador.
--
-- **Falha fechada de propósito.** Uma entidade que esta função não conheça —
-- porque uma versão futura da app a inventou — é recusada. O contrário
-- (deixar passar o que não se conhece) faz com que cada entidade nova nasça
-- sem permissões e ninguém dê por isso.
create or replace function public.punho_colaborador_pode_escrever(
  p_entidade text,
  p_payload jsonb
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case p_entidade
    -- Cliente: cria e corrige. Arquivar é do gestor — e arquivar viaja como o
    -- estado final do cliente com `archived: true`, não como um apagar.
    when 'customer' then coalesce((p_payload->>'archived')::boolean, false) is not true

    -- O pedido de aluguer que lhe chega e a reserva que faz a partir dele.
    when 'lead' then true
    when 'booking' then true

    -- O pagamento que aceita.
    when 'receipt' then true

    -- Entregar e recolher mexe no estado da máquina, e é ele que o faz. Tirar
    -- a máquina de circulação não.
    --
    -- Nota: isto deixa passar qualquer campo da máquina, não só o estado. O
    -- registo de operações não guarda o "antes", portanto uma política não
    -- consegue ver o que mudou — para apertar mais era preciso comparar com a
    -- última operação daquela máquina, num gatilho.
    when 'machine' then coalesce((p_payload->>'archived')::boolean, false) is not true

    -- Cadastro e dinheiro que sai: do gestor.
    when 'expense' then false
    when 'vehicle' then false
    when 'collaborator' then false

    else false
  end
$$;

revoke all on function public.punho_perfil_na_empresa(uuid) from public;
grant execute on function public.punho_perfil_na_empresa(uuid) to authenticated;
revoke all on function public.punho_colaborador_pode_escrever(text, jsonb) from public;
grant execute on function public.punho_colaborador_pode_escrever(text, jsonb)
  to authenticated;

-- Escrever.
drop policy if exists punho_operacoes_membro_escreve on public.punho_operacoes;
create policy punho_operacoes_membro_escreve on public.punho_operacoes
  for insert to authenticated
  with check (
    case public.punho_perfil_na_empresa(punho_operacoes.empresa_id)
      when 'gestor' then true
      when 'colaborador' then public.punho_colaborador_pode_escrever(
        punho_operacoes.entidade,
        punho_operacoes.payload
      )
      else false  -- não é membro activo desta empresa
    end
  );

-- Ler.
--
-- O colaborador vê as máquinas todas — é o que lhe permite dizer a um cliente
-- se há giratória livre na quinta-feira. Vê os clientes, as reservas e os
-- recebimentos, que são o trabalho dele. Não vê as despesas: é a única coisa
-- que aqui viaja e que é dinheiro a sair da empresa.
drop policy if exists punho_operacoes_membro_le on public.punho_operacoes;
create policy punho_operacoes_membro_le on public.punho_operacoes
  for select to authenticated
  using (
    case public.punho_perfil_na_empresa(punho_operacoes.empresa_id)
      when 'gestor' then true
      when 'colaborador' then punho_operacoes.entidade <> 'expense'
      else false
    end
  );
