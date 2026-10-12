-- O que o assistente de atendimento (Carlitos e o funil) precisa de saber de CADA empresa.
-- Vive na base e não no código: uma empresa nova é uma linha, não um deploy.
--
-- Só a função `receber-lead` (service role) lê isto para validar pedidos. Os membros
-- activos da empresa podem ver a sua própria linha; quem a edita é decidido quando
-- houver ecrã para isso (hoje edita-se por SQL).

create table if not exists public.punho_atendimento_config (
  empresa_id uuid primary key references public.punho_empresas(id) on delete cascade,
  -- Como o assistente fala da empresa («Sou o Carlitos, o assistente de IA da <nome>»).
  nome_publico text not null,
  fuso text not null default 'Europe/Lisbon',
  -- O que a empresa oferece: serviço, aluguer de máquinas, venda de máquinas.
  tipos text[] not null default '{servico,aluguer,venda}'
    check (tipos <@ array['servico','aluguer','venda']::text[]),
  -- As categorias entre que a pessoa escolhe (texto igual ao da categoria das máquinas).
  categorias text[] not null default '{}',
  -- Janelas em horas decimais, p.ex. [{"de":9,"ate":13},{"de":15,"ate":18}].
  -- Nulo = a empresa não tem horário validado: só se exige data futura.
  horario_servico jsonb,
  horario_aluguer jsonb,
  atualizado_em timestamptz not null default now()
);

alter table public.punho_atendimento_config enable row level security;

drop policy if exists punho_atendimento_membro_le on public.punho_atendimento_config;
create policy punho_atendimento_membro_le
  on public.punho_atendimento_config for select
  using (exists (
    select 1 from public.punho_membros m
    where m.empresa_id = punho_atendimento_config.empresa_id
      and m.user_id = auth.uid() and m.ativo
  ));

comment on table public.punho_atendimento_config is
  'Configuração de atendimento por empresa (horários, categorias, o que oferece). Lida por receber-lead.';

-- O nome do assistente é da empresa: o «Carlitos» é só o nome que damos por simplicidade.
alter table public.punho_atendimento_config
  add column if not exists nome_assistente text not null default 'Assistente';
