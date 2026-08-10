-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801232211). Estava em
-- produção sem ficheiro no repo.
-- O número no nome é a ordem em que foi aplicada: as quatro mexem na mesma
-- função e por ordem alfabética ficariam trocadas.

create or replace function public.punho_garantir_particao_realtime(p_dia date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text := format('messages_%s', to_char(p_dia, 'YYYY_MM_DD'));
begin
  if to_regclass('realtime.' || quote_ident(v_nome)) is not null then
    return;
  end if;
  execute format(
    'create table realtime.%I partition of realtime.messages for values from (%L) to (%L)',
    v_nome, p_dia, p_dia + 1
  );
exception when others then
  raise warning 'particao realtime %: %', v_nome, sqlerrm;
end;
$$;

comment on function public.punho_garantir_particao_realtime(date) is
  'Cria a particao diaria de realtime.messages se faltar. Existe porque o projecto nao tem pg_cron e a realtime.send falha em silencio sem particao.';

create or replace function public.punho_operacoes_avisar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    perform public.punho_garantir_particao_realtime(current_date);
    perform public.punho_garantir_particao_realtime(current_date + 1);

    perform realtime.send(
      jsonb_build_object('seq', NEW.seq),
      'nova_operacao',
      'punho:empresa:' || NEW.empresa_id::text,
      true
    );
  exception when others then
    raise warning 'campainha do Punho falhou (seq %): %', NEW.seq, sqlerrm;
  end;

  return null;
end;
$$;
