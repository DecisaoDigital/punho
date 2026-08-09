-- As reservas continuam a ser cópia — mas passam a saber até onde copiaram.
--
-- ## Porquê isto não é um guarda
--
-- Um guarda mede o estrago depois de feito: conta as linhas dos dois lados e
-- compara. É O(tudo), só diz *que* divergiu — nunca *quando* nem *a partir de
-- quê* — e depende de alguém se lembrar de o correr.
--
-- Uma posição é outra coisa. `punho_operacoes.seq` é monótono; se a projecção
-- guardar "apliquei até ao seq N", então:
--
--   atraso = max(seq) - ultimo_seq
--
-- é uma subtracção, está sempre disponível, e não pode mentir. Recuperar deixa
-- de ser "reprojectar tudo e rezar" e passa a ser "aplicar o que falta".
--
-- E o mais importante: **o gatilho deixa de ser o mecanismo**. Passa a ser
-- pressa. Quem lê chama `punho_reservas_em_dia()` primeiro, que não faz nada
-- quando não há nada a fazer e apanha o atraso quando há. Um gatilho que não
-- dispare — por estar desactivado, substituído, ou contornado por um
-- `session_replication_role = replica` num restauro — passa a custar
-- milissegundos em vez de reservas invisíveis.

create table if not exists public.punho_projeccao_posicao (
  empresa_id     uuid not null references public.punho_empresas(id) on delete cascade,
  entidade       text not null,
  ultimo_seq     bigint not null default 0,
  actualizado_em timestamptz not null default now(),
  primary key (empresa_id, entidade)
);

comment on table public.punho_projeccao_posicao is
  'Ate onde cada projeccao leu o registo. atraso = max(punho_operacoes.seq) - ultimo_seq.';

alter table public.punho_projeccao_posicao enable row level security;

create policy "empresa le a sua posicao" on public.punho_projeccao_posicao
  for select using (empresa_id = public.punho_empresa_atual());

-- Ninguém escreve isto de fora: só as funções SECURITY DEFINER abaixo.
revoke all on public.punho_projeccao_posicao from anon, authenticated;
grant select on public.punho_projeccao_posicao to authenticated;

-- ---------------------------------------------------------------------------
-- Avançar a posição faz parte de projectar, na mesma transacção
-- ---------------------------------------------------------------------------
-- Na mesma transacção de propósito: se a reserva entrou e a posição não
-- avançou, ou ao contrário, ficávamos com uma mentira arrumada. Ou entram as
-- duas ou não entra nenhuma.
create or replace function public.punho_operacoes_projectar()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform punho_projectar_entidade(
    new.empresa_id, new.entidade, new.entidade_id,
    new.payload, new.feito_em, new.por_utilizador
  );

  if new.entidade = 'booking' then
    insert into punho_projeccao_posicao (empresa_id, entidade, ultimo_seq, actualizado_em)
    values (new.empresa_id, 'booking', new.seq, now())
    on conflict (empresa_id, entidade) do update
      set ultimo_seq     = greatest(punho_projeccao_posicao.ultimo_seq, excluded.ultimo_seq),
          actualizado_em = now();
  end if;

  return new;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Pôr em dia — o mecanismo a sério, no caminho de leitura
-- ---------------------------------------------------------------------------
-- Sem parâmetro de empresa **de propósito**. A empresa vem da sessão, nunca de
-- quem chama: um `p_empresa uuid` deixava qualquer cliente escolher em que casa
-- mandava projectar.
--
-- Devolve quantas operações teve de aplicar. Zero é o caso normal e custa uma
-- comparação de inteiros.
create or replace function public.punho_reservas_em_dia()
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_empresa uuid := punho_empresa_atual();
  v_desde   bigint;
  v_ate     bigint;
  v_op      record;
  v_conta   integer := 0;
begin
  if v_empresa is null then
    return 0;  -- sem empresa activa não há nada para pôr em dia
  end if;

  select coalesce(p.ultimo_seq, 0) into v_desde
  from punho_projeccao_posicao p
  where p.empresa_id = v_empresa and p.entidade = 'booking';
  v_desde := coalesce(v_desde, 0);

  for v_op in
    select o.entidade_id, o.payload, o.feito_em, o.por_utilizador, o.seq
    from punho_operacoes o
    where o.empresa_id = v_empresa and o.entidade = 'booking' and o.seq > v_desde
    order by o.seq
  loop
    perform punho_projectar_entidade(
      v_empresa, 'booking', v_op.entidade_id,
      v_op.payload, v_op.feito_em, v_op.por_utilizador
    );
    v_ate   := v_op.seq;
    v_conta := v_conta + 1;
  end loop;

  if v_conta > 0 then
    insert into punho_projeccao_posicao (empresa_id, entidade, ultimo_seq, actualizado_em)
    values (v_empresa, 'booking', v_ate, now())
    on conflict (empresa_id, entidade) do update
      set ultimo_seq     = greatest(punho_projeccao_posicao.ultimo_seq, excluded.ultimo_seq),
          actualizado_em = now();
  end if;

  return v_conta;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Quanto está atrasado — uma subtracção, não uma contagem
-- ---------------------------------------------------------------------------
create or replace function public.punho_projeccao_atraso()
returns table (entidade text, ultimo_seq bigint, no_registo bigint, atraso bigint)
language sql
stable
security definer
set search_path = public
as $fn$
  select 'booking'::text,
         coalesce(p.ultimo_seq, 0),
         coalesce(max(o.seq), 0),
         greatest(coalesce(max(o.seq), 0) - coalesce(p.ultimo_seq, 0), 0)
  from punho_operacoes o
  left join punho_projeccao_posicao p
    on p.empresa_id = punho_empresa_atual() and p.entidade = 'booking'
  where o.empresa_id = punho_empresa_atual() and o.entidade = 'booking'
  group by p.ultimo_seq
$fn$;

revoke all on function public.punho_reservas_em_dia()  from public, anon;
revoke all on function public.punho_projeccao_atraso() from public, anon;
grant execute on function public.punho_reservas_em_dia()  to authenticated;
grant execute on function public.punho_projeccao_atraso() to authenticated;

-- ---------------------------------------------------------------------------
-- Ponto de partida: aplicar tudo o que houver e gravar onde ficou
-- ---------------------------------------------------------------------------
-- A posição nasce a zero e sobe até ao fim do registo. Além de a acertar, isto
-- corre o caminho de recuperação uma vez em cada empresa — se estivesse
-- partido, partia aqui e não em produção daqui a um mês.
do $blk$
declare
  v_empresa uuid;
  v_op      record;
  v_ate     bigint;
begin
  for v_empresa in select id from punho_empresas loop
    v_ate := 0;
    for v_op in
      select entidade_id, payload, feito_em, por_utilizador, seq
      from punho_operacoes
      where empresa_id = v_empresa and entidade = 'booking'
      order by seq
    loop
      perform punho_projectar_entidade(
        v_empresa, 'booking', v_op.entidade_id,
        v_op.payload, v_op.feito_em, v_op.por_utilizador
      );
      v_ate := v_op.seq;
    end loop;

    if v_ate > 0 then
      insert into punho_projeccao_posicao (empresa_id, entidade, ultimo_seq)
      values (v_empresa, 'booking', v_ate)
      on conflict (empresa_id, entidade) do update
        set ultimo_seq = greatest(punho_projeccao_posicao.ultimo_seq, excluded.ultimo_seq),
            actualizado_em = now();
    end if;
  end loop;
end;
$blk$;
