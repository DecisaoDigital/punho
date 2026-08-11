-- As tarefas do pg_cron, escritas como os comandos que as recriam.
--
-- Não saem no dump do `public` — o pg_cron guarda-as no seu próprio esquema — e
-- perdiam-se sem ninguém dar por isso. É aqui que vive o expurgo RGPD diário.
--
-- O `to_regclass` não é preciosismo: numa base sem a extensão, `from cron.job`
-- nem chega a ser analisado, rebenta, e com `set -e` levava a cópia inteira
-- atrás. Uma cópia de segurança não pode falhar por causa da parte mais
-- pequena dela.
--
-- Correr com: psql -Atq -f copia_agenda.sql
create temp table _agenda(linha text);

do $$
begin
  if to_regclass('cron.job') is null then
    insert into _agenda values ('-- esta base não tem pg_cron');
  else
    execute 'insert into _agenda
               select format(''select cron.schedule(%L, %L, %L);'',
                             jobname, schedule, command)
                 from cron.job order by jobid';
  end if;
  if not exists (select 1 from _agenda) then
    insert into _agenda values ('-- nenhuma tarefa agendada');
  end if;
end $$;

select linha from _agenda;
