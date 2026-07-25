-- Estado operacional sincronizado para o gestor. É deliberadamente separado
-- dos dados de colaborador: um colaborador não pode descarregar finanças,
-- custos ou informação global da empresa através desta tabela.
create table if not exists public.punho_estado_operacional (
  empresa_id uuid primary key references public.punho_empresas(id) on delete cascade,
  revision integer not null default 1,
  payload jsonb not null default '{}'::jsonb,
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.punho_estado_operacional enable row level security;

drop policy if exists "gestor le estado operacional" on public.punho_estado_operacional;
create policy "gestor le estado operacional" on public.punho_estado_operacional
  for select to authenticated
  using (
    empresa_id = public.punho_empresa_atual()
    and public.punho_e_gestor()
  );

drop policy if exists "gestor cria estado operacional" on public.punho_estado_operacional;
create policy "gestor cria estado operacional" on public.punho_estado_operacional
  for insert to authenticated
  with check (
    empresa_id = public.punho_empresa_atual()
    and updated_by = auth.uid()
    and public.punho_e_gestor()
  );

drop policy if exists "gestor atualiza estado operacional" on public.punho_estado_operacional;
create policy "gestor atualiza estado operacional" on public.punho_estado_operacional
  for update to authenticated
  using (
    empresa_id = public.punho_empresa_atual()
    and public.punho_e_gestor()
  )
  with check (
    empresa_id = public.punho_empresa_atual()
    and updated_by = auth.uid()
    and public.punho_e_gestor()
  );

-- A revisão permite ao cliente detetar uma alteração remota que ainda não
-- recebeu. O cliente nunca deve sobrescrever esse caso silenciosamente.
create or replace function public.punho_guardar_estado_operacional(
  novo_payload jsonb,
  revisao_esperada integer default null
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  empresa uuid := public.punho_empresa_atual();
  atual integer;
begin
  if empresa is null or not public.punho_e_gestor() then
    raise exception 'Apenas o gestor ativo pode sincronizar o estado operacional.';
  end if;

  select revision into atual
  from public.punho_estado_operacional
  where empresa_id = empresa
  for update;

  if atual is null then
    if revisao_esperada is not null then
      raise exception 'O estado remoto ainda não existe.' using errcode = 'P0001';
    end if;
    insert into public.punho_estado_operacional
      (empresa_id, revision, payload, updated_by)
    values (empresa, 1, novo_payload, auth.uid());
    return 1;
  end if;

  if revisao_esperada is distinct from atual then
    raise exception 'Existe uma alteração remota por rever.' using errcode = 'P0001';
  end if;

  update public.punho_estado_operacional
  set payload = novo_payload,
      revision = atual + 1,
      updated_by = auth.uid(),
      updated_at = now()
  where empresa_id = empresa;
  return atual + 1;
end;
$$;

revoke all on function public.punho_guardar_estado_operacional(jsonb, integer) from public;
grant execute on function public.punho_guardar_estado_operacional(jsonb, integer)
  to authenticated;
