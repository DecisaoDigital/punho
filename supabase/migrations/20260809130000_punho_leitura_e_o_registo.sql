-- As tabelas derivadas passam a vistas sobre o registo.
--
-- ## Porquê
--
-- A 8/8/2026 a app do gestor mostrava 20 clientes e a Punho OP mostrava 8. Os
-- 20 estavam todos em `punho_operacoes`; 12 nunca chegaram a `punho_clientes`.
-- Ninguém deu erro: o `insert` respondeu 201, o registo ficou completo, e a
-- cópia que o operador lê ficou para trás em silêncio durante 24 horas.
--
-- O defeito não é o gatilho ter falhado uma vez. É haver **duas cópias da mesma
-- verdade sem nada que verifique que andam juntas**. Enquanto existirem duas,
-- podem divergir; e como nada guarda "a cópia está actualizada até à operação
-- N", a única forma de saber era recontar tudo e comparar.
--
-- Uma vista não pode divergir do registo porque não é uma segunda cópia: é o
-- registo, lido de outra maneira. O problema deixa de ser detectável porque
-- deixa de ser possível.
--
-- ## O que fica de fora
--
-- `punho_reservas` continua tabela: precisa de índices por intervalo de datas
-- (`inicio < X and fim > Y`) e de junção a `punho_reserva_maquinas`. Essa leva
-- posição explícita — ver 20260809140000_punho_reservas_com_posicao.sql.
--
-- ## Segurança
--
-- As vistas são `security_invoker = true`: quem manda é o RLS de
-- `punho_operacoes`, avaliado como o utilizador que pergunta. Isso reproduz as
-- políticas antigas sem as duplicar —
--   membros:  customer, machine, lead, receipt
--   gestor:   expense, vehicle, collaborator
-- — desde que o registo não mostre pessoal a colaboradores, que é o que a
-- migração 20260809120000 foi fechar. Sem ela, estas vistas **abriam** acesso a
-- salários em vez de o manter fechado. A ordem importa.
--
-- ## Reversibilidade
--
-- As tabelas antigas não são apagadas: passam a `*_copia_2026_08_09`. Os dados
-- são inteiramente deriváveis do registo, mas uma conversão em produção não se
-- faz sem caminho de volta. Apagam-se quando o César disser.

-- ---------------------------------------------------------------------------
-- Índice que sustenta as vistas
-- ---------------------------------------------------------------------------
-- Sem isto cada leitura é uma varredura do registo. Com 117 operações o Postgres
-- ignora-o e faz bem; passa a usá-lo quando crescer.
create index if not exists punho_operacoes_projeccao_idx
  on public.punho_operacoes (entidade, empresa_id, entidade_id, seq desc);

-- ---------------------------------------------------------------------------
-- A chave estrangeira que impedia a conversão
-- ---------------------------------------------------------------------------
-- `punho_membros.colaborador_id` apontava para `punho_colaboradores.id`, e uma
-- vista não pode ser alvo de chave estrangeira. A promessa — "se está ligado a
-- uma ficha, a ficha existe" — passa a gatilho. Mesma garantia, sem a cópia.
alter table public.punho_membros
  drop constraint if exists punho_membros_colaborador_id_fkey;

create or replace function public.punho_membro_ficha_existe()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.colaborador_id is null then
    return new;
  end if;
  if not exists (
    select 1 from public.punho_operacoes o
    where o.entidade = 'collaborator'
      and o.empresa_id = new.empresa_id
      and public.punho_id_estavel(o.empresa_id, o.entidade_id) = new.colaborador_id
  ) then
    raise exception 'A ficha de empregado nao existe nesta empresa.';
  end if;
  return new;
end;
$fn$;

drop trigger if exists punho_membros_ficha_existe on public.punho_membros;
create trigger punho_membros_ficha_existe
  before insert or update of colaborador_id on public.punho_membros
  for each row execute function public.punho_membro_ficha_existe();

-- ---------------------------------------------------------------------------
-- Arrumar as tabelas antigas
-- ---------------------------------------------------------------------------
alter table if exists public.punho_clientes      rename to punho_clientes_copia_2026_08_09;
alter table if exists public.punho_maquinas      rename to punho_maquinas_copia_2026_08_09;
alter table if exists public.punho_leads         rename to punho_leads_copia_2026_08_09;
alter table if exists public.punho_colaboradores rename to punho_colaboradores_copia_2026_08_09;
alter table if exists public.punho_recebimentos  rename to punho_recebimentos_copia_2026_08_09;
alter table if exists public.punho_despesas      rename to punho_despesas_copia_2026_08_09;
alter table if exists public.punho_veiculos      rename to punho_veiculos_copia_2026_08_09;

-- As cópias não são para ninguém ler. Ficam só como rede.
revoke all on public.punho_clientes_copia_2026_08_09      from anon, authenticated;
revoke all on public.punho_maquinas_copia_2026_08_09      from anon, authenticated;
revoke all on public.punho_leads_copia_2026_08_09         from anon, authenticated;
revoke all on public.punho_colaboradores_copia_2026_08_09 from anon, authenticated;
revoke all on public.punho_recebimentos_copia_2026_08_09  from anon, authenticated;
revoke all on public.punho_despesas_copia_2026_08_09      from anon, authenticated;
revoke all on public.punho_veiculos_copia_2026_08_09      from anon, authenticated;

-- ---------------------------------------------------------------------------
-- As vistas
-- ---------------------------------------------------------------------------
-- Colunas iguais às das tabelas que substituem, para as apps não mudarem uma
-- linha. `created_at` é o instante da primeira operação da entidade e
-- `revision` o número de operações — derivados, e agora sempre certos, porque
-- se contam no momento da leitura.

create view public.punho_clientes
with (security_invoker = true) as
with ult as (
  select o.empresa_id, o.entidade_id, o.payload, o.feito_em, o.seq,
         row_number() over (partition by o.empresa_id, o.entidade_id order by o.seq desc) as rn,
         min(o.feito_em) over (partition by o.empresa_id, o.entidade_id) as nasceu_em,
         count(*)       over (partition by o.empresa_id, o.entidade_id) as revisoes,
         first_value(o.por_utilizador) over (
           partition by o.empresa_id, o.entidade_id order by o.seq) as autor
  from public.punho_operacoes o
  where o.entidade = 'customer'
)
select public.punho_id_estavel(empresa_id, entidade_id) as id,
       empresa_id,
       coalesce(payload->>'name', '')  as nome,
       nullif(payload->>'phone', '')   as telemovel,
       nullif(payload->>'taxId', '')   as nif,
       autor       as created_by,
       feito_em    as updated_at,
       nasceu_em   as created_at,
       revisoes::int as revision,
       payload     as dados,
       entidade_id as id_local
from ult where rn = 1;

-- As restantes têm todas a mesma forma: só `dados`.
do $blk$
declare
  v record;
begin
  for v in
    select * from (values
      ('punho_maquinas',      'machine'),
      ('punho_leads',         'lead'),
      ('punho_colaboradores', 'collaborator'),
      ('punho_recebimentos',  'receipt'),
      ('punho_despesas',      'expense'),
      ('punho_veiculos',      'vehicle')
    ) as t(vista, entidade)
  loop
    execute format($sql$
      create view public.%I
      with (security_invoker = true) as
      with ult as (
        select o.empresa_id, o.entidade_id, o.payload, o.feito_em, o.seq,
               row_number() over (partition by o.empresa_id, o.entidade_id order by o.seq desc) as rn,
               min(o.feito_em) over (partition by o.empresa_id, o.entidade_id) as nasceu_em,
               count(*)       over (partition by o.empresa_id, o.entidade_id) as revisoes,
               first_value(o.por_utilizador) over (
                 partition by o.empresa_id, o.entidade_id order by o.seq) as autor
        from public.punho_operacoes o
        where o.entidade = %L
      )
      select public.punho_id_estavel(empresa_id, entidade_id) as id,
             empresa_id,
             autor         as created_by,
             feito_em      as updated_at,
             nasceu_em     as created_at,
             revisoes::int as revision,
             payload       as dados,
             entidade_id   as id_local
      from ult where rn = 1
    $sql$, v.vista, v.entidade);

    execute format('grant select on public.%I to authenticated', v.vista);
  end loop;
end;
$blk$;

grant select on public.punho_clientes to authenticated;

comment on view public.punho_clientes is
  'Vista sobre punho_operacoes. Nao e uma copia: nao pode divergir do registo.';
comment on view public.punho_colaboradores is
  'Vista sobre punho_operacoes. So gestor le — quem o garante e o RLS do registo.';

-- ---------------------------------------------------------------------------
-- O projector deixa de escrever o que já não é tabela
-- ---------------------------------------------------------------------------
-- Sem isto a migração parte a app inteira: `punho_projectar_entidade` fazia
-- `insert into punho_clientes`, que agora é uma vista sem gatilho INSTEAD OF —
-- e o erro sobe pelo gatilho AFTER INSERT até rejeitar a escrita no registo.
-- Ou seja, o operador deixava de conseguir gravar seja o que for.
--
-- Fica só `booking`, que continua tabela. Tudo o resto passa a ler-se do
-- registo directamente, e não há nada para projectar.
create or replace function public.punho_projectar_entidade(
  p_empresa   uuid,
  p_entidade  text,
  p_id_local  text,
  p_dados     jsonb,
  p_quando    timestamptz,
  p_por       uuid
) returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid := punho_id_estavel(p_empresa, p_id_local);
begin
  if p_entidade <> 'booking' then
    return;  -- lê-se do registo; não há cópia para manter
  end if;

  insert into punho_reservas (
    id, empresa_id, id_local, cliente_id, colaborador_responsavel_id,
    cliente_nome_snapshot, colaborador_nome_snapshot,
    inicio, fim, estado, valor_previsto_centimos,
    created_by, dados, updated_at
  )
  values (
    v_id, p_empresa, p_id_local,
    punho_id_estavel(p_empresa, p_dados->>'customerId'),
    case
      when nullif(p_dados->>'collaboratorResponsibleId', '') is null then null
      else punho_id_estavel(p_empresa, p_dados->>'collaboratorResponsibleId')
    end,
    coalesce(p_dados->>'customerNameSnapshot', ''),
    nullif(p_dados->>'collaboratorNameSnapshot', ''),
    (p_dados->>'startsAt')::timestamptz,
    (p_dados->>'endsAt')::timestamptz,
    coalesce(p_dados->>'status', 'request'),
    nullif(p_dados->>'expectedValueCents', '')::int,
    p_por, p_dados, p_quando
  )
  on conflict (id) do update
    set cliente_id = excluded.cliente_id,
        colaborador_responsavel_id = excluded.colaborador_responsavel_id,
        cliente_nome_snapshot = excluded.cliente_nome_snapshot,
        colaborador_nome_snapshot = excluded.colaborador_nome_snapshot,
        inicio = excluded.inicio,
        fim = excluded.fim,
        estado = excluded.estado,
        valor_previsto_centimos = excluded.valor_previsto_centimos,
        dados = excluded.dados,
        id_local = excluded.id_local,
        updated_at = excluded.updated_at,
        revision = punho_reservas.revision + 1
    where punho_reservas.dados is distinct from excluded.dados;

  delete from punho_reserva_maquinas where reserva_id = v_id;
  insert into punho_reserva_maquinas (reserva_id, maquina_id)
  select v_id, punho_id_estavel(p_empresa, m)
  from jsonb_array_elements_text(
    case jsonb_typeof(p_dados->'machineIds')
      when 'array' then p_dados->'machineIds'
      else '[]'::jsonb
    end
  ) as m
  on conflict do nothing;
end;
$fn$;

revoke all on function public.punho_projectar_entidade(uuid, text, text, jsonb, timestamptz, uuid)
  from public, anon, authenticated;
