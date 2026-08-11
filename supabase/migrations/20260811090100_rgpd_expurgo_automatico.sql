-- Guardar para sempre não é uma decisão, é a falta dela.
--
-- ## O que estava a acontecer
--
-- Não havia expurgo nenhum. Nem `pg_cron`, nem script, nem prazo escrito em
-- lado nenhum. `pings` guardava NIF desde o primeiro dia da base. `punho_erros`
-- guarda utilizador, máquina e pilha de excepção. `licencas_audit` guarda o
-- NIF e o nome dentro do `antes`/`depois` — incluindo de licenças que já foram
-- apagadas, e que por isso já nem se sabe de quem eram.
--
-- O RGPD não obriga a apagar tudo; obriga a ter um prazo e a cumpri-lo. O que
-- faltava era o prazo.
--
-- ## Os prazos, e porque não são iguais para tudo
--
--   pings                          30 dias   telemetria, nenhuma obrigação legal
--   punho_erros                    30 dias   diagnóstico, morre com a versão
--   registar_terminal_tentativas   30 dias   rate limit, não é histórico
--   punho_leads_entrada            6 meses   contacto que nunca converteu
--   licencas_audit                 12 meses  prova de decisões sobre licenças
--
-- E o que **não** se toca, de propósito: recibos, despesas, séries comunicadas,
-- guias, assinaturas, licenças activas e tudo o que seja colaborador. Aí manda
-- a lei fiscal (10 anos, CIVA art. 52.º) e a laboral (5 anos), e nenhuma delas
-- se negoceia com um cron.
--
-- ## Porque é que corre na base e não no i9
--
-- Porque o expurgo tem de acontecer com o portátil desligado. Um cron no i9
-- transformava uma obrigação legal numa dependência de alguém não ter feito
-- shutdown.

create table if not exists punho_expurgos (
  id bigserial primary key,
  corrido_em timestamptz not null default now(),
  contagens jsonb not null
);

comment on table punho_expurgos is
  'Prova de que o expurgo correu e quanto apagou. Sem isto, «temos retenção» é '
  'uma afirmação sem registo.';

alter table punho_expurgos enable row level security;

drop policy if exists punho_expurgos_admin_le on punho_expurgos;
create policy punho_expurgos_admin_le on punho_expurgos
  for select to authenticated
  using (is_admin());

create or replace function punho_expurgar_dados()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_pings integer := 0;
  v_erros integer := 0;
  v_tentativas integer := 0;
  v_leads integer := 0;
  v_auditoria integer := 0;
  v_contagens jsonb;
begin
  delete from pings where created_at < now() - interval '30 days';
  get diagnostics v_pings = row_count;

  delete from punho_erros
   where coalesce(recebido_em, acontecido_em) < now() - interval '30 days';
  get diagnostics v_erros = row_count;

  delete from registar_terminal_tentativas
   where criado_em < now() - interval '30 days';
  get diagnostics v_tentativas = row_count;

  delete from punho_leads_entrada
   where recebida_em < now() - interval '6 months';
  get diagnostics v_leads = row_count;

  delete from licencas_audit
   where criado_em < now() - interval '12 months';
  get diagnostics v_auditoria = row_count;

  v_contagens := jsonb_build_object(
    'pings', v_pings,
    'punho_erros', v_erros,
    'registar_terminal_tentativas', v_tentativas,
    'punho_leads_entrada', v_leads,
    'licencas_audit', v_auditoria
  );

  insert into punho_expurgos (contagens) values (v_contagens);

  return v_contagens;
end;
$$;

comment on function punho_expurgar_dados() is
  'Retenção (RGPD art. 5.º-1-e). Corre sozinho todos os dias às 04:17 UTC. '
  'Não toca em nada com obrigação fiscal ou laboral.';

-- Ninguém chama isto do lado do cliente. Quem chama é o agendador.
revoke all on function punho_expurgar_dados() from public;
revoke all on function punho_expurgar_dados() from anon;
revoke all on function punho_expurgar_dados() from authenticated;

create extension if not exists pg_cron;

-- Idempotente: se já lá estiver de uma passagem anterior, tira-se e volta a
-- pôr-se, para o horário ser o que este ficheiro diz e não o que sobrou.
select cron.unschedule(jobid)
  from cron.job
 where jobname = 'punho_expurgo_diario';

select cron.schedule(
  'punho_expurgo_diario',
  '17 4 * * *',
  $cron$select public.punho_expurgar_dados();$cron$
);
