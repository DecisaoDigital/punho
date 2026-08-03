-- =============================================================================
-- Seed de demonstração — empresa de ALUGUER DE MÁQUINAS (Punho)
-- =============================================================================
--
-- O QUE É ISTO
-- ------------
-- Semeia um mês de operação realista (máquinas, clientes, leads, reservas,
-- despesas e recebimentos) para uma empresa de aluguer de máquinas de
-- construção, para o dashboard nascer vivo numa demonstração em vez de vazio.
--
-- COMO OS DADOS CHEGAM À APP (mesmo mecanismo confirmado no seed
-- supabase/seeds/mare_alta.sql)
-- ----------------------------------------------------------------------------
-- A app não lê tabelas "materializadas" — lê exclusivamente `punho_operacoes`
-- (append-only: cada linha é uma alteração a uma entidade, identificada por
-- `entidade` + `entidade_id`, com o estado completo em `payload` jsonb) e cada
-- dispositivo faz pull das linhas com `por_dispositivo` diferente do seu.
-- Este script escreve só nessa tabela, com o payload no formato EXACTO que a
-- app produz — as chaves foram copiadas literalmente dos métodos
-- `_machineToJson`, `_customerToJson`, `_leadToJson`, `_bookingToJson`,
-- `_expenseToJson` e `_receiptToJson` em
-- lib/data/repositories/operation_repository.dart, e os valores de enum
-- (estados, categorias, métodos de pagamento) de
-- lib/domain/models/operations.dart e lib/domain/models/finance.dart.
--
-- Chaves usadas por entidade (confirmado contra o código, não parafraseado):
--   machine  : id, name, reference, category, status, dailyRateCents,
--              acquiredOn, purchasePriceCents, notes, photoPaths, archived
--   customer : id, name, phone, taxId, email, address, postalCode, locality,
--              notes, companyId, archived
--   lead     : id, name, phone, status, source, createdAt, summary,
--              collaboratorResponsibleId
--   booking  : id, customerId, machineIds, startsAt, endsAt, status,
--              expectedValueCents, collaboratorResponsibleId, companyId,
--              customerNameSnapshot, collaboratorNameSnapshot, notes
--   expense  : id, date, amountCents, category, status, note, description,
--              machineId, vehicleId, documentPath, recordedByCollaboratorId,
--              dataSource, archived
--   receipt  : id, date, amountCents, customerId, bookingId, method, note,
--              recordedByCollaboratorId, archived
--
-- Todas as 6 máquinas ficam com `dailyRateCents` E `purchasePriceCents`
-- preenchidos — sem isto o cartão de Utilização/Rentabilidade não acende.
--
-- O trigger `punho_operacoes_payload_coerente` (migração
-- 20260803_punho_validar_payload_operacoes.sql) rejeita reservas com
-- endsAt <= startsAt e qualquer amountCents/dailyRateCents/
-- purchasePriceCents/expectedValueCents negativo. Todos os valores aqui
-- respeitam isso (nunca negativos, todas as reservas com endsAt > startsAt).
--
-- DATAS RELATIVAS A now()
-- ------------------------
-- Para os números fazerem sempre sentido, independentemente de quando este
-- script for corrido, as datas não são literais fixos: são calculadas a
-- partir de duas variáveis definidas uma vez no início do bloco `do $$`:
--   v_agora : o instante exacto de execução (timestamptz = now())
--   v_hoje  : a meia-noite UTC do dia de execução (timestamp, sem fuso,
--             já convertido para UTC — serve de base para os deslocamentos
--             "há N dias, às H horas")
-- Duas famílias de expressão são usadas em todo o ficheiro:
--   Padrão A (dia + hora do dia): v_hoje + interval '<N> days' + interval '<HH:MI:SS>'
--   Padrão B (deslocamento em horas a partir de agora, para os casos que
--             têm de cair dentro de uma janela precisa como "próximas 48h"):
--             v_agora + interval '<N> hours'
-- Em ambos os casos formata-se para texto ISO 8601 UTC com "Z" via:
--   to_char(<expressão> at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
-- (nota: `v_hoje` já é timestamp sem fuso em UTC, por isso o "at time zone
-- 'utc'" aplicado sobre expressões com `v_hoje` é inofensivo/redundante mas
-- inofensivo; mantém-se por uniformidade de padrão em todas as expressões.)
--
-- Datas cobertas: últimos 30 dias (a mais antiga é "hoje menos 28 dias") até
-- alguns dias no futuro (a mais distante é "hoje mais 12 dias"), incluindo:
--   - 2 reservas ('rented') a terminar nas próximas 48h (reserva #10 e #12)
--   - 1 reserva ('rented') com recolha em atraso — endsAt já passado há 18h
--     mas o estado continua "rented" (reserva #9)
--   - 2 leads por contactar há mais de 5 dias (leads #5 e #6, estado 'newLead')
--
-- COMO SE CORRE
-- --------------
-- 1. Edita a variável `v_empresa` no bloco `do $$ declare ... begin` mais
--    abaixo, pondo lá o uuid real da empresa de demonstração
--    (punho_empresas.id). O script recusa-se a correr (raise exception) se
--    esse uuid não existir na tabela punho_empresas — não há forma de
--    esquecer de o mudar e semear dados órfãos.
-- 2. Opcional: define `v_utilizador` com o uuid de um gestor activo dessa
--    empresa (punho_membros.user_id) — serve só para preencher
--    `por_utilizador`, que é nullable; podes deixá-lo NULL sem problema.
-- 3. Corre com psql:
--      psql "$SUPABASE_DB_URL" -f scripts/semear_demonstracao.sql
--    ou cola o conteúdo no SQL Editor do Supabase.
-- 4. Correr o script outra vez não duplica nada: o bloco começa por apagar
--    tudo o que ele próprio tenha inserido antes para esta empresa
--    (por_dispositivo = 'semente-demonstracao'), antes de voltar a inserir.
--
-- COMO SE APAGA
-- --------------
-- Ver scripts/limpar_demonstracao.sql, ou directamente:
--   delete from public.punho_operacoes
--    where empresa_id = '<uuid da empresa>'
--      and por_dispositivo = 'semente-demonstracao';
--
-- NÃO VERIFICADO — LER ANTES DE APLICAR
-- ----------------------------------------------------------------------------
-- Este ficheiro foi escrito por leitura de código (operation_repository.dart,
-- operations.dart, finance.dart, e o trigger de validação), mas NUNCA foi
-- corrido contra uma base de dados real. Confirma num ambiente de teste antes
-- de usar em demonstração ao vivo.
--
-- =============================================================================

do $$
declare
  -- ---- EDITA AQUI ----------------------------------------------------------
  v_empresa    uuid := '37b847eb-de1c-4f29-820d-814e069806ee'; -- <-- põe aqui o punho_empresas.id da empresa de demonstração
  v_utilizador uuid := null;                                    -- opcional: punho_membros.user_id de um gestor activo desta empresa
  -- ---------------------------------------------------------------------------
  v_tag   text := 'semente-demonstracao'; -- marca todas as linhas deste seed, para idempotência e limpeza
  v_agora timestamptz := now();
  v_hoje  timestamp := date_trunc('day', v_agora at time zone 'utc');
begin
  if not exists (select 1 from public.punho_empresas where id = v_empresa) then
    raise exception 'punho: v_empresa (%) não existe em punho_empresas — edita a variável v_empresa no topo do script antes de correr', v_empresa;
  end if;

  -- Idempotência: remove primeiro tudo o que este seed tenha inserido antes
  -- para esta empresa, para que correr o ficheiro vezes seguidas não duplique
  -- nada (todas as entidades ficam com entidade_id prefixado 'demo-').
  delete from public.punho_operacoes
   where empresa_id = v_empresa
     and por_dispositivo = v_tag;

  -- ===========================================================================
  -- MÁQUINAS (6) — todas com dailyRateCents e purchasePriceCents preenchidos
  -- ===========================================================================

  -- Giratória: actualmente alugada (reserva #10, termina em breve)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-1', jsonb_build_object(
    'id', 'demo-maq-1', 'name', 'Giratória CAT 320', 'reference', 'GIR-320-01',
    'category', 'Escavação', 'status', 'rented',
    'dailyRateCents', 25000, 'acquiredOn', '2021-03-10T00:00:00Z',
    'purchasePriceCents', 8500000, 'notes', 'Giratória de 20 toneladas, lagartas',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Mini-escavadora: actualmente alugada, com recolha em atraso (reserva #9)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-2', jsonb_build_object(
    'id', 'demo-maq-2', 'name', 'Mini-escavadora Kubota U27', 'reference', 'MINI-U27-01',
    'category', 'Escavação', 'status', 'rented',
    'dailyRateCents', 9000, 'acquiredOn', '2023-06-01T00:00:00Z',
    'purchasePriceCents', 1800000, 'notes', 'Ideal para espaços confinados',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Martelo demolidor: disponível
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-3', jsonb_build_object(
    'id', 'demo-maq-3', 'name', 'Martelo Demolidor Hilti TE 3000', 'reference', 'MART-TE3000-01',
    'category', 'Demolição', 'status', 'available',
    'dailyRateCents', 4500, 'acquiredOn', '2024-01-15T00:00:00Z',
    'purchasePriceCents', 350000, 'notes', 'Uso manual, requer compressor próprio',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Placa compactadora: em manutenção (motor a reparar, ver despesa #3)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-4', jsonb_build_object(
    'id', 'demo-maq-4', 'name', 'Placa Compactadora Wacker Neuson', 'reference', 'PLAC-WN-01',
    'category', 'Compactação', 'status', 'maintenance',
    'dailyRateCents', 3500, 'acquiredOn', '2022-09-20T00:00:00Z',
    'purchasePriceCents', 220000, 'notes', 'Em reparação ao motor',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Gerador: reservado para obra futura (reserva #13)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-5', jsonb_build_object(
    'id', 'demo-maq-5', 'name', 'Gerador Himoinsa 20kVA', 'reference', 'GER-HIM20-01',
    'category', 'Energia', 'status', 'reserved',
    'dailyRateCents', 6000, 'acquiredOn', '2023-11-05T00:00:00Z',
    'purchasePriceCents', 950000, 'notes', 'Gerador insonorizado',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Plataforma elevatória: actualmente alugada, termina em breve (reserva #12)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'machine', 'demo-maq-6', jsonb_build_object(
    'id', 'demo-maq-6', 'name', 'Plataforma Elevatória Haulotte', 'reference', 'PLAT-HAU-01',
    'category', 'Elevação', 'status', 'rented',
    'dailyRateCents', 12000, 'acquiredOn', '2020-07-22T00:00:00Z',
    'purchasePriceCents', 2600000, 'notes', 'Altura máxima de trabalho 12 metros',
    'photoPaths', jsonb_build_array(), 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- ===========================================================================
  -- CLIENTES (8) — empresas de construção
  -- ===========================================================================

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-1', jsonb_build_object(
    'id', 'demo-cli-1', 'name', 'Construções Silva & Filhos, Lda', 'phone', '912000001',
    'taxId', '500001014', 'email', 'geral@silvaefilhos.pt', 'address', 'Rua das Obras, 12',
    'postalCode', '4700-000', 'locality', 'Braga', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-2', jsonb_build_object(
    'id', 'demo-cli-2', 'name', 'Obrantes — Construção Civil, Lda', 'phone', '913000002',
    'taxId', '500002029', 'email', 'geral@obrantes.pt', 'address', 'Avenida da Construção, 45',
    'postalCode', '4810-000', 'locality', 'Guimarães', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-3', jsonb_build_object(
    'id', 'demo-cli-3', 'name', 'Edifica Norte, Lda', 'phone', '914000003',
    'taxId', '500003033', 'email', 'geral@edificanorte.pt', 'address', 'Rua do Estaleiro, 8',
    'postalCode', '4760-000', 'locality', 'Vila Nova de Famalicão', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-4', jsonb_build_object(
    'id', 'demo-cli-4', 'name', 'Terraplanagens Costa, Unipessoal Lda', 'phone', '915000004',
    'taxId', '500004048', 'email', 'geral@terraplanagenscosta.pt', 'address', 'Estrada Nacional 14, km 3',
    'postalCode', '4750-000', 'locality', 'Barcelos', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-5', jsonb_build_object(
    'id', 'demo-cli-5', 'name', 'Grupo Vieira Construções, SA', 'phone', '916000005',
    'taxId', '500005052', 'email', 'geral@grupovieira.pt', 'address', 'Zona Industrial, Lote 22',
    'postalCode', '4770-000', 'locality', 'Vila Nova de Famalicão', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-6', jsonb_build_object(
    'id', 'demo-cli-6', 'name', 'Renovar Obras e Remodelações, Lda', 'phone', '917000006',
    'taxId', '500006067', 'email', 'geral@renovarobras.pt', 'address', 'Rua Nova da Estação, 3',
    'postalCode', '4830-000', 'locality', 'Póvoa de Lanhoso', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-7', jsonb_build_object(
    'id', 'demo-cli-7', 'name', 'Construtora Almeida & Pereira, Lda', 'phone', '918000007',
    'taxId', '500007071', 'email', 'geral@almeidapereira.pt', 'address', 'Rua do Progresso, 15',
    'postalCode', '4820-000', 'locality', 'Fafe', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', 'demo-cli-8', jsonb_build_object(
    'id', 'demo-cli-8', 'name', 'Infraestruturas do Minho, Lda', 'phone', '919000008',
    'taxId', '500008086', 'email', 'geral@infraestruturasminho.pt', 'address', 'Parque Empresarial do Minho, Lote 5',
    'postalCode', '4705-000', 'locality', 'Braga', 'notes', '', 'companyId', v_empresa::text,
    'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- ===========================================================================
  -- LEADS (7) — 2 convertidas, 1 em proposta, 1 contactada, 2 por contactar
  -- há mais de 5 dias, 1 perdida
  -- ===========================================================================

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-1', jsonb_build_object(
    'id', 'demo-lead-1', 'name', 'Hugo Martins', 'phone', '912345101',
    'status', 'converted', 'source', 'google',
    'createdAt', to_char((v_hoje + interval '-25 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Pediu orçamento para giratória; fechou contrato, tornou-se cliente (Terraplanagens Costa).',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-2', jsonb_build_object(
    'id', 'demo-lead-2', 'name', 'Marisa Coelho', 'phone', '913345102',
    'status', 'converted', 'source', 'referral',
    'createdAt', to_char((v_hoje + interval '-20 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Indicada por cliente actual; fechou aluguer mensal de mini-escavadora.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-3', jsonb_build_object(
    'id', 'demo-lead-3', 'name', 'André Sousa', 'phone', '914345103',
    'status', 'proposal', 'source', 'facebook',
    'createdAt', to_char((v_hoje + interval '-10 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Proposta enviada para aluguer mensal de plataforma elevatória; a aguardar resposta.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-4', jsonb_build_object(
    'id', 'demo-lead-4', 'name', 'Filipa Nogueira', 'phone', '915345104',
    'status', 'contacted', 'source', 'whatsapp',
    'createdAt', to_char((v_hoje + interval '-3 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Contactada por WhatsApp, à espera de confirmar datas.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  -- Por contactar há mais de 5 dias (dispara a recomendação de procura)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-5', jsonb_build_object(
    'id', 'demo-lead-5', 'name', 'Ricardo Tavares', 'phone', '916345105',
    'status', 'newLead', 'source', 'landingPage',
    'createdAt', to_char((v_hoje + interval '-8 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Pediu informação pelo site sobre aluguer de martelo demolidor; ainda por contactar.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  -- Por contactar há mais de 5 dias (dispara a recomendação de procura)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-6', jsonb_build_object(
    'id', 'demo-lead-6', 'name', 'Sandra Beato', 'phone', '917345106',
    'status', 'newLead', 'source', 'call',
    'createdAt', to_char((v_hoje + interval '-6 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Ligou a perguntar preços de compactadora; ainda por contactar.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'lead', 'demo-lead-7', jsonb_build_object(
    'id', 'demo-lead-7', 'name', 'Nuno Ferreira', 'phone', '918345107',
    'status', 'lost', 'source', 'agenda',
    'createdAt', to_char((v_hoje + interval '-2 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'summary', 'Achou o preço alto e desistiu.',
    'collaboratorResponsibleId', null
  ), v_agora, v_utilizador, v_tag);

  -- ===========================================================================
  -- RESERVAS (14) — 8 completed, 3 rented (2 a terminar em 48h, 1 em atraso),
  -- 3 confirmed no futuro
  -- ===========================================================================

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-1', jsonb_build_object(
    'id', 'demo-res-1', 'customerId', 'demo-cli-1', 'machineIds', jsonb_build_array('demo-maq-1'),
    'startsAt', to_char((v_hoje + interval '-28 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-25 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 75000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Construções Silva & Filhos, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Escavação de fundação para armazém'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-2', jsonb_build_object(
    'id', 'demo-res-2', 'customerId', 'demo-cli-2', 'machineIds', jsonb_build_array('demo-maq-3'),
    'startsAt', to_char((v_hoje + interval '-25 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-24 days' + interval '17:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 4500, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Obrantes — Construção Civil, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Demolição de muro exterior'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-3', jsonb_build_object(
    'id', 'demo-res-3', 'customerId', 'demo-cli-3', 'machineIds', jsonb_build_array('demo-maq-4'),
    'startsAt', to_char((v_hoje + interval '-22 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-20 days' + interval '17:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 7000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Edifica Norte, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Compactação de base para pavimento'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-4', jsonb_build_object(
    'id', 'demo-res-4', 'customerId', 'demo-cli-4', 'machineIds', jsonb_build_array('demo-maq-2'),
    'startsAt', to_char((v_hoje + interval '-20 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-16 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 36000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Terraplanagens Costa, Unipessoal Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Abertura de valas para terraplanagem'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-5', jsonb_build_object(
    'id', 'demo-res-5', 'customerId', 'demo-cli-5', 'machineIds', jsonb_build_array('demo-maq-6'),
    'startsAt', to_char((v_hoje + interval '-18 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-15 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 36000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Grupo Vieira Construções, SA',
    'collaboratorNameSnapshot', '', 'notes', 'Trabalhos em altura na fachada'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-6', jsonb_build_object(
    'id', 'demo-res-6', 'customerId', 'demo-cli-6', 'machineIds', jsonb_build_array('demo-maq-5'),
    'startsAt', to_char((v_hoje + interval '-14 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-12 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 12000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Renovar Obras e Remodelações, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Fornecimento de energia para obra sem rede'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-7', jsonb_build_object(
    'id', 'demo-res-7', 'customerId', 'demo-cli-7', 'machineIds', jsonb_build_array('demo-maq-1'),
    'startsAt', to_char((v_hoje + interval '-12 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-8 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 100000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Construtora Almeida & Pereira, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Escavação de piscina'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-8', jsonb_build_object(
    'id', 'demo-res-8', 'customerId', 'demo-cli-8', 'machineIds', jsonb_build_array('demo-maq-3'),
    'startsAt', to_char((v_hoje + interval '-9 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '-7 days' + interval '17:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'completed', 'expectedValueCents', 9000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Infraestruturas do Minho, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Demolição de pavimento antigo'
  ), v_agora, v_utilizador, v_tag);

  -- Recolha em atraso: devia ter terminado há 18h, continua "rented"
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-9', jsonb_build_object(
    'id', 'demo-res-9', 'customerId', 'demo-cli-1', 'machineIds', jsonb_build_array('demo-maq-2'),
    'startsAt', to_char((v_agora + interval '-96 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_agora + interval '-18 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'rented', 'expectedValueCents', 36000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Construções Silva & Filhos, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Devia ter sido devolvida — recolha em atraso'
  ), v_agora, v_utilizador, v_tag);

  -- Termina nas próximas 48h (#1)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-10', jsonb_build_object(
    'id', 'demo-res-10', 'customerId', 'demo-cli-2', 'machineIds', jsonb_build_array('demo-maq-1'),
    'startsAt', to_char((v_agora + interval '-72 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_agora + interval '18 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'rented', 'expectedValueCents', 100000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Obrantes — Construção Civil, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Termina brevemente, agendar recolha'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-11', jsonb_build_object(
    'id', 'demo-res-11', 'customerId', 'demo-cli-3', 'machineIds', jsonb_build_array('demo-maq-3'),
    'startsAt', to_char((v_hoje + interval '3 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '5 days' + interval '17:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'confirmed', 'expectedValueCents', 9000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Edifica Norte, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Confirmada, aguarda início'
  ), v_agora, v_utilizador, v_tag);

  -- Termina nas próximas 48h (#2)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-12', jsonb_build_object(
    'id', 'demo-res-12', 'customerId', 'demo-cli-4', 'machineIds', jsonb_build_array('demo-maq-6'),
    'startsAt', to_char((v_agora + interval '-24 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_agora + interval '40 hours') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'rented', 'expectedValueCents', 36000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Terraplanagens Costa, Unipessoal Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Termina brevemente, agendar recolha'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-13', jsonb_build_object(
    'id', 'demo-res-13', 'customerId', 'demo-cli-5', 'machineIds', jsonb_build_array('demo-maq-5'),
    'startsAt', to_char((v_hoje + interval '5 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '8 days' + interval '18:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'confirmed', 'expectedValueCents', 18000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Grupo Vieira Construções, SA',
    'collaboratorNameSnapshot', '', 'notes', 'Confirmada para obra futura'
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', 'demo-res-14', jsonb_build_object(
    'id', 'demo-res-14', 'customerId', 'demo-cli-6', 'machineIds', jsonb_build_array('demo-maq-4'),
    'startsAt', to_char((v_hoje + interval '10 days' + interval '08:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endsAt', to_char((v_hoje + interval '12 days' + interval '17:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'status', 'confirmed', 'expectedValueCents', 7000, 'collaboratorResponsibleId', null,
    'companyId', v_empresa::text, 'customerNameSnapshot', 'Renovar Obras e Remodelações, Lda',
    'collaboratorNameSnapshot', '', 'notes', 'Confirmada após fim da manutenção da placa compactadora'
  ), v_agora, v_utilizador, v_tag);

  -- ===========================================================================
  -- DESPESAS (6) — combustível, manutenção, seguro
  -- ===========================================================================

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-1', jsonb_build_object(
    'id', 'demo-desp-1',
    'date', to_char((v_hoje + interval '-20 days' + interval '09:15:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 12000, 'category', 'fuel', 'status', 'paid',
    'note', 'Gasóleo para camião de transporte de máquinas', 'description', 'Gasóleo para camião de transporte de máquinas',
    'machineId', null, 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'manual', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-2', jsonb_build_object(
    'id', 'demo-desp-2',
    'date', to_char((v_hoje + interval '-10 days' + interval '16:40:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 8500, 'category', 'fuel', 'status', 'paid',
    'note', 'Combustível da giratória CAT 320', 'description', 'Combustível da giratória CAT 320',
    'machineId', 'demo-maq-1', 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'manual', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-3', jsonb_build_object(
    'id', 'demo-desp-3',
    'date', to_char((v_hoje + interval '-2 days' + interval '11:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 32000, 'category', 'machineMaintenance', 'status', 'unpaid',
    'note', 'Reparação do motor da placa compactadora', 'description', 'Reparação do motor da placa compactadora',
    'machineId', 'demo-maq-4', 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'manual', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-4', jsonb_build_object(
    'id', 'demo-desp-4',
    'date', to_char((v_hoje + interval '-15 days' + interval '09:30:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 68000, 'category', 'machineMaintenance', 'status', 'paid',
    'note', 'Manutenção preventiva da giratória CAT 320', 'description', 'Manutenção preventiva da giratória CAT 320',
    'machineId', 'demo-maq-1', 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'qr', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-5', jsonb_build_object(
    'id', 'demo-desp-5',
    'date', to_char((v_hoje + interval '-18 days' + interval '10:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 54000, 'category', 'vehicleInsurance', 'status', 'paid',
    'note', 'Seguro anual da viatura de transporte de máquinas', 'description', 'Seguro anual da viatura de transporte de máquinas',
    'machineId', null, 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'manual', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', 'demo-desp-6', jsonb_build_object(
    'id', 'demo-desp-6',
    'date', to_char((v_hoje + interval '-6 days' + interval '14:20:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 9800, 'category', 'fuel', 'status', 'paid',
    'note', 'Gasóleo para máquinas em obra', 'description', 'Gasóleo para máquinas em obra',
    'machineId', null, 'vehicleId', null, 'documentPath', null,
    'recordedByCollaboratorId', null, 'dataSource', 'manual', 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- ===========================================================================
  -- RECEBIMENTOS (12) — ligados às reservas, ao longo do mês
  -- ===========================================================================

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-1', jsonb_build_object(
    'id', 'demo-rec-1',
    'date', to_char((v_hoje + interval '-24 days' + interval '10:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 75000, 'customerId', 'demo-cli-1', 'bookingId', 'demo-res-1',
    'method', 'transfer', 'note', 'Pagamento integral do serviço',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-2', jsonb_build_object(
    'id', 'demo-rec-2',
    'date', to_char((v_hoje + interval '-24 days' + interval '17:30:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 4500, 'customerId', 'demo-cli-2', 'bookingId', 'demo-res-2',
    'method', 'cash', 'note', 'Pagamento no acto',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-3', jsonb_build_object(
    'id', 'demo-rec-3',
    'date', to_char((v_hoje + interval '-19 days' + interval '12:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 7000, 'customerId', 'demo-cli-3', 'bookingId', 'demo-res-3',
    'method', 'mbWay', 'note', 'Pagamento integral',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-4', jsonb_build_object(
    'id', 'demo-rec-4',
    'date', to_char((v_hoje + interval '-16 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 20000, 'customerId', 'demo-cli-4', 'bookingId', 'demo-res-4',
    'method', 'transfer', 'note', 'Sinal recebido',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-5', jsonb_build_object(
    'id', 'demo-rec-5',
    'date', to_char((v_hoje + interval '-13 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 16000, 'customerId', 'demo-cli-4', 'bookingId', 'demo-res-4',
    'method', 'multibanco', 'note', 'Liquidação final',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-6', jsonb_build_object(
    'id', 'demo-rec-6',
    'date', to_char((v_hoje + interval '-14 days' + interval '15:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 36000, 'customerId', 'demo-cli-5', 'bookingId', 'demo-res-5',
    'method', 'transfer', 'note', 'Pagamento integral',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-7', jsonb_build_object(
    'id', 'demo-rec-7',
    'date', to_char((v_hoje + interval '-11 days' + interval '11:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 12000, 'customerId', 'demo-cli-6', 'bookingId', 'demo-res-6',
    'method', 'cash', 'note', 'Pagamento no acto',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-8', jsonb_build_object(
    'id', 'demo-rec-8',
    'date', to_char((v_hoje + interval '-8 days' + interval '10:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 60000, 'customerId', 'demo-cli-7', 'bookingId', 'demo-res-7',
    'method', 'transfer', 'note', 'Sinal recebido',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-9', jsonb_build_object(
    'id', 'demo-rec-9',
    'date', to_char((v_hoje + interval '-6 days' + interval '10:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 40000, 'customerId', 'demo-cli-7', 'bookingId', 'demo-res-7',
    'method', 'mbWay', 'note', 'Liquidação final',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-10', jsonb_build_object(
    'id', 'demo-rec-10',
    'date', to_char((v_hoje + interval '-6 days' + interval '16:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 9000, 'customerId', 'demo-cli-8', 'bookingId', 'demo-res-8',
    'method', 'multibanco', 'note', 'Pagamento integral',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Sinal da reserva com recolha em atraso — o restante fica por cobrar
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-11', jsonb_build_object(
    'id', 'demo-rec-11',
    'date', to_char((v_hoje + interval '-4 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 20000, 'customerId', 'demo-cli-1', 'bookingId', 'demo-res-9',
    'method', 'transfer', 'note', 'Sinal — restante por cobrar após recolha',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

  -- Sinal da reserva que termina em breve — o restante fica por cobrar
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', 'demo-rec-12', jsonb_build_object(
    'id', 'demo-rec-12',
    'date', to_char((v_hoje + interval '-3 days' + interval '09:00:00') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'amountCents', 50000, 'customerId', 'demo-cli-2', 'bookingId', 'demo-res-10',
    'method', 'mbWay', 'note', 'Sinal — restante por cobrar após recolha',
    'recordedByCollaboratorId', null, 'archived', false
  ), v_agora, v_utilizador, v_tag);

end $$;

-- =============================================================================
-- LIMPEZA — repor o estado anterior a este seed
-- =============================================================================
-- Ver scripts/limpar_demonstracao.sql, ou descomenta e corre isto (troca o
-- uuid pela empresa usada acima):
--
-- delete from public.punho_operacoes
--  where empresa_id = '00000000-0000-0000-0000-000000000000'
--    and por_dispositivo = 'semente-demonstracao';
