-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260731224151). Estava em
-- produção sem ficheiro no repo.

-- Registo de operações — a base da sincronização entre dispositivos.
--
-- O que existia era um instantâneo do estado operacional COMPLETO, com uma
-- revisão. Dois dispositivos a editar davam conflito e um deles perdia o
-- trabalho — que é exactamente o caso de uso (gestor no escritório,
-- colaborador no terreno).
--
-- Isto é só de acrescentar. Cada alteração local vira uma linha; cada
-- dispositivo puxa as que ainda não viu e aplica-as por ordem de `seq`. Duas
-- linhas escritas ao mesmo tempo sobrevivem as duas: não há revisão para
-- colidir, e a ordem total do `seq` decide quem fica por cima quando é mesmo a
-- mesma entidade.
create table if not exists public.punho_operacoes (
  -- Ordem total atribuída pelo servidor. É o cursor: cada dispositivo guarda o
  -- último `seq` que aplicou. Relógios de telemóveis não servem para isto —
  -- andam dessincronizados e dois dispositivos podem gravar "ao mesmo tempo".
  seq bigserial primary key,

  -- Gerado no cliente, para a operação poder esperar em fila sem rede e ser
  -- reenviada sem risco de entrar duas vezes.
  id uuid not null unique,

  empresa_id uuid not null references public.punho_empresas(id) on delete cascade,

  entidade text not null check (entidade in (
    'machine', 'customer', 'lead', 'booking',
    'expense', 'receipt', 'collaborator', 'vehicle'
  )),
  entidade_id text not null,

  -- O objecto completo, no mesmo formato que a app já usa em disco. Guardar o
  -- estado final e não um "diff" é o que permite aplicar operações fora de
  -- ordem sem reconstruir história.
  payload jsonb not null,

  feito_em timestamptz not null default now(),
  por_utilizador uuid,
  -- Para um dispositivo saber ignorar o que foi ele próprio a escrever.
  por_dispositivo text
);

-- A consulta de cada arranque: o que apareceu depois do meu cursor.
create index if not exists punho_operacoes_por_empresa
  on public.punho_operacoes (empresa_id, seq);

alter table public.punho_operacoes enable row level security;

-- Membro activo lê e escreve as da sua empresa. Não há update nem delete: o
-- registo é histórico, e corrigir faz-se acrescentando outra operação.
drop policy if exists punho_operacoes_membro_le on public.punho_operacoes;
create policy punho_operacoes_membro_le
  on public.punho_operacoes for select
  using (exists (
    select 1 from public.punho_membros m
    where m.empresa_id = punho_operacoes.empresa_id
      and m.user_id = auth.uid() and m.ativo
  ));

drop policy if exists punho_operacoes_membro_escreve on public.punho_operacoes;
create policy punho_operacoes_membro_escreve
  on public.punho_operacoes for insert
  with check (exists (
    select 1 from public.punho_membros m
    where m.empresa_id = punho_operacoes.empresa_id
      and m.user_id = auth.uid() and m.ativo
  ));

comment on table public.punho_operacoes is
  'Registo append-only de alteracoes operacionais, para sincronizacao entre dispositivos. Ver docs/SINCRONIZACAO.md.';
