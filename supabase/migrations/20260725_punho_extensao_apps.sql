-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260725021617). Estava em
-- produção sem ficheiro no repo.

-- Extensão do catálogo versoes_apps para o Punho: adiciona 'punho' ao enum de app,
-- coluna plataforma (all|windows|android|ios), e unique key composto.

alter table public.versoes_apps
  drop constraint if exists versoes_apps_app_check;
alter table public.versoes_apps
  add constraint versoes_apps_app_check
  check (app in ('pos', 'control', 'punho'));

alter table public.versoes_apps
  add column if not exists plataforma text not null default 'all';
alter table public.versoes_apps
  drop constraint if exists versoes_apps_plataforma_check;
alter table public.versoes_apps
  add constraint versoes_apps_plataforma_check
  check (plataforma in ('all', 'windows', 'android', 'ios'));

alter table public.versoes_apps
  drop constraint if exists versoes_apps_app_build_number_key;
create unique index if not exists versoes_apps_app_plataforma_build_unique
  on public.versoes_apps (app, plataforma, build_number);

comment on table public.versoes_apps is
  'Catálogo de versões do POS, WashInvoice Control e Punho. A Edge Function versao-mais-recente compara build_number, filtra por app+plataforma.';
