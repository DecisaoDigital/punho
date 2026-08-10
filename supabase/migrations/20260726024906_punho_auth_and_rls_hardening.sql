-- Autenticação, adesão à empresa e integridade multiempresa.
-- Esta migration é cumulativa: aplica-se depois das migrations iniciais.

-- A primeira versão do Punho prevê uma conta de utilizador por empresa.
-- Se no futuro existir uma conta de contabilista/consultor multiempresa,
-- essa funcionalidade deverá ter um modelo e permissões próprios.
create unique index if not exists punho_membros_user_empresa_unico
  on public.punho_membros (user_id);

-- Uma máquina associada a uma reserva tem de existir no inventário Punho.
alter table public.punho_reserva_maquinas
  drop constraint if exists punho_reserva_maquinas_maquina_id_fkey;
alter table public.punho_reserva_maquinas
  add constraint punho_reserva_maquinas_maquina_id_fkey
  foreign key (maquina_id) references public.punho_maquinas(id) on delete restrict;

-- Permite à pessoa autenticada ler a própria adesão e a empresa a que pertence.
drop policy if exists "membro ve a propria adesao" on public.punho_membros;
create policy "membro ve a propria adesao" on public.punho_membros
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "membro ve a propria empresa" on public.punho_empresas;
create policy "membro ve a propria empresa" on public.punho_empresas
  for select to authenticated
  using (id = public.punho_empresa_atual());

drop policy if exists "gestor atualiza a propria empresa" on public.punho_empresas;
create policy "gestor atualiza a propria empresa" on public.punho_empresas
  for update to authenticated
  using (id = public.punho_empresa_atual() and public.punho_e_gestor())
  with check (id = public.punho_empresa_atual() and public.punho_e_gestor());

-- A relação reserva/máquina também tem de respeitar a empresa da sessão.
drop policy if exists "membros gerem maquinas nas reservas da empresa" on public.punho_reserva_maquinas;
create policy "membros gerem maquinas nas reservas da empresa" on public.punho_reserva_maquinas
  for all to authenticated
  using (
    exists (
      select 1 from public.punho_reservas reserva
      where reserva.id = reserva_id
        and reserva.empresa_id = public.punho_empresa_atual()
    )
  )
  with check (
    exists (
      select 1 from public.punho_reservas reserva
      join public.punho_maquinas maquina on maquina.id = maquina_id
      where reserva.id = reserva_id
        and reserva.empresa_id = public.punho_empresa_atual()
        and maquina.empresa_id = reserva.empresa_id
    )
  );

-- Impede referências cruzadas entre empresas, mesmo que uma política futura
-- seja alterada por engano.
create or replace function public.punho_validar_referencias_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cliente_empresa uuid;
  membro_empresa uuid;
begin
  select empresa_id into cliente_empresa from public.punho_clientes where id = new.cliente_id;
  if cliente_empresa is null or cliente_empresa <> new.empresa_id then
    raise exception 'O cliente tem de pertencer à mesma empresa da reserva.';
  end if;

  if new.colaborador_responsavel_id is not null then
    select empresa_id into membro_empresa from public.punho_membros where id = new.colaborador_responsavel_id;
    if membro_empresa is null or membro_empresa <> new.empresa_id then
      raise exception 'O colaborador tem de pertencer à mesma empresa da reserva.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists punho_reserva_referencias_consistentes on public.punho_reservas;
create trigger punho_reserva_referencias_consistentes
  before insert or update of empresa_id, cliente_id, colaborador_responsavel_id
  on public.punho_reservas
  for each row execute function public.punho_validar_referencias_reserva();

create or replace function public.punho_validar_maquina_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  empresa_reserva uuid;
  empresa_maquina uuid;
begin
  select empresa_id into empresa_reserva from public.punho_reservas where id = new.reserva_id;
  select empresa_id into empresa_maquina from public.punho_maquinas where id = new.maquina_id;
  if empresa_reserva is null or empresa_maquina is null or empresa_reserva <> empresa_maquina then
    raise exception 'A máquina tem de pertencer à mesma empresa da reserva.';
  end if;
  return new;
end;
$$;

drop trigger if exists punho_reserva_maquina_empresa_consistente on public.punho_reserva_maquinas;
create trigger punho_reserva_maquina_empresa_consistente
  before insert or update of reserva_id, maquina_id
  on public.punho_reserva_maquinas
  for each row execute function public.punho_validar_maquina_reserva();

-- A verificação de sobreposição tem de correr também quando a reserva muda
-- para confirmada/em_aluguer, e não apenas quando a máquina é associada.
create or replace function public.punho_validar_conflito_ao_ativar_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado in ('confirmada', 'em_aluguer') and exists (
    select 1
    from public.punho_reserva_maquinas atual
    join public.punho_reservas outra on outra.id <> new.id
      and outra.empresa_id = new.empresa_id
      and outra.estado in ('confirmada', 'em_aluguer')
      and outra.inicio < new.fim
      and outra.fim > new.inicio
    join public.punho_reserva_maquinas outra_maquina
      on outra_maquina.reserva_id = outra.id
      and outra_maquina.maquina_id = atual.maquina_id
    where atual.reserva_id = new.id
  ) then
    raise exception 'Existe uma reserva ativa sobreposta para pelo menos uma máquina.';
  end if;
  return new;
end;
$$;

drop trigger if exists punho_reserva_conflito_ao_ativar on public.punho_reservas;
create trigger punho_reserva_conflito_ao_ativar
  before insert or update of estado, inicio, fim
  on public.punho_reservas
  for each row execute function public.punho_validar_conflito_ao_ativar_reserva();

-- Criação atómica da empresa inicial. Uma conta autenticada não pode criar
-- uma segunda empresa através desta RPC.
create or replace function public.punho_criar_empresa_inicial(nome_empresa text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  empresa public.punho_empresas;
begin
  if auth.uid() is null then
    raise exception 'Sessão autenticada obrigatória.';
  end if;
  if nullif(btrim(nome_empresa), '') is null then
    raise exception 'O nome da empresa é obrigatório.';
  end if;
  if exists (select 1 from public.punho_membros where user_id = auth.uid()) then
    raise exception 'Esta conta já pertence a uma empresa.';
  end if;

  insert into public.punho_empresas (nome)
  values (btrim(nome_empresa))
  returning * into empresa;

  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (empresa.id, auth.uid(), 'gestor', true)
  ;

  insert into public.punho_subscricoes (empresa_id, dados, limite_colaboradores_ativos)
  values (empresa.id, jsonb_build_object('estado', 'desenvolvimento'), 3);

  insert into public.punho_instalacoes (empresa_id, dados)
  values (empresa.id, jsonb_build_object('origem', 'onboarding-inicial'));

  return empresa.id;
end;
$$;

revoke all on function public.punho_criar_empresa_inicial(text) from public;
grant execute on function public.punho_criar_empresa_inicial(text) to authenticated;
