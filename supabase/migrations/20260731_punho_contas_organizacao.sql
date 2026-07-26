-- ============================================================================
-- Punho v0.0.2 — contas por organização com aprovação manual no Control.
--
-- DELTA sobre 20260730_punho_pedidos_acesso.sql, que já criou
-- `punho_pedidos_acesso`, a RPC `punho_meu_estado_acesso()` e o trigger de
-- `auth.users`. Aqui acrescenta-se o que faltava:
--
--   1. `punho_convites` — convites de gestor, uso único, 14 dias.
--   2. Colunas em falta em `punho_pedidos_acesso` (`actualizado_em`,
--      `convite_id`) + índice `(estado, criado_em)` para o Control paginar.
--   3. Trigger de registo reescrito: passa a consumir código de convite e a
--      gravar `origem = 'convite'` com a empresa certa.
--   4. Policies: gestor aprovado vê os pedidos da sua empresa; ninguém
--      autenticado escreve (o Control usa service role). Sem policy DELETE.
--   5. RPCs `punho_criar_convite()`, `punho_validar_convite()` e
--      `punho_meu_acesso()`.
--   6. Fecha `punho_criar_empresa_inicial()` ao role `authenticated` — hoje
--      qualquer conta se auto-promovia a gestora de uma empresa nova, o que
--      contorna por completo a aprovação manual.
--
-- Idempotente: pode correr as vezes que forem precisas.
-- Vocabulário: o repositório usa `perfil` ('gestor' | 'colaborador'). Mantém-se
-- `perfil` e não `cargo` para não haver dois nomes para a mesma coisa.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Convites
-- ---------------------------------------------------------------------------
create table if not exists public.punho_convites (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.punho_empresas(id) on delete cascade,
  email text not null,
  perfil text not null default 'colaborador'
    check (perfil in ('gestor', 'colaborador')),
  codigo text not null unique,
  criado_por uuid not null references auth.users(id),
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default now() + interval '14 days',
  usado boolean not null default false,
  usado_por uuid references auth.users(id),
  usado_em timestamptz
);

-- Um convite por email e empresa enquanto estiver por usar. A expiração não
-- entra no índice (now() não é imutável); é validada no trigger e na RPC.
create unique index if not exists punho_convites_email_ativo
  on public.punho_convites (empresa_id, lower(email))
  where not usado;

create index if not exists punho_convites_empresa
  on public.punho_convites (empresa_id, criado_em desc);

alter table public.punho_convites enable row level security;

-- O gestor vê os convites da própria empresa (para listar e partilhar códigos).
-- Não há policy de insert/update/delete: criar é só pela RPC security definer.
drop policy if exists "gestor le convites da empresa" on public.punho_convites;
create policy "gestor le convites da empresa" on public.punho_convites
  for select to authenticated
  using (empresa_id = public.punho_empresa_atual() and public.punho_e_gestor());

-- ---------------------------------------------------------------------------
-- 2. Delta de `punho_pedidos_acesso`
-- ---------------------------------------------------------------------------
alter table public.punho_pedidos_acesso
  add column if not exists actualizado_em timestamptz not null default now();
alter table public.punho_pedidos_acesso
  add column if not exists convite_id uuid references public.punho_convites(id);

-- O Control lista por estado e ordena por data.
create index if not exists punho_pedidos_acesso_estado_criado
  on public.punho_pedidos_acesso (estado, criado_em);

create or replace function public.punho_tocar_actualizado_em()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_em := now();
  return new;
end;
$$;

drop trigger if exists punho_pedidos_acesso_actualizado_em
  on public.punho_pedidos_acesso;
create trigger punho_pedidos_acesso_actualizado_em
  before update on public.punho_pedidos_acesso
  for each row execute function public.punho_tocar_actualizado_em();

-- ---------------------------------------------------------------------------
-- 3. Policies de `punho_pedidos_acesso`
-- ---------------------------------------------------------------------------
-- Nome da empresa do caller sem passar pela RLS de `punho_empresas` — evita
-- que a policy dependa de outra policy.
create or replace function public.punho_nome_empresa_atual()
returns text language sql stable security definer set search_path = public as $$
  select e.nome from public.punho_empresas e where e.id = public.punho_empresa_atual();
$$;
revoke all on function public.punho_nome_empresa_atual() from public;
grant execute on function public.punho_nome_empresa_atual() to authenticated;

drop policy if exists "utilizador le o proprio pedido" on public.punho_pedidos_acesso;
create policy "utilizador le o proprio pedido" on public.punho_pedidos_acesso
  for select to authenticated using (user_id = auth.uid());

-- O gestor aprovado vê o que entra para a empresa dele: por convite (já traz
-- `empresa_id`) ou por nome indicado no registo livre.
drop policy if exists "gestor le pedidos da empresa" on public.punho_pedidos_acesso;
create policy "gestor le pedidos da empresa" on public.punho_pedidos_acesso
  for select to authenticated
  using (
    public.punho_e_gestor()
    and (
      empresa_id = public.punho_empresa_atual()
      or (
        public.punho_nome_empresa_atual() is not null
        and lower(trim(empresa_indicada))
            = lower(trim(public.punho_nome_empresa_atual()))
      )
    )
  );

-- Sem policies de INSERT/UPDATE/DELETE de propósito:
--   * INSERT  -> só pelo trigger de auth.users (security definer).
--   * UPDATE  -> só o Control, com service role (aprovar/recusar/revogar).
--   * DELETE  -> ninguém. Revogar é mudança de estado, nunca apagar.

-- ---------------------------------------------------------------------------
-- 4. Registo: trigger que consome o convite
-- ---------------------------------------------------------------------------
-- Corre no insert de `auth.users`, e não numa chamada da app, porque com
-- confirmação de email o utilizador pode só voltar dias depois — o pedido tem
-- de existir na mesma desde o primeiro momento.
create or replace function public.punho_criar_pedido_ao_registar()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_codigo text := nullif(trim(coalesce(new.raw_user_meta_data->>'convite', '')), '');
  v_convite public.punho_convites%rowtype;
  v_empresa text;
  v_perfil text;
begin
  if coalesce(new.raw_user_meta_data->>'app', '') <> 'punho' then
    return new;
  end if;

  if v_codigo is not null then
    select * into v_convite
      from public.punho_convites
     where upper(codigo) = upper(v_codigo)
       and not usado
       and expira_em > now()
       and lower(email) = lower(new.email)
     for update;

    -- Código presente mas imprestável: aborta o registo. A app valida antes,
    -- com `punho_validar_convite()`, para dar mensagem legível; isto é a rede
    -- de segurança para quem chamar o signUp por fora.
    if not found then
      raise exception 'Código de convite inválido, expirado ou já utilizado.'
        using errcode = 'P0001';
    end if;

    update public.punho_convites
       set usado = true, usado_por = new.id, usado_em = now()
     where id = v_convite.id;

    select nome into v_empresa from public.punho_empresas where id = v_convite.empresa_id;

    insert into public.punho_pedidos_acesso
      (user_id, nome, email, empresa_indicada, empresa_id, perfil, origem, convite_id)
    values
      (new.id, new.raw_user_meta_data->>'nome', new.email,
       coalesce(v_empresa, 'Empresa por confirmar'), v_convite.empresa_id,
       v_convite.perfil, 'convite', v_convite.id);

    return new;
  end if;

  -- Registo livre: fica sem empresa associada até o Control decidir.
  v_perfil := case
    when new.raw_user_meta_data->>'perfil' = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem)
  values
    (new.id, new.raw_user_meta_data->>'nome', new.email,
     coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa por confirmar'),
     v_perfil, 'livre');

  return new;
end;
$$;

drop trigger if exists punho_criar_pedido_ao_registar on auth.users;
create trigger punho_criar_pedido_ao_registar after insert on auth.users
  for each row execute function public.punho_criar_pedido_ao_registar();

-- ---------------------------------------------------------------------------
-- 5. RPCs
-- ---------------------------------------------------------------------------

-- Estado de acesso numa só chamada: a app precisa de saber se já é membro
-- activo (abre a app) e, se não for, em que pé está o pedido.
create or replace function public.punho_meu_acesso()
returns table (membro_ativo boolean, perfil text, estado text)
language sql stable security definer set search_path = public as $$
  select
    exists (select 1 from public.punho_membros m
             where m.user_id = auth.uid() and m.ativo),
    (select m.perfil from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1),
    coalesce((select p.estado from public.punho_pedidos_acesso p
               where p.user_id = auth.uid()), 'pendente');
$$;
revoke all on function public.punho_meu_acesso() from public;
grant execute on function public.punho_meu_acesso() to authenticated;

-- Validação do código antes do signUp, para a app poder dizer porquê. Devolve
-- só um estado — nunca o nome da empresa nem quem convidou.
create or replace function public.punho_validar_convite(p_codigo text)
returns text language plpgsql stable security definer set search_path = public as $$
declare v public.punho_convites%rowtype;
begin
  if nullif(trim(coalesce(p_codigo, '')), '') is null then return 'invalido'; end if;
  select * into v from public.punho_convites where upper(codigo) = upper(trim(p_codigo));
  if not found then return 'invalido'; end if;
  if v.usado then return 'usado'; end if;
  if v.expira_em <= now() then return 'expirado'; end if;
  return 'valido';
end;
$$;
revoke all on function public.punho_validar_convite(text) from public;
grant execute on function public.punho_validar_convite(text) to anon, authenticated;

-- Só um gestor com adesão activa cria convites, e sempre para a sua empresa.
create or replace function public.punho_criar_convite(
  p_email text, p_perfil text default 'colaborador'
) returns table (codigo text, expira_em timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  v_empresa uuid;
  v_codigo text;
  v_expira timestamptz := now() + interval '14 days';
begin
  if not public.punho_e_gestor() then
    raise exception 'Só um gestor aprovado pode criar convites.' using errcode = 'P0001';
  end if;
  if p_perfil not in ('gestor', 'colaborador') then
    raise exception 'Perfil inválido.' using errcode = 'P0001';
  end if;
  if nullif(trim(coalesce(p_email, '')), '') is null then
    raise exception 'Indica o email de quem vais convidar.' using errcode = 'P0001';
  end if;

  v_empresa := public.punho_empresa_atual();
  if v_empresa is null then
    raise exception 'Conta sem empresa activa.' using errcode = 'P0001';
  end if;

  -- Liberta um convite anterior por usar para o mesmo email (o índice único
  -- só admite um activo por empresa) e evita colisão com códigos expirados.
  update public.punho_convites
     set usado = true, usado_em = now()
   where empresa_id = v_empresa
     and lower(email) = lower(trim(p_email))
     and not usado;

  v_codigo := upper(encode(gen_random_bytes(5), 'hex'));

  insert into public.punho_convites
    (empresa_id, email, perfil, codigo, criado_por, expira_em)
  values
    (v_empresa, lower(trim(p_email)), p_perfil, v_codigo, auth.uid(), v_expira);

  return query select v_codigo, v_expira;
end;
$$;
revoke all on function public.punho_criar_convite(text, text) from public;
grant execute on function public.punho_criar_convite(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Fechar a auto-criação de empresa
-- ---------------------------------------------------------------------------
-- `punho_criar_empresa_inicial()` (20260728) estava grantada a `authenticated`:
-- qualquer conta autenticada criava uma empresa e nomeava-se gestora dela,
-- saltando por cima da aprovação manual. A criação de empresa passa a ser
-- exclusiva do Control (service role), na aprovação de um pedido `livre`.
revoke all on function public.punho_criar_empresa_inicial(text) from public;
revoke all on function public.punho_criar_empresa_inicial(text) from anon;
revoke all on function public.punho_criar_empresa_inicial(text) from authenticated;

-- As três funções auxiliares de 20260725/26 ficaram com o `execute to public`
-- por omissão. Fecham-se aqui: só contam para RLS de contas autenticadas.
revoke all on function public.punho_empresa_atual() from public;
revoke all on function public.punho_e_gestor() from public;
revoke all on function public.punho_membro_ativo() from public;
grant execute on function public.punho_empresa_atual() to authenticated;
grant execute on function public.punho_e_gestor() to authenticated;
grant execute on function public.punho_membro_ativo() to authenticated;

commit;
