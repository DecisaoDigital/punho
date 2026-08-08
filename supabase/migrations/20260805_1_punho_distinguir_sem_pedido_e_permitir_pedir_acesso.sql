-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805141451). Estava em
-- produção sem ficheiro no repo.

-- "Não há pedido" não é "pedido pendente".
--
-- O `coalesce(..., 'pendente')` que aqui estava fazia a função responder
-- «pendente» a quem nunca pediu nada. A app mostrava "Pedido em análise" e o
-- Control não tinha linha nenhuma para aprovar — um beco sem saída para
-- qualquer conta que perca a adesão (revogada, ou empresa apagada).
--
-- Passa a devolver `null` quando não há pedido. É compatível com as versões já
-- instaladas: o cliente antigo faz `?? 'pendente'` e continua a ver o que via.
create or replace function public.punho_meu_acesso()
returns table(membro_ativo boolean, perfil text, estado text, empresa_id uuid)
language sql
stable security definer
set search_path to 'public'
as $function$
  select
    exists (select 1 from public.punho_membros m
             where m.user_id = auth.uid() and m.ativo),
    (select m.perfil from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1),
    (select p.estado from public.punho_pedidos_acesso p
      where p.user_id = auth.uid()),
    (select m.empresa_id from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1);
$function$;

-- Pedir acesso deixa de ser exclusivo do instante do registo.
--
-- Até aqui o pedido só nascia no trigger `punho_criar_pedido_ao_registar`, que
-- dispara no INSERT em auth.users. Quem já tinha conta não tinha como pedir —
-- e é exactamente a situação de quem foi revogado ou cuja empresa desapareceu.
--
-- A identidade vem toda do servidor: `auth.uid()` e o email de `auth.users`.
-- Quem chama só diz o nome, a empresa e o perfil — nunca quem é.
create or replace function public.punho_pedir_acesso(
  p_nome text,
  p_empresa text,
  p_perfil text default 'gestor'
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_estado text;
begin
  if v_user is null then
    raise exception 'É preciso ter sessão iniciada para pedir acesso.'
      using errcode = 'P0001';
  end if;

  -- Já é membro: não há nada a pedir.
  if exists (select 1 from public.punho_membros m
              where m.user_id = v_user and m.ativo) then
    return 'membro';
  end if;

  -- Já pediu: devolve o estado em que está, sem criar outro. Serve também de
  -- travão a quem foi recusado ou revogado — voltar a pedir seria dar a volta
  -- a uma decisão que já foi tomada.
  select estado into v_estado
    from public.punho_pedidos_acesso where user_id = v_user;
  if found then
    return v_estado;
  end if;

  select email into v_email from auth.users where id = v_user;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem)
  values
    (v_user,
     nullif(trim(coalesce(p_nome, '')), ''),
     v_email,
     coalesce(nullif(trim(coalesce(p_empresa, '')), ''), 'Empresa por confirmar'),
     case when p_perfil = 'gestor' then 'gestor' else 'colaborador' end,
     'livre');

  return 'pendente';
end;
$function$;

revoke all on function public.punho_pedir_acesso(text, text, text) from public, anon;
grant execute on function public.punho_pedir_acesso(text, text, text) to authenticated;
