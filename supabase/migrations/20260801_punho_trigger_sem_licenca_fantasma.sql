-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801230904). Estava em
-- produção sem ficheiro no repo.

create or replace function public.punho_sync_licenca_from_empresa()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nif            text := NEW.dados->>'nif';
  v_nome_comercial text := NEW.dados->>'nome_comercial';
begin
  if v_nif is null or length(v_nif) < 9 then
    return NEW;
  end if;

  update public.licencas
     set nome           = coalesce(v_nome_comercial, NEW.nome),
         nome_comercial = v_nome_comercial
   where app = 'punho'
     and nif = v_nif;

  return NEW;
end;
$$;

comment on function public.punho_sync_licenca_from_empresa() is
  'Mantem o nome das instalacoes Punho de uma empresa em dia. NAO cria licencas: ate 1 ago 2026 fabricava uma linha por empresa (machine_id "punho:<id>") que aparecia no Control como um terminal instalado sem o ser.';
