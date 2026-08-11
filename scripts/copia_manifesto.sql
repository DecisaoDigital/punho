-- Inventário verificável de uma base do Punho.
--
-- Corre-se duas vezes: na base viva, na altura da cópia, e na base restaurada
-- a partir dessa cópia. Se as duas listas forem iguais, o restauro trouxe tudo.
--
-- Contam-se linhas a sério (count(*)) e não `reltuples` — o planeador nunca
-- correu ANALYZE aqui e as estimativas estão todas a -1. O truque do
-- query_to_xml é o que permite contar todas as tabelas numa só consulta.
--
-- Correr sempre com: psql -At -F '|' -f copia_manifesto.sql
with tabelas as (
  select c.relname as nome,
         (xpath('/row/n/text()',
                query_to_xml(format('select count(*) as n from public.%I', c.relname),
                             false, true, '')))[1]::text::bigint as linhas
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public'
     and c.relkind = 'r'
)
select 'tabela ' || nome, linhas from tabelas
union all
select 'total de tabelas', count(*) from tabelas
union all
select 'total de linhas', coalesce(sum(linhas), 0) from tabelas
union all
select 'vistas', count(*) from pg_views where schemaname = 'public'
union all
select 'funcoes', count(*)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
union all
select 'politicas rls', count(*) from pg_policies where schemaname = 'public'
union all
select 'tabelas com rls ligado', count(*)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
union all
select 'gatilhos', count(*)
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and not t.tgisinternal
union all
select 'indices', count(*) from pg_indexes where schemaname = 'public'
union all
select 'chaves estrangeiras', count(*)
  from pg_constraint co join pg_namespace n on n.oid = co.connamespace
 where n.nspname = 'public' and co.contype = 'f'
union all
-- Fora do `public`: as contas têm de vir na cópia, e as tarefas agendadas não
-- vêm — o pg_cron não carrega num contentor descartável. Ficam no agenda.sql.
select 'contas de utilizador',
       case when to_regclass('auth.users') is null then 0
            else (xpath('/row/n/text()',
                        query_to_xml('select count(*) as n from auth.users',
                                     false, true, '')))[1]::text::bigint end
union all
select 'tarefas agendadas',
       case when to_regclass('cron.job') is null then 0
            else (xpath('/row/n/text()',
                        query_to_xml('select count(*) as n from cron.job',
                                     false, true, '')))[1]::text::bigint end
order by 1;
