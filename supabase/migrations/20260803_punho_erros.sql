-- Onde os erros de produção vão dar.
--
-- Até aqui a app era cega: todos os `catch` acabavam em `debugPrint`, que **não
-- existe numa build release**. Um empresário com um erro ao sábado só chegava
-- ao conhecimento de alguém se telefonasse — e não telefona: encolhe os ombros
-- e volta ao caderno.
--
-- Escrita-apenas do lado do cliente: a app insere e nunca lê. Quem lê é o
-- Control, com `service_role`.
create table if not exists public.punho_erros (
  id uuid primary key default gen_random_uuid(),
  machine_id text not null,
  app text not null default 'punho',
  versao text,
  -- `on delete set null` e não `cascade`: apagar uma empresa não pode apagar o
  -- rasto dos erros que ela viu — é justamente o histórico que explica porquê.
  empresa_id uuid references public.punho_empresas(id) on delete set null,
  utilizador uuid references auth.users(id) on delete set null,
  -- 'flutter' (erro de widget), 'zona' (excepção não apanhada), 'plataforma'
  -- (erro do motor), 'manual' (reportado por código nosso).
  tipo text not null,
  mensagem text not null,
  pilha text,
  -- Modelo do aparelho, versão do Android, ecrã onde aconteceu.
  contexto jsonb not null default '{}'::jsonb,
  -- Quando aconteceu no telemóvel (pode ser muito antes de chegar cá: um erro
  -- que mata a app é gravado localmente e só sobe no arranque seguinte).
  acontecido_em timestamptz not null,
  recebido_em timestamptz not null default now()
);

create index if not exists punho_erros_por_maquina
  on public.punho_erros (machine_id, acontecido_em desc);
create index if not exists punho_erros_por_empresa
  on public.punho_erros (empresa_id, acontecido_em desc);

alter table public.punho_erros enable row level security;

-- Insert aberto a `anon` de propósito: os erros mais valiosos são os do
-- arranque e do login, que acontecem antes de haver sessão. Um erro que só se
-- consegue reportar depois de entrar na app é um erro que nunca se vê.
drop policy if exists "qualquer terminal reporta erro" on public.punho_erros;
create policy "qualquer terminal reporta erro" on public.punho_erros
  for insert to anon, authenticated
  with check (true);

-- Sem policy de select: o cliente escreve e não lê. Quem investiga usa o
-- Control, que passa por `service_role` e ignora RLS.

-- Tecto por aparelho, mesmo princípio da tabela `pings`: um telemóvel em ciclo
-- de erro não pode encher a base. Fica o histórico recente, que é o que serve
-- para diagnosticar.
create or replace function public.punho_limitar_erros()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.punho_erros
  where machine_id = new.machine_id
    and id not in (
      select id from public.punho_erros
      where machine_id = new.machine_id
      order by acontecido_em desc
      limit 200
    );
  return null;
end;
$$;

drop trigger if exists punho_erros_tecto on public.punho_erros;
create trigger punho_erros_tecto
  after insert on public.punho_erros
  for each row execute function public.punho_limitar_erros();
