-- ---------------------------------------------------------------------------
-- O contabilista corrige o período que lhe pediram
-- ---------------------------------------------------------------------------
--
-- A app pede cinco anos por omissão. Uma empresa aberta em 2024 não tem 2021,
-- e o contabilista que abre o link vê trinta e seis meses que nunca existiram.
-- Isso não é só ruído no ecrã: cada um deles ia contar como lacuna, e o gestor
-- acabava com uma tarefa a pedir-lhe faturação de antes de a empresa existir.
--
-- Quem sabe quando a empresa começou é ele. Portanto é ele que o diz, no
-- próprio formulário, e a partir daí o período pedido encolhe.
--
-- Coluna nova em vez de reescrever `mes_inicial` porque são duas coisas
-- diferentes e as duas interessam: `mes_inicial` é o que o gestor pediu,
-- `mes_inicial_efectivo` é o que o contabilista disse que faz sentido pedir. Um
-- gestor que veja "pedi 5 anos, ele diz que só há desde Março de 2024" ficou a
-- saber alguma coisa sobre a própria empresa.
alter table public.punho_convites_contabilista
  add column if not exists mes_inicial_efectivo date;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'punho_convite_efectivo_na_janela'
  ) then
    alter table public.punho_convites_contabilista
      add constraint punho_convite_efectivo_na_janela check (
        mes_inicial_efectivo is null
        or (mes_inicial_efectivo >= mes_inicial
            and mes_inicial_efectivo <= mes_final
            and extract(day from mes_inicial_efectivo) = 1)
      );
  end if;
end $$;

comment on column public.punho_convites_contabilista.mes_inicial_efectivo is
  'Início real do período, dito pelo contabilista. Encolhe a grelha e as '
  'lacunas; nunca alarga além de mes_inicial, e não apaga nada do que já foi '
  'respondido antes dele.';

-- ---------------------------------------------------------------------------
-- As lacunas passam a contar a partir do início efectivo
-- ---------------------------------------------------------------------------
--
-- É esta a razão de ser da coluna. Sem isto, o contabilista dizia "a empresa
-- começou em 2024", entregava, e o gestor recebia na mesma "faltam 42 meses de
-- faturação" — contados desde 2021. Uma tarefa impossível de fechar é pior do
-- que nenhuma: ensina a ignorar a lista toda.
create or replace function public.punho_lacunas_contabilista(
  p_empresa uuid default null
)
returns table (
  rubrica text,
  rotulo text,
  periodicidade text,
  em_falta integer,
  so_anual integer,
  primeiro_mes date,
  ultimo_mes date
)
language sql
stable
set search_path = public
as $$
  with alvo as (
    select coalesce(p_empresa, punho_empresa_atual()) as empresa_id
  ),
  convite as (
    select c.*,
           -- O que o contabilista disse, se disse; senão o que o gestor pediu.
           coalesce(c.mes_inicial_efectivo, c.mes_inicial) as inicio
      from public.punho_convites_contabilista c, alvo
     where c.empresa_id = alvo.empresa_id
       and c.revogado_em is null
       and (c.submetido_em is not null or c.expira_em < now())
     order by c.criado_em desc
     limit 1
  ),
  esperado as (
    select r.chave, r.rotulo, r.periodicidade,
           case when r.periodicidade = 'mensal'
                then m.mes::date
                else null::date
           end as mes
      from public.punho_rubricas_contabilista r
     cross join convite c
      left join lateral generate_series(
             c.inicio, c.mes_final, interval '1 month'
           ) as m(mes)
             on r.periodicidade = 'mensal'
     where r.activa and r.essencial
  ),
  em_aberto as (
    select e.chave, e.rotulo, e.periodicidade, e.mes,
           -- Há total anual a cobrir este mês? Então não é um buraco, é um
           -- número grosso à espera de ser desdobrado.
           exists (
             select 1
               from public.punho_respostas_contabilista ra
              where ra.empresa_id = (select empresa_id from alvo)
                and ra.rubrica = e.chave
                and ra.ano is not null
                and e.mes is not null
                and ra.ano = extract(year from e.mes)::integer
           ) as coberto_por_anual
      from esperado e
      cross join alvo
      left join public.punho_respostas_contabilista resp
             on resp.empresa_id = alvo.empresa_id
            and resp.rubrica = e.chave
            and resp.ano is null
            and resp.mes is not distinct from e.mes
     where resp.id is null
  )
  select chave, rotulo, periodicidade,
         count(*) filter (where not coberto_por_anual)::integer,
         count(*) filter (where coberto_por_anual)::integer,
         min(mes), max(mes)
    from em_aberto
   group by chave, rotulo, periodicidade
   order by chave;
$$;

-- ---------------------------------------------------------------------------
-- E a porta por onde ele o diz
-- ---------------------------------------------------------------------------
--
-- Só encolhe. Aceitar um início anterior ao pedido era deixar o formulário
-- pedir meses que o gestor não quis, e um `null` devolve ao período original —
-- é assim que se desfaz um engano.
create or replace function public.punho_definir_periodo_contabilista(
  p_convite uuid,
  p_mes_inicial date
)
returns date
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.punho_convites_contabilista%rowtype;
begin
  select * into c
    from public.punho_convites_contabilista
   where id = p_convite
     and revogado_em is null
     and expira_em > now();

  if not found then
    raise exception 'Convite inválido ou expirado.' using errcode = '28000';
  end if;

  if p_mes_inicial is not null then
    if p_mes_inicial < c.mes_inicial or p_mes_inicial > c.mes_final then
      raise exception 'Esse mês está fora do período pedido.'
        using errcode = '22007';
    end if;
    if extract(day from p_mes_inicial) <> 1 then
      raise exception 'O início do período é sempre dia 1.'
        using errcode = '22007';
    end if;
  end if;

  update public.punho_convites_contabilista
     set mes_inicial_efectivo = p_mes_inicial
   where id = c.id;

  return coalesce(p_mes_inicial, c.mes_inicial);
end;
$$;

revoke all on function public.punho_definir_periodo_contabilista(uuid, date)
  from public, anon, authenticated;
