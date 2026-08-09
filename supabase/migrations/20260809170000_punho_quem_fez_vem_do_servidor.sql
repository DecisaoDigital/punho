-- Quem fez a operação passa a ser afirmação do servidor, não do cliente.
--
-- ## O que se provou
--
-- Com a sessão de um colaborador da Depilconcept, esta chamada foi aceite:
--
--   POST /rest/v1/punho_operacoes
--   { "entidade": "customer", ...,
--     "por_utilizador": "<id do gestor>",
--     "feito_em": "2020-01-01T00:00:00Z" }
--
-- HTTP 201. A vista `punho_clientes` passou a mostrar esse cliente como criado
-- pelo gestor, em 2020. Nada mentiu — ninguém perguntou.
--
-- O registo é a única fonte de verdade desta aplicação. Um registo em que o
-- autor de cada linha é escolhido por quem a escreve não é um registo: é um
-- caderno onde qualquer um assina por qualquer um. E como as vistas derivam
-- `created_by` e `created_at` daqui, a falsificação propaga-se a tudo o que o
-- gestor lê.
--
-- ## O que muda
--
-- `por_utilizador` deixa de ser aceite de fora: é sempre `auth.uid()`. Quando
-- não há sessão (semeadura pelo `postgres`, funções `security definer`) mantém-se
-- o que vier, porque aí quem escreve já é o servidor.
--
-- `feito_em` **continua a vir do cliente**, e tem de continuar: a fila offline
-- existe precisamente para o operador registar às 9h o que fez às 7h no
-- estaleiro sem rede. O que não se aceita é uma data no futuro — essa só serve
-- para uma entidade parecer mais recente do que as alterações que vieram depois.
--
-- E passa a haver `recebido_em`: a hora do relógio do servidor, que ninguém
-- escreve. O relógio do telemóvel é uma alegação; este é um facto. Com os dois
-- sabe-se sempre quanto tempo uma operação esteve em fila.
--
-- ## Despesas
--
-- O operador passa a poder lançar despesas — é o que o separador Hoje precisa.
-- Mas só vê as suas: a política de leitura filtra `expense` por autor. O gestor
-- vê todas, como sempre.
--
-- Um operador também não pode escrever por cima da despesa de outro. Isso não
-- se consegue exprimir em `punho_colaborador_pode_escrever(entidade, payload)`,
-- que não recebe a entidade nem a empresa — vai no carimbo, que tem o `NEW`
-- inteiro.

-- ---------------------------------------------------------------------------
-- A hora a que o servidor soube
-- ---------------------------------------------------------------------------
alter table public.punho_operacoes
  add column if not exists recebido_em timestamptz not null default now();

comment on column public.punho_operacoes.recebido_em is
  'Relogio do servidor. feito_em e a alegacao do telemovel; este e o facto.';

-- ---------------------------------------------------------------------------
-- O carimbo
-- ---------------------------------------------------------------------------
-- Corre antes da validação: o nome começa por `c` e os gatilhos disparam por
-- ordem alfabética. Não é uma subtileza que se deva depender dela em silêncio,
-- por isso fica escrito.
create or replace function public.punho_operacoes_carimbar()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_perfil text;
begin
  if auth.uid() is not null then
    new.por_utilizador := auth.uid();
  end if;

  new.recebido_em := now();

  -- Uma pequena folga para o relógio do telemóvel estar adiantado. Meia hora
  -- chega para desafinação normal e não chega para inventar história.
  if new.feito_em is null or new.feito_em > now() + interval '30 minutes' then
    new.feito_em := now();
  end if;

  if auth.uid() is null then
    return new;  -- é o próprio servidor a escrever
  end if;

  v_perfil := punho_perfil_na_empresa(new.empresa_id);

  -- A despesa de um operador é dele. Voltar a escrever sobre a mesma entidade é
  -- corrigi-la, e corrigir a de outra pessoa não é trabalho do operador.
  if v_perfil = 'colaborador' and new.entidade = 'expense' then
    if exists (
      select 1 from punho_operacoes o
      where o.empresa_id = new.empresa_id
        and o.entidade = 'expense'
        and o.entidade_id = new.entidade_id
        and o.por_utilizador is distinct from auth.uid()
    ) then
      raise exception 'Essa despesa foi lançada por outra pessoa.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$fn$;

revoke all on function public.punho_operacoes_carimbar() from public, anon, authenticated;

drop trigger if exists punho_operacoes_carimbo on public.punho_operacoes;
create trigger punho_operacoes_carimbo
  before insert on public.punho_operacoes
  for each row execute function public.punho_operacoes_carimbar();

-- ---------------------------------------------------------------------------
-- O operador lança despesas, e vê as suas
-- ---------------------------------------------------------------------------
create or replace function public.punho_colaborador_pode_escrever(
  p_entidade text, p_payload jsonb
) returns boolean
language sql
immutable
set search_path = public
as $fn$
  select case p_entidade
    when 'customer' then coalesce((p_payload->>'archived')::boolean, false) is not true
    when 'lead' then true
    when 'booking' then true
    when 'receipt' then true
    when 'machine' then coalesce((p_payload->>'archived')::boolean, false) is not true
    -- Novo. Quem gasta é quem anda na rua: combustível, portagens, uma peça
    -- comprada a meio de uma entrega. Obrigar a passar pelo gestor era garantir
    -- que a despesa se perdia.
    when 'expense' then true
    when 'vehicle' then false
    when 'collaborator' then false
    else false
  end
$fn$;

drop policy if exists punho_operacoes_membro_le on public.punho_operacoes;

create policy punho_operacoes_membro_le on public.punho_operacoes
  for select
  using (
    case public.punho_perfil_na_empresa(empresa_id)
      when 'gestor' then true
      when 'colaborador' then
        case
          -- As contas da empresa não são dele. As dele são.
          when entidade = 'expense' then por_utilizador = auth.uid()
          when entidade in ('vehicle', 'collaborator') then false
          else true
        end
      else false
    end
  );

-- ---------------------------------------------------------------------------
-- A despesa diz de quem é
-- ---------------------------------------------------------------------------
-- «O gestor tem de ver quem lhe enviou o gasto. Nome do funcionário, horas,
-- data.» O nome não vai no payload de propósito: o payload é do cliente, e o
-- nome de quem lançou é precisamente o que o cliente não pode dizer. Vem daqui,
-- por junção ao registo de membros.
drop view if exists public.punho_despesas;

create view public.punho_despesas
with (security_invoker = true) as
with ult as (
  select o.empresa_id, o.entidade_id, o.payload, o.feito_em, o.recebido_em, o.seq,
         o.por_utilizador,
         row_number() over (partition by o.empresa_id, o.entidade_id order by o.seq desc) as rn,
         min(o.feito_em) over (partition by o.empresa_id, o.entidade_id) as nasceu_em,
         count(*)       over (partition by o.empresa_id, o.entidade_id) as revisoes,
         first_value(o.por_utilizador) over (
           partition by o.empresa_id, o.entidade_id order by o.seq) as autor
  from public.punho_operacoes o
  where o.entidade = 'expense'
)
select public.punho_id_estavel(u.empresa_id, u.entidade_id) as id,
       u.empresa_id,
       u.autor         as created_by,
       u.feito_em      as updated_at,
       u.nasceu_em     as created_at,
       u.revisoes::int as revision,
       u.payload       as dados,
       u.entidade_id   as id_local,
       -- Quem lançou, pelo nome por que os colegas o conhecem.
       coalesce(
         nullif(btrim(c.dados->>'name'), ''),
         nullif(btrim(f.nome), ''),
         'Sem nome'
       ) as lancada_por,
       u.por_utilizador as lancada_por_user_id,
       u.recebido_em    as recebida_em
from ult u
left join public.punho_membros m
       on m.user_id = u.por_utilizador and m.empresa_id = u.empresa_id
left join public.punho_perfis f
       on f.user_id = u.por_utilizador
left join public.punho_colaboradores c
       on c.id = m.colaborador_id
where u.rn = 1;

grant select on public.punho_despesas to authenticated;

comment on view public.punho_despesas is
  'Vista sobre punho_operacoes. lancada_por vem do registo de membros, nunca do payload.';

-- ---------------------------------------------------------------------------
-- Quanto falta cobrar, por reserva
-- ---------------------------------------------------------------------------
-- A app do operador tinha «Por cobrar» a listar toda a reserva com valor
-- previsto, e aceitar um pagamento não a tirava de lá: nada subtraía o que já
-- tinha entrado. O mesmo cartão ficava com o mesmo botão, e tocar-lhe outra vez
-- criava um segundo recibo pelo valor todo.
--
-- A subtracção faz-se aqui e não no telemóvel: quem cobra pode não ser quem
-- marcou, e dois operadores no mesmo cliente têm de ver a mesma dívida.
create or replace view public.punho_cobrancas
with (security_invoker = true) as
select r.empresa_id,
       r.id                     as reserva_id,
       r.id_local               as reserva_id_local,
       r.cliente_id,
       r.cliente_nome_snapshot  as cliente,
       r.estado,
       r.inicio,
       r.fim,
       coalesce(r.valor_previsto_centimos, 0)               as previsto_centimos,
       coalesce(rec.recebido, 0)::bigint                    as recebido_centimos,
       (coalesce(r.valor_previsto_centimos, 0) - coalesce(rec.recebido, 0))::bigint
                                                            as por_cobrar_centimos
from public.punho_reservas r
left join lateral (
  -- `case` e não um cast directo: um recibo com `amountCents` em texto ou em
  -- falta rebentava a vista inteira, e com ela o ecrã de cobranças. Vale zero e
  -- fica visível na lista de recibos, em vez de derrubar tudo.
  select sum(
    case when jsonb_typeof(v.dados->'amountCents') = 'number'
         then (v.dados->>'amountCents')::bigint else 0 end
  ) as recebido
  from public.punho_recebimentos v
  where v.empresa_id = r.empresa_id
    and v.dados->>'bookingId' = r.id_local
    and coalesce((v.dados->>'archived')::boolean, false) is not true
) rec on true;

grant select on public.punho_cobrancas to authenticated;

comment on view public.punho_cobrancas is
  'Previsto menos recebido, por reserva. Quem cobra pode nao ser quem marcou.';

-- ---------------------------------------------------------------------------
-- A app precisa de saber que colaborador é quem está sentado nela
-- ---------------------------------------------------------------------------
-- Sem isto o operador é uma conta, não uma pessoa: o recibo que ele aceita fica
-- com `recordedByCollaboratorId` a nulo porque a app não tem como saber a que
-- ficha corresponde. A ligação existe em `punho_membros.colaborador_id` desde
-- que a aprovação passou a criar a ficha — só não estava a ser dita a ninguém.
-- Os nomes das colunas ficam **exactamente** como estavam. As duas apps lêem-nas
-- pelo nome (`json['membro_ativo']`, `json['estado']`, …) e um `estado_pedido`
-- mais bonito era a app do gestor a deixar de saber se há pedido. Só se
-- acrescenta uma coluna ao fim.
drop function if exists public.punho_meu_acesso();

create function public.punho_meu_acesso()
returns table (
  membro_ativo boolean, perfil text, estado text, empresa_id uuid,
  nome text, empresa_nome text, nif text, colaborador_id uuid
)
language sql
stable
security definer
set search_path = public
as $fn$
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
      where f.user_id = auth.uid()),
    (select m.colaborador_id from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1);
$fn$;

revoke all on function public.punho_meu_acesso() from public, anon;
grant execute on function public.punho_meu_acesso() to authenticated;

-- ---------------------------------------------------------------------------
-- «Pendente» quando não se pediu nada é uma espera que nunca acaba
-- ---------------------------------------------------------------------------
-- Quem criasse conta e não tivesse pedido nenhum recebia `'pendente'` — a app
-- dizia-lhe que estava à espera de aprovação, o gestor não tinha nada na lista,
-- e ninguém ia lá. `'sem_pedido'` é a verdade, e é accionável: quer dizer
-- «pede».
create or replace function public.punho_meu_estado_acesso()
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select coalesce(
    (select estado from public.punho_pedidos_acesso where user_id = auth.uid()),
    'sem_pedido'
  );
$fn$;
