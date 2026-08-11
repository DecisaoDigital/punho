-- Uma pessoa pede para ser apagada. Hoje não há resposta.
--
-- ## O que existe e o que não existe
--
-- As únicas funções de apagar que a base tem — `apagar_licenca`,
-- `apagar_pedido_acesso`, `punho_apagar_pedido` — são operações de admin sobre
-- registos de negócio. Nenhuma delas responde a «apaguem os meus dados».
--
-- E os dados pessoais não estão numa tabela onde se possa fazer `delete`. Estão
-- dentro do log:
--
--   customer      name, taxId, phone, email, address, locality, postalCode, notes
--   collaborator  name, taxId, phone, socialSecurityNumber, maritalStatus,
--                 dependents, notes
--   lead          name, phone, summary
--
-- Pior: o nome do cliente e do colaborador é **copiado** para dentro de cada
-- reserva (`customerNameSnapshot`, `collaboratorNameSnapshot`), no log e na
-- tabela projectada. Apagar o cliente e deixar as reservas era apagar o nome de
-- um sítio e deixá-lo escrito noutros trinta.
--
-- ## Porquê redigir e não apagar
--
-- O log é append-only e é ele que re-hidrata os terminais. Apagar linhas abria
-- buracos no `seq`, deixava `punho_reservas.cliente_id` a apontar para alguém
-- que já não existe, e não deixava prova nenhuma de que o apagamento aconteceu
-- — que é justamente o que é preciso mostrar a quem o pediu.
--
-- Por isso a linha fica e o conteúdo sai: `name` passa a «Titular apagado», o
-- resto a `null`, e carimba-se `_apagado_em`. O `seq` mantém-se, a projecção
-- mantém-se, e fica registo em `punho_apagamentos`.
--
-- Não se toca em dinheiro nem em datas: `amountCents`, `expectedValueCents`,
-- `startsAt`, `endsAt` ficam como estavam. O que era obrigação fiscal continua
-- a ser obrigação fiscal — o que se apaga é quem, não quanto.
--
-- ## Quem pode chamar
--
-- O gestor, e só na empresa da sua sessão. A empresa **não** é parâmetro: sai
-- de `punho_empresa_atual()`. Quem chama diz quem apagar, não diz de onde.

create table if not exists punho_apagamentos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references punho_empresas(id) on delete cascade,
  entidade text not null check (entidade in ('customer', 'collaborator', 'lead')),
  entidade_id text not null,
  motivo text,
  operacoes_redigidas integer not null default 0,
  reservas_redigidas integer not null default 0,
  pedido_por uuid,
  feito_em timestamptz not null default now()
);

comment on table punho_apagamentos is
  'Prova de que um titular foi apagado: quem, quando, e quantas linhas mudaram. '
  'Não guarda dados pessoais — só o id local da entidade, que já não diz nada '
  'a ninguém depois da redacção.';

create index if not exists punho_apagamentos_empresa_idx
  on punho_apagamentos (empresa_id, feito_em desc);

alter table punho_apagamentos enable row level security;

-- O gestor lê os apagamentos da sua empresa. Ninguém escreve por fora: quem
-- escreve é a função, e é isso que faz da tabela uma prova e não um bloco de
-- notas.
drop policy if exists punho_apagamentos_gestor_le on punho_apagamentos;
create policy punho_apagamentos_gestor_le on punho_apagamentos
  for select to authenticated
  using (empresa_id = punho_empresa_atual() and punho_e_gestor());

create or replace function punho_apagar_titular(
  p_entidade text,
  p_entidade_id text,
  p_motivo text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_empresa uuid;
  v_id_estavel uuid;
  v_ops integer := 0;
  v_no_log integer := 0;
  v_projectadas integer := 0;
  v_marca constant text := 'Titular apagado';
  v_hoje constant text := to_char(now(), 'YYYY-MM-DD');
begin
  if not punho_e_gestor() then
    raise exception 'punho: só o gestor da empresa pode apagar um titular'
      using errcode = '42501';
  end if;

  v_empresa := punho_empresa_atual();
  if v_empresa is null then
    raise exception 'punho: esta sessão não está ligada a nenhuma empresa'
      using errcode = '42501';
  end if;

  if p_entidade is null or p_entidade not in ('customer', 'collaborator', 'lead') then
    raise exception
      'punho: apaga-se uma pessoa (customer, collaborator, lead), não %', p_entidade
      using errcode = '22023';
  end if;

  if p_entidade_id is null or length(trim(p_entidade_id)) = 0 then
    raise exception 'punho: falta dizer quem' using errcode = '22023';
  end if;

  -- 1. O titular, em todas as revisões que dele existem no log.
  update punho_operacoes o
     set payload = case p_entidade
       when 'customer' then o.payload || jsonb_build_object(
         'name', v_marca, 'taxId', null, 'phone', null, 'email', null,
         'address', null, 'locality', null, 'postalCode', null, 'notes', null,
         '_apagado_em', v_hoje)
       when 'collaborator' then o.payload || jsonb_build_object(
         'name', v_marca, 'taxId', null, 'phone', null,
         'socialSecurityNumber', null, 'maritalStatus', null,
         'dependents', null, 'notes', null,
         '_apagado_em', v_hoje)
       else o.payload || jsonb_build_object(
         'name', v_marca, 'phone', null, 'summary', null,
         '_apagado_em', v_hoje)
     end
   where o.empresa_id = v_empresa
     and o.entidade = p_entidade
     and o.entidade_id = p_entidade_id;
  get diagnostics v_ops = row_count;

  if v_ops = 0 then
    raise exception 'punho: não há nenhum % com o id % nesta empresa',
      p_entidade, p_entidade_id
      using errcode = 'P0002';
  end if;

  -- 2. O nome que ficou copiado para dentro das reservas, no log.
  if p_entidade = 'customer' then
    update punho_operacoes o
       set payload = o.payload || jsonb_build_object('customerNameSnapshot', v_marca)
     where o.empresa_id = v_empresa
       and o.entidade = 'booking'
       and o.payload->>'customerId' = p_entidade_id
       and coalesce(o.payload->>'customerNameSnapshot', '') <> v_marca;
    get diagnostics v_no_log = row_count;
  elsif p_entidade = 'collaborator' then
    update punho_operacoes o
       set payload = o.payload || jsonb_build_object('collaboratorNameSnapshot', v_marca)
     where o.empresa_id = v_empresa
       and o.entidade = 'booking'
       and o.payload->>'collaboratorResponsibleId' = p_entidade_id
       and coalesce(o.payload->>'collaboratorNameSnapshot', '') <> v_marca;
    get diagnostics v_no_log = row_count;
  end if;

  -- 3. O mesmo nome, na tabela projectada — que é a que a app lê.
  v_id_estavel := punho_id_estavel(v_empresa, p_entidade_id);

  if p_entidade = 'customer' then
    update punho_reservas
       set cliente_nome_snapshot = v_marca
     where empresa_id = v_empresa
       and cliente_id = v_id_estavel
       and coalesce(cliente_nome_snapshot, '') <> v_marca;
    get diagnostics v_projectadas = row_count;
  elsif p_entidade = 'collaborator' then
    update punho_reservas
       set colaborador_nome_snapshot = v_marca
     where empresa_id = v_empresa
       and colaborador_responsavel_id = v_id_estavel
       and coalesce(colaborador_nome_snapshot, '') <> v_marca;
    get diagnostics v_projectadas = row_count;
  end if;

  insert into punho_apagamentos (
    empresa_id, entidade, entidade_id, motivo,
    operacoes_redigidas, reservas_redigidas, pedido_por
  ) values (
    v_empresa, p_entidade, p_entidade_id, nullif(trim(coalesce(p_motivo, '')), ''),
    v_ops + v_no_log, v_projectadas, auth.uid()
  );

  return jsonb_build_object(
    'ok', true,
    'entidade', p_entidade,
    'operacoes_redigidas', v_ops,
    'reservas_no_log_redigidas', v_no_log,
    'reservas_projectadas_redigidas', v_projectadas,
    'apagado_em', v_hoje
  );
end;
$$;

comment on function punho_apagar_titular(text, text, text) is
  'Direito ao apagamento (RGPD art. 17.º). Redige o titular no log e nos nomes '
  'copiados para as reservas. Empresa vem da sessão, nunca do chamador.';

revoke all on function punho_apagar_titular(text, text, text) from public;
revoke all on function punho_apagar_titular(text, text, text) from anon;
grant execute on function punho_apagar_titular(text, text, text) to authenticated;
