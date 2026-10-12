-- A administrativa: a pessoa do escritório que valida as leads quentes e faz as marcações.
--
-- Tem os MESMOS poderes de um gerente (perfil continua 'gestor', logo todas as policies e
-- funções existentes tratam-na como gestor). O que muda é só a VISTA: o gerente escolhe
-- que ecrãs da barra lateral ela não vê (p.ex. o Painel, com a faturação).
-- Aditiva: duas colunas novas e três funções novas; apps antigas não dão por nada.
--
-- Atenção: esconder um ecrã é decisão de apresentação, não é segurança. Ela tem poderes
-- de gestor no servidor, por vontade do dono, e os dados chegam ao aparelho dela.

alter table public.punho_membros
  add column if not exists funcao text,
  add column if not exists ecras_ocultos text[] not null default '{}';

alter table public.punho_membros
  drop constraint if exists punho_membros_funcao_conhecida;
alter table public.punho_membros
  add constraint punho_membros_funcao_conhecida
  check (funcao is null or funcao in ('gerente', 'administrativa'));

-- Os ecrãs da barra lateral que se podem esconder (nomes de AppDestination).
create or replace function public.punho_ecras_validos(p text[])
returns boolean language sql immutable as $$
  select p <@ array['management','semana','bookings','clients','machines','employees','empresa','tasks','kpis']::text[]
$$;

-- Quem sou eu na equipa: função (nula = gerente) e ecrãs escondidos.
create or replace function public.punho_minha_funcao()
returns table (funcao text, ecras_ocultos text[])
language sql stable security definer set search_path = public as $$
  select coalesce(m.funcao, 'gerente'), m.ecras_ocultos
    from punho_membros m
   where m.user_id = auth.uid() and m.ativo
   limit 1
$$;

-- Só um gerente (gestor que não é administrativa) vê e muda a equipa.
create or replace function public.punho_e_gerente()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from punho_membros m
     where m.user_id = auth.uid() and m.ativo and m.perfil = 'gestor'
       and coalesce(m.funcao, 'gerente') = 'gerente'
  )
$$;

create or replace function public.punho_listar_equipa()
returns table (user_id uuid, email text, funcao text, ecras_ocultos text[], eu boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_empresa uuid;
begin
  if not public.punho_e_gerente() then
    raise exception 'Só um gerente vê a equipa.' using errcode = 'P0001';
  end if;
  v_empresa := public.punho_empresa_atual();
  return query
    select m.user_id, u.email::text, coalesce(m.funcao, 'gerente'), m.ecras_ocultos, (m.user_id = auth.uid())
      from punho_membros m
      join auth.users u on u.id = m.user_id
     where m.empresa_id = v_empresa and m.ativo and m.perfil = 'gestor'
     order by (m.user_id = auth.uid()) desc, u.email;
end $$;

create or replace function public.punho_definir_funcao(
  p_user_id uuid, p_funcao text, p_ecras_ocultos text[] default '{}'
) returns void
language plpgsql security definer set search_path = public as $$
declare v_empresa uuid;
begin
  if not public.punho_e_gerente() then
    raise exception 'Só um gerente muda a função de alguém.' using errcode = 'P0001';
  end if;
  if p_funcao not in ('gerente', 'administrativa') then
    raise exception 'Função inválida.' using errcode = 'P0001';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Não podes mudar a tua própria função.' using errcode = 'P0001';
  end if;
  if not public.punho_ecras_validos(coalesce(p_ecras_ocultos, '{}')) then
    raise exception 'Ecrã desconhecido.' using errcode = 'P0001';
  end if;
  v_empresa := public.punho_empresa_atual();
  update punho_membros
     set funcao = p_funcao,
         -- um gerente vê tudo: a lista de ecrãs escondidos só vale para a administrativa
         ecras_ocultos = case when p_funcao = 'administrativa' then coalesce(p_ecras_ocultos, '{}') else '{}' end,
         updated_at = now()
   where user_id = p_user_id and empresa_id = v_empresa and ativo and perfil = 'gestor';
  if not found then
    raise exception 'Essa pessoa não é gestora desta empresa.' using errcode = 'P0001';
  end if;
end $$;

revoke all on function public.punho_minha_funcao(), public.punho_e_gerente(), public.punho_listar_equipa(),
  public.punho_definir_funcao(uuid, text, text[]) from public, anon;
grant execute on function public.punho_minha_funcao(), public.punho_listar_equipa(),
  public.punho_definir_funcao(uuid, text, text[]) to authenticated;
