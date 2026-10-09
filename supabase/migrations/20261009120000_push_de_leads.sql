-- Push (FCM) das leads: registo dos aparelhos e gatilhos que chamam `punho-push`.
--
-- Firebase próprio do Punho (projecto punho-fist). O token é do aparelho, mas
-- quem o dono é decide-se aqui, pela sessão: o cliente nunca diz «sou o
-- utilizador X» (princípio da identidade vinda do servidor).
--
-- Aditiva: tabela nova, duas funções novas, dois gatilhos AFTER INSERT que
-- engolem qualquer erro (um push falhado nunca impede uma operação).

create table if not exists public.punho_push_tokens (
  token text not null,
  empresa_id uuid not null,
  user_id uuid not null,
  plataforma text not null default 'android',
  atualizado_em timestamptz not null default now(),
  primary key (token, empresa_id)
);
create index if not exists punho_push_tokens_user on public.punho_push_tokens (empresa_id, user_id);
alter table public.punho_push_tokens enable row level security;
revoke all on public.punho_push_tokens from anon, authenticated;

-- Regista este aparelho para quem tem sessão. Um token pertence a uma pessoa de
-- cada vez: quem o registar fica com ele, os outros donos perdem-no (troca de
-- conta no mesmo telemóvel).
create or replace function public.punho_registar_push(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then raise exception 'sem sessão' using errcode = '42501'; end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then
    raise exception 'token inválido' using errcode = '22023';
  end if;
  delete from punho_push_tokens where token = p_token and user_id <> auth.uid();
  insert into punho_push_tokens (token, empresa_id, user_id)
  select p_token, m.empresa_id, auth.uid()
    from punho_membros m
   where m.user_id = auth.uid() and m.ativo
  on conflict (token, empresa_id)
  do update set user_id = excluded.user_id, atualizado_em = now();
end
$fn$;

create or replace function public.punho_esquecer_push(p_token text)
returns void
language sql
security definer
set search_path = public
as $fn$
  delete from punho_push_tokens where token = p_token and user_id = auth.uid()
$fn$;

revoke all on function public.punho_registar_push(text), public.punho_esquecer_push(text) from public, anon;
grant execute on function public.punho_registar_push(text), public.punho_esquecer_push(text) to authenticated;

-- Gatilho comum: só diz à edge function o que mudou.
create or replace function public.punho_chamar_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  segredo text;
  tipo text := tg_argv[0];
begin
  begin
    select decrypted_secret into segredo
      from vault.decrypted_secrets where name = 'edge_invoke_secret' limit 1;
    if segredo is null then return new; end if;
    perform net.http_post(
      url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/punho-push',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || segredo),
      body := jsonb_build_object('tipo', tipo, 'id', new.id)
    );
  exception when others then
    null;
  end;
  return new;
end
$fn$;
revoke all on function public.punho_chamar_push() from public, anon, authenticated;

drop trigger if exists punho_push_lead_entrada on public.punho_leads_entrada;
create trigger punho_push_lead_entrada
  after insert on public.punho_leads_entrada
  for each row when (new.classificacao in ('aceite', 'retida'))
  execute function public.punho_chamar_push('entrada');

drop trigger if exists punho_push_lead_operacao on public.punho_operacoes;
create trigger punho_push_lead_operacao
  after insert on public.punho_operacoes
  for each row when (new.entidade = 'lead')
  execute function public.punho_chamar_push('operacao');
