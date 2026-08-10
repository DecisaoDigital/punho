-- Pedidos de acesso ao DesignDigital Punho: aprovação manual no Control.
create table if not exists public.punho_pedidos_acesso (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  nome text, email text not null, empresa_indicada text not null,
  empresa_id uuid references public.punho_empresas(id),
  perfil text not null check (perfil in ('gestor','colaborador')),
  origem text not null check (origem in ('livre','convite')),
  estado text not null default 'pendente' check (estado in ('pendente','aprovado','recusado','revogado')),
  criado_em timestamptz not null default now(), decidido_em timestamptz
);
alter table public.punho_pedidos_acesso enable row level security;
create policy "utilizador le o proprio pedido" on public.punho_pedidos_acesso
  for select to authenticated using (user_id = auth.uid());

create or replace function public.punho_meu_estado_acesso()
returns text language sql stable security definer set search_path=public as $$
  select coalesce((select estado from public.punho_pedidos_acesso where user_id = auth.uid()), 'pendente');
$$;
revoke all on function public.punho_meu_estado_acesso() from public;
grant execute on function public.punho_meu_estado_acesso() to authenticated;

create or replace function public.punho_criar_pedido_ao_registar()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.raw_user_meta_data->>'app', '') <> 'punho' then return new; end if;
  insert into public.punho_pedidos_acesso(user_id,nome,email,empresa_indicada,perfil,origem)
  values (new.id, new.raw_user_meta_data->>'nome', new.email,
    coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa por confirmar'),
    case when new.raw_user_meta_data->>'perfil' = 'gestor' then 'gestor' else 'colaborador' end,
    'livre');
  return new;
end;
$$;
drop trigger if exists punho_criar_pedido_ao_registar on auth.users;
create trigger punho_criar_pedido_ao_registar after insert on auth.users
  for each row execute function public.punho_criar_pedido_ao_registar();
