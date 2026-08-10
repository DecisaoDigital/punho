-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801195312). Estava em
-- produção sem ficheiro no repo.

create table if not exists public.chaves_mestre (
  nif                    text primary key,
  chave                  text not null unique,
  nome                   text,
  criada_em              timestamptz not null default now(),
  criada_por_machine_id  text,
  criada_por_app         text,
  notas                  text
);

comment on table public.chaves_mestre is
  'Chave mestre da empresa (uma por NIF), metade do par mestre+dispositivo. Nasce na primeira associacao de um dispositivo; o valor e opaco e nao deriva dessa maquina. Escrita por service_role (Edge Functions); lida por authenticated com is_admin() no Control.';

comment on column public.chaves_mestre.criada_por_machine_id is
  'So rasto: que aparelho estava presente quando a chave nasceu. A chave NAO deriva dele e sobrevive-lhe.';

create or replace function public.gerar_chave_mestre(p_prefixo text default null)
returns text
language plpgsql
as $$
declare
  alfabeto constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  corpo    text := '';
  pref     text;
  i        int;
begin
  pref := upper(regexp_replace(coalesce(p_prefixo, ''), '[^A-Za-z]', '', 'g'));
  pref := left(pref, 6);

  for i in 1..12 loop
    corpo := corpo || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
  end loop;

  return case when pref = '' then corpo else pref || '-' || corpo end;
end;
$$;

create or replace function public.obter_ou_criar_chave_mestre(
  p_nif        text,
  p_machine_id text default null,
  p_app        text default null,
  p_nome       text default null,
  p_prefixo    text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chave text;
  v_nova  text;
  tentativa int := 0;
begin
  if p_nif is null or btrim(p_nif) = '' then
    raise exception 'NIF em falta: a chave mestre e sempre de uma empresa';
  end if;

  select chave into v_chave from public.chaves_mestre where nif = btrim(p_nif);
  if v_chave is not null then
    return v_chave;
  end if;

  loop
    tentativa := tentativa + 1;
    v_nova := public.gerar_chave_mestre(p_prefixo);

    begin
      insert into public.chaves_mestre
        (nif, chave, nome, criada_por_machine_id, criada_por_app)
      values
        (btrim(p_nif), v_nova, p_nome, p_machine_id, p_app);
      return v_nova;
    exception
      when unique_violation then
        select chave into v_chave from public.chaves_mestre where nif = btrim(p_nif);
        if v_chave is not null then
          return v_chave;
        end if;
        if tentativa >= 5 then
          raise;
        end if;
    end;
  end loop;
end;
$$;

revoke all on function public.obter_ou_criar_chave_mestre(text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.gerar_chave_mestre(text) from public, anon, authenticated;
grant execute on function public.obter_ou_criar_chave_mestre(text, text, text, text, text) to service_role;
grant execute on function public.gerar_chave_mestre(text) to service_role;

alter table public.chaves_mestre enable row level security;

drop policy if exists chaves_mestre_admin_select on public.chaves_mestre;
create policy chaves_mestre_admin_select
  on public.chaves_mestre for select
  to authenticated
  using (public.is_admin());

alter table public.licencas add column if not exists chave_mestre text;

comment on column public.licencas.chave_mestre is
  'Metade "empresa" do par. NULL nas licencas anteriores a esta mudanca — essas continuam a validar pela base assinada antiga.';

create index if not exists licencas_chave_mestre_idx
  on public.licencas (chave_mestre) where chave_mestre is not null;
