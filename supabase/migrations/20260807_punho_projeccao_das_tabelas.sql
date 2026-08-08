-- =============================================================================
-- As tabelas a sério passam a ter linhas.
-- =============================================================================
--
-- O PROBLEMA
-- ----------
-- `punho_clientes`, `punho_maquinas`, `punho_reservas`, `punho_leads`,
-- `punho_recebimentos`, `punho_despesas`, `punho_veiculos` e
-- `punho_colaboradores` existem desde `20260725_punho_core.sql` e estão todas a
-- zero. O estado real da empresa vive em dois sítios que ninguém consegue
-- consultar sem ser a app inteira: `punho_operacoes` (o registo de alterações,
-- que é preciso dobrar do princípio) e `punho_estado_operacional` (a ficha
-- toda num único jsonb).
--
-- Isso chegava enquanto o único leitor era o Punho, que carrega tudo para
-- memória. Deixa de chegar com a app do operador: ela não guarda nada no
-- aparelho, por isso tem de perguntar ao servidor "quais são as máquinas e
-- quais estão livres?" — e hoje não há ninguém a quem perguntar.
--
-- O QUE ISTO FAZ
-- --------------
-- Quem escreve continua a ser quem escrevia. O servidor é que passa a projectar
-- cada escrita para a tabela respectiva, por gatilho, nos dois canais:
--
--   punho_operacoes           (uma linha por alteração)  ─┐
--                                                         ├─→ tabelas
--   punho_estado_operacional  (a ficha inteira)          ─┘
--
-- A app não foi mexida. Escrever duas vezes a partir do telemóvel — uma para o
-- registo, outra para a tabela — era a alternativa, e é pior: sem rede as duas
-- metades separam-se, uma sobe e a outra não, e ficam duas versões do mesmo
-- cliente sem forma de saber qual é a boa. Assim há uma escrita só, e a segunda
-- acontece dentro da mesma transacção, no servidor.
--
-- Daqui em diante: **o registo manda, as tabelas são a sua leitura.** Ninguém
-- escreve nelas directamente — as políticas abaixo só dão SELECT. Uma escrita
-- directa numa tabela nunca chegaria ao registo, e o gestor nunca a veria.
--
-- SE A PROJECÇÃO FALHAR, A ESCRITA FALHA
-- --------------------------------------
-- De propósito. Uma projecção que engolisse o erro deixava as tabelas caladas e
-- erradas, e quem as lesse — o operador, em obra — decidia com base numa
-- empresa que não existe. Mais vale a sincronização dar erro à vista.
--
-- A única coisa que não rebenta é uma `entidade` desconhecida: fica por
-- projectar, sem erro. É a mesma escolha que a app já faz em
-- `aplicarOperacaoRemota` — uma versão antiga não pode partir por a outra ponta
-- ter aprendido uma palavra nova.

-- -----------------------------------------------------------------------------
-- 1. A ponte entre os dois mundos de identificadores
-- -----------------------------------------------------------------------------
--
-- A app gera ids como `m1785969714554173` (letra + milissegundos). As tabelas
-- têm chaves `uuid`. Em vez de guardar uma tabela de correspondências — que é
-- mais uma coisa que pode ficar dessincronizada —, o uuid **deriva** do id
-- local: mesma empresa e mesmo id local dão sempre o mesmo uuid.
--
-- É o que torna a projecção repetível. Projectar a mesma operação duas vezes dá
-- exactamente a mesma linha, e uma reserva consegue apontar para o cliente sem
-- ter de o procurar primeiro.
create or replace function public.punho_id_estavel(
  p_empresa uuid,
  p_id_local text
) returns uuid
language sql
immutable
strict
set search_path = public
as $$
  select md5(p_empresa::text || ':' || p_id_local)::uuid
$$;

comment on function public.punho_id_estavel(uuid, text) is
  'uuid derivado do id local da app. Determinístico: a projecção pode correr '
  'as vezes que forem precisas sem duplicar nada.';

-- -----------------------------------------------------------------------------
-- 2. Pôr as tabelas na forma do que a app tem para guardar
-- -----------------------------------------------------------------------------

-- `dados` guarda o payload tal como a app o escreveu. As colunas com nome
-- próprio ao lado são para consultar e ordenar; nenhuma delas é a verdade — a
-- verdade é o `dados`, e as outras saem de lá.
alter table public.punho_clientes add column if not exists dados jsonb not null default '{}'::jsonb;
alter table public.punho_reservas add column if not exists dados jsonb not null default '{}'::jsonb;

-- O id local fica à vista. Sem isto, ler uma linha destas e ligá-la ao que a
-- app mostra obriga a inverter um md5, e não se inverte.
alter table public.punho_clientes      add column if not exists id_local text;
alter table public.punho_maquinas      add column if not exists id_local text;
alter table public.punho_reservas      add column if not exists id_local text;
alter table public.punho_leads         add column if not exists id_local text;
alter table public.punho_recebimentos  add column if not exists id_local text;
alter table public.punho_despesas      add column if not exists id_local text;
alter table public.punho_veiculos      add column if not exists id_local text;
alter table public.punho_colaboradores add column if not exists id_local text;

-- Dois clientes sem NIF e sem telemóvel são dois clientes, não um conflito.
-- `Customer.phone` é uma String não-anulável na app: quem não tiver telemóvel
-- fica com '' — e '' colide consigo próprio numa restrição de unicidade. O
-- segundo cliente assim desaparecia da projecção sem dizer nada.
alter table public.punho_clientes drop constraint if exists punho_clientes_empresa_id_nif_key;
alter table public.punho_clientes drop constraint if exists punho_clientes_empresa_id_telemovel_key;

-- As chaves estrangeiras entre entidades saem.
--
-- O registo de operações não promete ordem entre entidades: um telemóvel que
-- esteve sem rede sobe o lote todo de uma vez, e a reserva pode chegar antes do
-- cliente. Com chave estrangeira isso deixava de ser "a tabela fica um
-- instante incompleta" e passava a ser "o telemóvel não consegue sincronizar".
-- A ligação continua lá, na coluna e no índice; o que sai é a imposição.
alter table public.punho_reservas drop constraint if exists punho_reservas_cliente_id_fkey;
alter table public.punho_reservas drop constraint if exists punho_reservas_colaborador_responsavel_id_fkey;
alter table public.punho_reserva_maquinas drop constraint if exists punho_reserva_maquinas_reserva_id_fkey;
alter table public.punho_reserva_maquinas drop constraint if exists punho_reserva_maquinas_maquina_id_fkey;

-- `colaborador_responsavel_id` passa a apontar para `punho_colaboradores` e não
-- para `punho_membros`. É o que o nome diz e é o que a app tem: o
-- `collaboratorResponsibleId` de uma reserva é o colaborador do negócio, que
-- pode nem ter conta para entrar na app.
comment on column public.punho_reservas.colaborador_responsavel_id is
  'punho_colaboradores.id (derivado do id local). Não é punho_membros.';

-- -----------------------------------------------------------------------------
-- 3. A projecção
-- -----------------------------------------------------------------------------
--
-- Uma entidade, um payload, uma linha. Chamada pelos dois gatilhos e pela
-- reconstrução — daí ser função e não corpo de gatilho.
--
-- Cada `on conflict` só toca na linha **se o conteúdo mudou**. A ficha inteira
-- volta a passar por aqui a cada gravação do gestor, e sem esta condição todas
-- as linhas ficavam com `updated_at` novo a cada vez — o que dava pelo caminho
-- cabo de qualquer leitura incremental por data.
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
as $$
declare
  v_id uuid := punho_id_estavel(p_empresa, p_id_local);
begin
  case p_entidade

  when 'machine' then
    insert into punho_maquinas (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_maquinas.revision + 1
      where punho_maquinas.dados is distinct from excluded.dados;

  when 'customer' then
    insert into punho_clientes (
      id, empresa_id, id_local, created_by, nome, telemovel, nif, dados, updated_at
    )
    values (
      v_id, p_empresa, p_id_local, p_por,
      coalesce(p_dados->>'name', ''),
      nullif(p_dados->>'phone', ''),
      nullif(p_dados->>'taxId', ''),
      p_dados, p_quando
    )
    on conflict (id) do update
      set nome = excluded.nome,
          telemovel = excluded.telemovel,
          nif = excluded.nif,
          dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_clientes.revision + 1
      where punho_clientes.dados is distinct from excluded.dados;

  when 'booking' then
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

    -- As máquinas da reserva são uma lista dentro do payload. Reescrita
    -- inteira: uma máquina retirada da reserva tem de sair daqui, e comparar
    -- item a item para poupar duas linhas não paga o risco de deixar lá uma.
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

  when 'lead' then
    insert into punho_leads (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_leads.revision + 1
      where punho_leads.dados is distinct from excluded.dados;

  when 'receipt' then
    insert into punho_recebimentos (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_recebimentos.revision + 1
      where punho_recebimentos.dados is distinct from excluded.dados;

  when 'expense' then
    insert into punho_despesas (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_despesas.revision + 1
      where punho_despesas.dados is distinct from excluded.dados;

  when 'vehicle' then
    insert into punho_veiculos (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_veiculos.revision + 1
      where punho_veiculos.dados is distinct from excluded.dados;

  when 'collaborator' then
    insert into punho_colaboradores (id, empresa_id, id_local, created_by, dados, updated_at)
    values (v_id, p_empresa, p_id_local, p_por, p_dados, p_quando)
    on conflict (id) do update
      set dados = excluded.dados,
          id_local = excluded.id_local,
          updated_at = excluded.updated_at,
          revision = punho_colaboradores.revision + 1
      where punho_colaboradores.dados is distinct from excluded.dados;

  else
    -- Entidade que esta versão da base de dados ainda não conhece. Fica por
    -- projectar e não parte nada: o registo de operações tem-na na mesma, e a
    -- reconstrução apanha-a assim que houver uma coluna onde a pôr.
    null;

  end case;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Gatilho no canal das operações
-- -----------------------------------------------------------------------------
create or replace function public.punho_operacoes_projectar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform punho_projectar_entidade(
    new.empresa_id, new.entidade, new.entidade_id,
    new.payload, new.feito_em, new.por_utilizador
  );
  return new;
end;
$$;

drop trigger if exists punho_operacoes_projectar on public.punho_operacoes;
create trigger punho_operacoes_projectar
  after insert on public.punho_operacoes
  for each row execute function public.punho_operacoes_projectar();

-- -----------------------------------------------------------------------------
-- 5. Gatilho no canal do instantâneo
-- -----------------------------------------------------------------------------
--
-- O instantâneo do gestor traz a ficha inteira, incluindo as entidades. Sem
-- este gatilho, um gestor que só gravasse por aí deixava as tabelas paradas —
-- e é precisamente o caminho pelo qual passa a primeira gravação de uma
-- empresa nova.
create or replace function public.punho_projectar_ficha(
  p_empresa uuid,
  p_payload jsonb,
  p_quando  timestamptz
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lista  record;
  v_item   jsonb;
begin
  for v_lista in
    select * from (values
      ('machines',      'machine'),
      ('customers',     'customer'),
      ('bookings',      'booking'),
      ('leads',         'lead'),
      ('receipts',      'receipt'),
      ('expenses',      'expense'),
      ('vehicles',      'vehicle'),
      ('collaborators', 'collaborator')
    ) as t(chave, entidade)
  loop
    if jsonb_typeof(p_payload->v_lista.chave) <> 'array' then
      continue;
    end if;
    for v_item in select * from jsonb_array_elements(p_payload->v_lista.chave)
    loop
      -- Sem id não há linha. Um item destes é um item corrompido, e inventar-lhe
      -- um id era criar do nada uma entidade que ninguém escreveu.
      continue when nullif(v_item->>'id', '') is null;
      perform punho_projectar_entidade(
        p_empresa, v_lista.entidade, v_item->>'id', v_item, p_quando, null
      );
    end loop;
  end loop;
end;
$$;

create or replace function public.punho_estado_operacional_projectar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform punho_projectar_ficha(new.empresa_id, new.payload, now());
  return new;
end;
$$;

drop trigger if exists punho_estado_operacional_projectar on public.punho_estado_operacional;
create trigger punho_estado_operacional_projectar
  after insert or update on public.punho_estado_operacional
  for each row execute function public.punho_estado_operacional_projectar();

-- -----------------------------------------------------------------------------
-- 6. Reconstruir do zero
-- -----------------------------------------------------------------------------
--
-- Rede de segurança: se alguma vez as tabelas ficarem atrás do registo — versão
-- nova com uma entidade que a antiga não sabia projectar, por exemplo —, isto
-- volta a passar tudo. Instantâneo primeiro, operações por cima, que é a ordem
-- em que aconteceram.
create or replace function public.punho_reprojectar_empresa(p_empresa uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_op    record;
  v_conta integer := 0;
begin
  perform punho_projectar_ficha(e.empresa_id, e.payload, e.updated_at)
  from punho_estado_operacional e
  where e.empresa_id = p_empresa;

  for v_op in
    select empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador
    from punho_operacoes
    where empresa_id = p_empresa
    order by seq
  loop
    perform punho_projectar_entidade(
      v_op.empresa_id, v_op.entidade, v_op.entidade_id,
      v_op.payload, v_op.feito_em, v_op.por_utilizador
    );
    v_conta := v_conta + 1;
  end loop;

  return v_conta;
end;
$$;

-- -----------------------------------------------------------------------------
-- 7. Índices para o que o operador pergunta
-- -----------------------------------------------------------------------------
create index if not exists punho_maquinas_empresa_idx      on public.punho_maquinas (empresa_id);
create index if not exists punho_clientes_empresa_idx      on public.punho_clientes (empresa_id);
create index if not exists punho_leads_empresa_idx         on public.punho_leads (empresa_id);
create index if not exists punho_recebimentos_empresa_idx  on public.punho_recebimentos (empresa_id);
create index if not exists punho_despesas_empresa_idx      on public.punho_despesas (empresa_id);
create index if not exists punho_veiculos_empresa_idx      on public.punho_veiculos (empresa_id);
create index if not exists punho_colaboradores_empresa_idx on public.punho_colaboradores (empresa_id);

-- "O que tenho para entregar e recolher hoje" é a primeira pergunta do
-- separador Hoje, e é sempre por empresa e por data.
create index if not exists punho_reservas_empresa_inicio_idx on public.punho_reservas (empresa_id, inicio);
create index if not exists punho_reservas_empresa_fim_idx    on public.punho_reservas (empresa_id, fim);
create index if not exists punho_reservas_empresa_estado_idx on public.punho_reservas (empresa_id, estado);
create index if not exists punho_reserva_maquinas_maquina_idx on public.punho_reserva_maquinas (maquina_id);

-- -----------------------------------------------------------------------------
-- 8. Quem lê o quê
-- -----------------------------------------------------------------------------
--
-- Estas tabelas são **só de leitura** para toda a gente. Não há política de
-- INSERT, UPDATE ou DELETE em nenhuma delas, e sem política o Postgres recusa —
-- que é o que se quer: uma escrita directa aqui não passava pelo registo, e o
-- gestor nunca a via aparecer no telemóvel dele. Quem quer escrever escreve em
-- `punho_operacoes`, e a linha aparece aqui por si.
--
-- As políticas antigas eram `ALL` e davam escrita a qualquer membro. Saem.

drop policy if exists "membros empresa"  on public.punho_clientes;
drop policy if exists "empresa_membros"  on public.punho_maquinas;
drop policy if exists "reservas empresa" on public.punho_reservas;
drop policy if exists "empresa_membros"  on public.punho_leads;
drop policy if exists "empresa_membros"  on public.punho_recebimentos;
drop policy if exists "empresa_membros"  on public.punho_veiculos;
drop policy if exists "empresa_membros"  on public.punho_colaboradores;
drop policy if exists "empresa_gestor"   on public.punho_despesas;
drop policy if exists "gestor despesas"  on public.punho_despesas;
drop policy if exists "membros gerem maquinas nas reservas da empresa" on public.punho_reserva_maquinas;

-- O que o colaborador vê: clientes, máquinas (todas, com disponibilidade),
-- reservas, leads e recebimentos. É o que ele precisa para receber um pedido,
-- reservar, entregar, recolher e aceitar pagamento.
create policy "empresa le" on public.punho_clientes
  for select using (empresa_id = punho_empresa_atual() and punho_membro_ativo());
create policy "empresa le" on public.punho_maquinas
  for select using (empresa_id = punho_empresa_atual() and punho_membro_ativo());
create policy "empresa le" on public.punho_reservas
  for select using (empresa_id = punho_empresa_atual() and punho_membro_ativo());
create policy "empresa le" on public.punho_leads
  for select using (empresa_id = punho_empresa_atual() and punho_membro_ativo());
create policy "empresa le" on public.punho_recebimentos
  for select using (empresa_id = punho_empresa_atual() and punho_membro_ativo());
create policy "empresa le" on public.punho_reserva_maquinas
  for select using (exists (
    select 1 from punho_reservas r
    where r.id = punho_reserva_maquinas.reserva_id
      and r.empresa_id = punho_empresa_atual()
  ) and punho_membro_ativo());

-- O que só o gestor vê. Despesas e veículos são custo, e a folha de
-- colaboradores é do negócio, não da obra — nada disto é do operador.
create policy "gestor le" on public.punho_despesas
  for select using (empresa_id = punho_empresa_atual() and punho_e_gestor());
create policy "gestor le" on public.punho_veiculos
  for select using (empresa_id = punho_empresa_atual() and punho_e_gestor());
create policy "gestor le" on public.punho_colaboradores
  for select using (empresa_id = punho_empresa_atual() and punho_e_gestor());

-- -----------------------------------------------------------------------------
-- 9. Encher com o que já lá está
-- -----------------------------------------------------------------------------
do $$
declare
  v_empresa uuid;
begin
  for v_empresa in
    select id from punho_empresas
  loop
    perform punho_reprojectar_empresa(v_empresa);
  end loop;
end;
$$;
