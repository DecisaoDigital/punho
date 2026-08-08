-- Quem é a pessoa, dito por ela própria.
--
-- O nome vinha só de `punho_pedidos_acesso`, onde a identidade nasce. Isso
-- deixa de fora duas situações reais: quem foi feito membro por outra via e
-- nunca teve pedido nenhum (é o caso de metade dos membros de hoje), e quem
-- escreveu o nome mal e não tem por onde o corrigir. Nenhuma delas tinha
-- solução — não havia sítio para guardar a correcção.
--
-- Este é esse sítio. Uma linha por pessoa, escrita por ela. Não substitui o
-- pedido de acesso: o pedido é o registo histórico de como entrou, imutável;
-- isto é quem ela é hoje, e pode mudar.
--
-- O contribuinte fica aqui e não em `licencas`: o NIF de `licencas` é o da
-- EMPRESA, para facturação. Este é o da pessoa, para a ficha de colaborador.
-- Confundi-los era pôr o NIF de um funcionário numa factura.

create table if not exists public.punho_perfis (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nome text,
  nif text,
  actualizado_em timestamptz not null default now()
);

comment on table public.punho_perfis is
  'Nome e contribuinte que cada pessoa declara sobre si. Escrita só pela RPC '
  'punho_guardar_o_meu_perfil; leitura pelos membros activos da mesma empresa.';

alter table public.punho_perfis enable row level security;

-- Leitura: a própria pessoa, e quem partilha empresa com ela.
--
-- Os colegas precisam de ler para o nome aparecer onde interessa — "quem
-- atendeu", "quem marcou". Sem isso o nome ficava guardado e invisível, que é
-- onde já estava.
--
-- O NIF viaja nesta mesma linha. É deliberado e é o preço de a ficha de
-- colaborador existir: quem trabalha na mesma empresa vê a ficha dos colegas.
-- Não sai da empresa — a política liga as duas pontas por `punho_membros`.
drop policy if exists punho_perfis_leitura on public.punho_perfis;
create policy punho_perfis_leitura on public.punho_perfis
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
        from public.punho_membros meu
        join public.punho_membros dele
          on dele.empresa_id = meu.empresa_id
       where meu.user_id = auth.uid()
         and meu.ativo
         and dele.user_id = punho_perfis.user_id
         and dele.ativo
    )
  );

-- Sem política de INSERT nem de UPDATE, de propósito: a única escrita é pela
-- RPC abaixo, que corre como definer e valida. Um cliente que tentasse gravar
-- directamente não passava a RLS — e a validação do NIF não é opcional só
-- porque alguém contornou o ecrã.
revoke all on table public.punho_perfis from anon;
grant select on table public.punho_perfis to authenticated;

-- Dígito de controlo do NIF português.
--
-- Nove dígitos são a forma; isto é a substância. Um NIF com o dígito errado é
-- sempre uma gralha, e apanhá-la no momento em que se escreve poupa descobri-la
-- meses depois, num documento que já saiu.
create or replace function public.punho_nif_valido(p_nif text)
returns boolean
language plpgsql
immutable
as $function$
declare
  v text := regexp_replace(coalesce(p_nif, ''), '\s', '', 'g');
  v_soma integer := 0;
  v_controlo integer;
  i integer;
begin
  if v !~ '^\d{9}$' then
    return false;
  end if;
  for i in 1..8 loop
    v_soma := v_soma + (substr(v, i, 1)::integer * (10 - i));
  end loop;
  v_controlo := 11 - (v_soma % 11);
  if v_controlo >= 10 then
    v_controlo := 0;
  end if;
  return v_controlo = substr(v, 9, 1)::integer;
end;
$function$;

-- Guardar o meu nome e o meu contribuinte.
--
-- Quem é o dono da linha não vem do pedido: sai de `auth.uid()`. Um parâmetro
-- `user_id` aqui seria uma forma de qualquer pessoa reescrever a ficha de
-- outra.
--
-- O NIF é opcional. Exigi-lo travava alguém que só o quer pôr depois, e um
-- ecrã que não deixa gravar o nome porque falta o contribuinte é um ecrã que
-- não se preenche. Mas se vier, tem de estar certo: um NIF inválido é
-- recusado, não guardado à espera de dar erro mais tarde.
create or replace function public.punho_guardar_o_meu_perfil(
  p_nome text,
  p_nif text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_nome text := nullif(btrim(coalesce(p_nome, '')), '');
  v_nif text := nullif(regexp_replace(coalesce(p_nif, ''), '\s', '', 'g'), '');
begin
  if v_user is null then
    raise exception 'É preciso ter sessão iniciada.' using errcode = 'P0001';
  end if;

  if v_nome is null or length(v_nome) < 2 then
    raise exception 'O nome é obrigatório.' using errcode = 'P0001';
  end if;

  if v_nif is not null and not public.punho_nif_valido(v_nif) then
    raise exception 'O contribuinte não é válido.' using errcode = 'P0001';
  end if;

  insert into public.punho_perfis (user_id, nome, nif, actualizado_em)
  values (v_user, v_nome, v_nif, now())
  on conflict (user_id) do update
    set nome = excluded.nome,
        nif = excluded.nif,
        actualizado_em = now();

  return jsonb_build_object('nome', v_nome, 'nif', v_nif);
end;
$function$;

revoke all on function public.punho_guardar_o_meu_perfil(text, text) from public;
revoke all on function public.punho_guardar_o_meu_perfil(text, text) from anon;
grant execute on function public.punho_guardar_o_meu_perfil(text, text) to authenticated;
grant execute on function public.punho_guardar_o_meu_perfil(text, text) to service_role;

-- `punho_meu_acesso` passa a devolver o perfil, e o contribuinte com ele.
--
-- Precedência: o que a pessoa declarou sobre si ganha ao que escreveu no
-- pedido de acesso. O pedido é de quando entrou e não se corrige; o perfil é
-- de agora. Se não houver perfil, cai no pedido — é o que faz as contas
-- antigas continuarem a mostrar o nome que sempre mostraram.
--
-- Muda a lista de colunas devolvidas, por isso é `drop` e não `replace`: o
-- Postgres não deixa alterar o tipo de retorno de uma função. As permissões
-- voltam a seguir, iguais às que tinha.
drop function if exists public.punho_meu_acesso();

create or replace function public.punho_meu_acesso()
returns table(
  membro_ativo boolean,
  perfil text,
  estado text,
  empresa_id uuid,
  nome text,
  empresa_nome text,
  nif text
)
language sql
stable
security definer
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
      where m.user_id = auth.uid() and m.ativo limit 1),
    coalesce(
      (select nullif(btrim(f.nome), '') from public.punho_perfis f
        where f.user_id = auth.uid()),
      (select nullif(btrim(p.nome), '') from public.punho_pedidos_acesso p
        where p.user_id = auth.uid())
    ),
    (select nullif(btrim(e.nome), '')
       from public.punho_membros m
       join public.punho_empresas e on e.id = m.empresa_id
      where m.user_id = auth.uid() and m.ativo limit 1),
    (select nullif(btrim(f.nif), '') from public.punho_perfis f
      where f.user_id = auth.uid());
$function$;

revoke all on function public.punho_meu_acesso() from public;
revoke all on function public.punho_meu_acesso() from anon;
grant execute on function public.punho_meu_acesso() to authenticated;
grant execute on function public.punho_meu_acesso() to service_role;

-- **O `grant select` acima não chegava.**
--
-- O Supabase tem `alter default privileges ... grant all on tables to anon,
-- authenticated, service_role` no schema `public`. Uma tabela nova nasce com
-- INSERT, UPDATE e DELETE já concedidos, e um `grant select` por cima não tira
-- nada — só confirma o que já lá estava.
--
-- Sem estes `revoke`, a única coisa a travar uma escrita directa à tabela era
-- a ausência de política de RLS. Isso chega para bloquear, mas apanhou-se em
-- teste que um PATCH devolvia **HTTP 204** — a RLS não deixava tocar em linha
-- nenhuma, e o PostgREST responde 204 na mesma. Uma porta trancada que responde
-- "feito" é pior que uma porta aberta: quem testar acredita que gravou, e quem
-- auditar acredita que está fechado sem o conseguir distinguir.
--
-- Com o revoke a resposta passa a ser 403 / 42501, que é verdade. A RPC
-- continua a escrever por ser `security definer`.
revoke insert, update, delete, truncate, references, trigger
  on table public.punho_perfis from authenticated;
revoke all on table public.punho_perfis from anon;
grant select on table public.punho_perfis to authenticated;
