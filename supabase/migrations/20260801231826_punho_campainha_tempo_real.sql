-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801231826). Estava em
-- produção sem ficheiro no repo.
-- O número no nome é a ordem em que foi aplicada: as quatro mexem na mesma
-- função e por ordem alfabética ficariam trocadas.

drop policy if exists punho_ouvir_canal_da_empresa on realtime.messages;
create policy punho_ouvir_canal_da_empresa
  on realtime.messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.punho_membros m
      where m.user_id = auth.uid()
        and m.ativo
        and realtime.topic() = 'punho:empresa:' || m.empresa_id::text
    )
  );

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

comment on function public.punho_operacoes_avisar() is
  'Avisa os aparelhos da empresa de que ha operacoes novas. Envia SO o seq — quem ouve puxa pelo caminho normal. Falha em silencio de proposito: nao pode abortar a insercao da operacao.';

drop trigger if exists punho_operacoes_avisar_trigger on public.punho_operacoes;
create trigger punho_operacoes_avisar_trigger
  after insert on public.punho_operacoes
  for each row
  execute function public.punho_operacoes_avisar();
