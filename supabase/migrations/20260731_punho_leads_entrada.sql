-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260731200058). Estava em
-- produção sem ficheiro no repo.

-- Caixa de entrada das leads que chegam de fora da app (landing page, WhatsApp,
-- agenda). Só de acrescentar: dois canais a escrever ao mesmo tempo sobrevivem
-- os dois, ao contrário do estado operacional completo, que deteta conflitos.
--
-- A app lê o que ainda não processou, cria as leads locais e marca
-- `processada_em`. Nada aqui é apagado: rejeitar é classificar. Sem o
-- `payload_bruto` guardado não se distingue "a campanha não trouxe nada" de "a
-- campanha trouxe lixo que apagámos".

create table if not exists public.punho_leads_entrada (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.punho_empresas(id) on delete cascade,

  origem text not null check (origem in (
    'landing_page', 'whatsapp', 'telefone', 'agenda', 'manual', 'outro'
  )),

  nome text,
  -- Normalizado para E.164 na Edge Function. É a chave de deduplicação: sem
  -- isto o mesmo cliente conta várias vezes e a conversão do painel divide-se
  -- pelo número de canais.
  telefone_e164 text,
  telefone_original text,
  email text,
  mensagem text,

  -- 'aceite'    -> vira lead sem ninguém aprovar (o caso normal)
  -- 'retida'    -> vai para triagem: um toque aceita, um toque descarta
  -- 'descartada'-> não aparece a ninguém, mas fica gravada
  classificacao text not null default 'retida'
    check (classificacao in ('aceite', 'retida', 'descartada')),
  motivo text,

  payload_bruto jsonb not null default '{}'::jsonb,
  ip_origem inet,

  recebida_em timestamptz not null default now(),
  processada_em timestamptz,
  -- Quando a app converte isto numa lead local, guarda aqui o id que lhe deu.
  lead_local_id text
);

-- A consulta que a app faz a cada arranque: o que falta processar, por empresa.
create index if not exists punho_leads_entrada_por_processar
  on public.punho_leads_entrada (empresa_id, recebida_em)
  where processada_em is null;

-- Deduplicação e limite de ritmo por número.
create index if not exists punho_leads_entrada_telefone
  on public.punho_leads_entrada (empresa_id, telefone_e164, recebida_em desc);

alter table public.punho_leads_entrada enable row level security;

-- Só quem é membro activo da empresa vê e mexe. A escrita pública não passa por
-- aqui: entra pela Edge Function com service role, que valida antes de gravar.
drop policy if exists punho_leads_entrada_membro_le on public.punho_leads_entrada;
create policy punho_leads_entrada_membro_le
  on public.punho_leads_entrada for select
  using (exists (
    select 1 from public.punho_membros m
    where m.empresa_id = punho_leads_entrada.empresa_id
      and m.user_id = auth.uid()
      and m.ativo
  ));

-- O gestor marca como processada, aceita ou descarta. Não pode inventar linhas
-- nem apagar histórico — daí não haver policy de insert nem de delete.
drop policy if exists punho_leads_entrada_membro_actualiza on public.punho_leads_entrada;
create policy punho_leads_entrada_membro_actualiza
  on public.punho_leads_entrada for update
  using (exists (
    select 1 from public.punho_membros m
    where m.empresa_id = punho_leads_entrada.empresa_id
      and m.user_id = auth.uid()
      and m.ativo
  ));

comment on table public.punho_leads_entrada is
  'Caixa de entrada append-only das leads externas. Ver docs/ENTRADA_DE_LEADS.md.';
