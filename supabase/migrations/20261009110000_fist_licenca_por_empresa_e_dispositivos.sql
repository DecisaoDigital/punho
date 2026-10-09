-- Fist: a licença é da EMPRESA (quem paga); o funcionário é um lugar em punho_membros;
-- cada funcionário tem no máximo 2 aparelhos e uma só sessão ativa.
-- Aditivo: nada existente muda de forma. machine_id continua NOT NULL; as linhas por
-- empresa levam o valor sintético 'empresa:<uuid>' para não partir o Control.
-- Aplicada em produção a 2026-10-09. Desenho: docs/LICENCA_POR_FUNCIONARIO.md

alter table public.licencas
  add column if not exists empresa_id uuid references public.punho_empresas(id) on delete set null;

create unique index if not exists licencas_empresa_app_uniq
  on public.licencas (empresa_id, app) where empresa_id is not null;

create table if not exists public.fist_dispositivos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  machine_id text not null,
  nome text,
  criado_em timestamptz not null default now(),
  visto_em timestamptz not null default now(),
  unique (user_id, machine_id)
);

create table if not exists public.fist_sessoes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  machine_id text not null,
  sessao_id uuid not null default gen_random_uuid(),
  aberta_em timestamptz not null default now(),
  visto_em timestamptz not null default now()
);

alter table public.fist_dispositivos enable row level security;
alter table public.fist_sessoes enable row level security;

-- Só o service_role escreve (Edge Functions). O admin do Control pode ler.
create policy fist_dispositivos_admin_read on public.fist_dispositivos
  for select to authenticated using (public.is_admin());
create policy fist_sessoes_admin_read on public.fist_sessoes
  for select to authenticated using (public.is_admin());
create policy fist_dispositivos_service on public.fist_dispositivos
  for all to service_role using (true) with check (true);
create policy fist_sessoes_service on public.fist_sessoes
  for all to service_role using (true) with check (true);
