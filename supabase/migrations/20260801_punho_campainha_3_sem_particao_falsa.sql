-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801232408). Estava em
-- produção sem ficheiro no repo.
-- O número no nome é a ordem em que foi aplicada: as quatro mexem na mesma
-- função e por ordem alfabética ficariam trocadas.

drop function if exists public.punho_garantir_particao_realtime(date);

create or replace function public.punho_operacoes_avisar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
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
