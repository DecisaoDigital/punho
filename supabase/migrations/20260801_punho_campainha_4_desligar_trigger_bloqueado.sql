-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260801233250). Estava em
-- produção sem ficheiro no repo.
-- O número no nome é a ordem em que foi aplicada: as quatro mexem na mesma
-- função e por ordem alfabética ficariam trocadas.

-- O trigger de campainha nao funciona neste projecto: realtime.messages e
-- particionada por dia, nao ha uma unica particao, e criar particoes exige
-- permissoes no schema realtime que nao temos. O Realtime recusa a subscricao
-- com "MissingPartition". Deixa-lo ligado so gera um WARNING por cada operacao
-- gravada, sem nunca avisar ninguem.
--
-- A campainha passou a ser entre aparelhos (ver lib/features/sync/sync_providers.dart).
-- Este trigger fica pronto a ser reactivado no dia em que houver particoes:
--   create trigger punho_operacoes_avisar_trigger
--     after insert on public.punho_operacoes
--     for each row execute function public.punho_operacoes_avisar();

drop trigger if exists punho_operacoes_avisar_trigger on public.punho_operacoes;
