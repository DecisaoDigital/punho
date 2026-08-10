-- Conflitos pendentes de decisão humana — hoje só o caso de duas reservas
-- confirmadas na mesma máquina, chegadas de dois aparelhos que estiveram
-- offline ao mesmo tempo (dois colaboradores da mesma empresa, cada um a
-- reservar a mesma máquina para um cliente diferente sem saber do outro).
--
-- A detecção corre em qualquer aparelho (inclui o do Gestor, que recebe as
-- duas reservas pelo canal já existente `punho_operacoes`, aberto a todos os
-- membros), mas só o Gestor decide — "o árbitro é quem tem app Gestor".
-- Por isso só o Gestor grava aqui (insere e resolve), tal como só o Gestor
-- grava em `punho_estado_operacional`. Um colaborador não precisa de
-- escrever nesta tabela: o aparelho do Gestor detecta a mesma disputa de
-- forma independente, assim que sincronizar as duas reservas.
--
-- Fase 0 (esta migração): só a tabela e o acesso. A detecção
-- (`aplicarOperacaoRemota`, em `operation_repository.dart`) e o banner/ecrã
-- de decisão ainda não existem — esta tabela fica inerte até essa fase.
create table if not exists public.punho_conflitos_pendentes (
  -- Determinístico (`'reservaMaquina:$menor:$maior'`), nunca gen_random_uuid():
  -- dois aparelhos que detectam a mesma disputa, cada um a seu tempo, têm de
  -- chegar à mesma linha — ver `ConflitoPendente.reservaMaquina` no cliente.
  id text primary key,
  empresa_id uuid not null references public.punho_empresas(id) on delete cascade,
  tipo text not null,
  entidade_a_id text not null,
  entidade_b_id text not null,
  machine_ids text[] not null default '{}',
  envolvidos uuid[] not null default '{}',
  estado text not null default 'pendente' check (estado in ('pendente', 'resolvido')),
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz,
  resolvido_por uuid references auth.users(id),
  fica_com_entidade_id text
);

alter table public.punho_conflitos_pendentes enable row level security;

-- Leitura aberta a qualquer membro activo: os colaboradores envolvidos
-- precisam de ver o conflito para o banner informativo (fase futura). É a
-- app, não a RLS, que filtra o que mostrar a cada papel — mesmo padrão de
-- `punho_operacoes`.
drop policy if exists "membro le conflitos pendentes" on public.punho_conflitos_pendentes;
create policy "membro le conflitos pendentes" on public.punho_conflitos_pendentes
  for select to authenticated
  using (empresa_id = public.punho_empresa_atual());

drop policy if exists "gestor cria conflito pendente" on public.punho_conflitos_pendentes;
create policy "gestor cria conflito pendente" on public.punho_conflitos_pendentes
  for insert to authenticated
  with check (
    empresa_id = public.punho_empresa_atual()
    and public.punho_e_gestor()
  );

drop policy if exists "gestor resolve conflito pendente" on public.punho_conflitos_pendentes;
create policy "gestor resolve conflito pendente" on public.punho_conflitos_pendentes
  for update to authenticated
  using (
    empresa_id = public.punho_empresa_atual()
    and public.punho_e_gestor()
  )
  with check (
    empresa_id = public.punho_empresa_atual()
    and public.punho_e_gestor()
  );
