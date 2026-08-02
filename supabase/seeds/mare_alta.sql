-- =============================================================================
-- Seed de dados de teste — Lavandaria Mare Alta (Punho)
-- =============================================================================
--
-- O QUE É ISTO
-- ------------
-- Este ficheiro popula a empresa de teste "Lavandaria Mare Alta" com dados
-- simulados completos e coerentes (colaboradores, veiculo, clientes, reservas,
-- despesas e recebimentos com 11 meses de historico e sazonalidade), para
-- deixar de depender de registos placeholder criados a mao durante os testes.
--
-- COMO OS DADOS CHEGAM AO TELEMOVEL (confirmado por inspeccao directa)
-- ----------------------------------------------------------------------------
-- A app Punho NAO le as tabelas "materializadas" punho_clientes, punho_maquinas,
-- punho_colaboradores, punho_veiculos, punho_despesas, punho_recebimentos nem
-- punho_documentos — todas elas estavam com 0 linhas apesar de a empresa ter
-- dados reais criados pela app durante os testes de hoje. A fonte de verdade
-- confirmada é a tabela append-only `punho_operacoes`: cada alteracao (criar/
-- actualizar uma entidade) fica la registada como uma linha com
-- (entidade, entidade_id, payload jsonb), e o dispositivo faz pull ordenado
-- por `seq` (ha um trigger `punho_operacoes_avisar` que avisa em tempo real
-- via Realtime quando entra uma seq nova). Por isso este seed escreve
-- exclusivamente em `punho_operacoes`, com o payload no formato exacto que a
-- app usa (confirmado comparando com as 79 operacoes reais ja existentes para
-- esta empresa, geradas pela propria app e por seeds anteriores).
--
-- Colunas obrigatorias de punho_operacoes (sem default, tem de vir preenchidas
-- em cada insert): id (uuid, unico), empresa_id, entidade, entidade_id,
-- payload, por_utilizador/por_dispositivo (ambos nullable, mas preenchidos
-- aqui para consistencia com o padrao real). `seq` e `feito_em` tem default
-- (nextval / now()) e nao devem ser definidos a mao.
--
-- NAO escreve em punho_estado_operacional (mecanismo alternativo, monolitico,
-- so acedido por RPC e por enquanto com 0 linhas para todas as empresas —
-- nao ha confirmacao de que escrever ali directamente chegue ao telemovel sem
-- passar pela RPC punho_guardar_estado_operacional, por isso nao arriscamos).
-- Por omissao dai tambem nao ha aqui um "historico mensal" agregado à parte:
-- em vez disso criamos despesas e recebimentos reais espalhados por 11 meses,
-- que e o que qualquer dashboard que agregue por data vai consumir.
--
-- IDEMPOTENCIA
-- ------------
-- Todas as linhas inseridas por este seed ficam marcadas com
-- por_dispositivo = 'seed-mare-alta'. Antes de inserir, o bloco apaga
-- qualquer coisa que ele proprio tenha semeado antes (para esta empresa) —
-- correr o ficheiro duas vezes não duplica nada. NÃO toca nos registos
-- manuais dos testes (ex: "Cliente Sino", "Teste Duplicados", "Campainha
-- Teste", "Ana Ferreira") nem nas maquinas ja corrigidas por seeds
-- anteriores ("seed-precos") — esses ficam tal como estao.
--
-- APONTAR A OUTRA EMPRESA
-- ------------------------
-- Muda o valor de v_empresa (linha "declare" logo a seguir) e, se quiseres,
-- o de v_utilizador (tem de ser um membro/gestor activo dessa empresa —
-- confirma com: select id, user_id from punho_membros where empresa_id = '...').
-- Os ids das entidades (clientes, maquinas, etc.) sao uuids literais fixos
-- deste ficheiro; nao ha colisao possivel entre empresas porque a tabela é
-- particionada logicamente por empresa_id, mas se quiseres reaproveitar este
-- ficheiro para uma segunda empresa de teste em simultaneo, muda tambem o
-- prefixo dos uuids (11111111-, 22222222-, etc.) para nao misturar dados
-- visualmente ao inspeccionar a tabela.
--
-- LIMPAR (repor o estado)
-- ------------------------
-- Ver o bloco comentado no fim do ficheiro.
--
-- NAO VERIFICADO — LER ANTES DE APLICAR
-- ----------------------------------------------------------------------------
-- 1. Nao consegui correr este script (só posso ler a base de dados). Os nomes
--    de tabela/coluna e os valores de enum foram confirmados contra
--    information_schema, os check constraints da BD e os ficheiros
--    lib/domain/models/operations.dart, workforce.dart e finance.dart — mas a
--    unica validacao real e o proprio Cesar correr isto num ambiente de teste.
-- 2. O mecanismo de pull no telemovel (ordenado por seq, lote de 500 segundo
--    o codigo) nao foi visto a correr ao vivo por mim — confirma que o
--    telemovel de teste faz mesmo esse pull periodicamente ou por pull-to-
--    refresh depois de aplicares o seed.
-- 3. `por_utilizador` nao tem foreign key para auth.users (confirmado), por
--    isso um id invalido nao rebentava o insert — mas usei o id real do
--    gestor desta empresa (cc1e85e7-...) para ser consistente com os dados
--    reais.
-- 4. Os NIF novos (particulares e empresas) tem digito de controlo valido
--    (algoritmo oficial). Os NISS (Seguranca Social) sao apenas 11 digitos
--    com o formato visto nos dados reais — nao existe um checksum publico
--    fiavel para validar, por isso nao ha garantia de que sejam "validos",
--    so realistas no formato.
--
-- =============================================================================

do $$
declare
  v_empresa     uuid := '1a267759-faeb-473e-828d-cea53cd8bbb3';  -- Lavandaria Mare Alta — muda aqui para apontar a outra empresa
  v_utilizador  uuid := 'cc1e85e7-3064-4b49-8870-0478a33200e8';  -- gestor activo desta empresa (punho_membros.user_id)
  v_tag         text := 'seed-mare-alta';                        -- marca todas as linhas deste seed, para idempotencia e limpeza
begin
  -- Idempotencia: remove primeiro tudo o que este seed tenha inserido antes
  -- para esta empresa, para que correr o ficheiro vezes seguidas nao
  -- duplique nada.
  delete from public.punho_operacoes
   where empresa_id = v_empresa
     and por_dispositivo = v_tag;

  -- Colaboradores novos: uma encarregada de engomadoria e um ex-colaborador arquivado
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'collaborator', '33333333-0000-4000-8000-000000000003', '{"id":"33333333-0000-4000-8000-000000000003","name":"Sofia Nunes","role":"Encarregada de engomadoria","notes":"Entrou em Fevereiro de 2025","phone":"935221004","taxId":"177654325","status":"active","archived":false,"schedule":{"1":{"works":true,"start":{"hour":8,"minute":30},"end":{"hour":17,"minute":0}},"2":{"works":true,"start":{"hour":8,"minute":30},"end":{"hour":17,"minute":0}},"3":{"works":true,"start":{"hour":8,"minute":30},"end":{"hour":17,"minute":0}},"4":{"works":true,"start":{"hour":8,"minute":30},"end":{"hour":17,"minute":0}},"5":{"works":true,"start":{"hour":8,"minute":30},"end":{"hour":16,"minute":0}},"6":{"works":false,"start":null,"end":null},"7":{"works":false,"start":null,"end":null}},"costCents":105000,"dependents":1,"costFrequency":"monthly","maritalStatus":"married1Holder","employmentType":"contrato","socialSecurityNumber":"12233445577"}'::jsonb, now(), v_utilizador, v_tag);
  -- Rui Pinto: arquivado de propósito, para validar que a app não o deixa ficar responsável por reservas futuras
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'collaborator', '33333333-0000-4000-8000-000000000004', '{"id":"33333333-0000-4000-8000-000000000004","name":"Rui Pinto","role":"Recolhas e entregas","notes":"Saiu da empresa em Maio de 2026","phone":"919887744","taxId":"286543214","status":"inactive","archived":true,"schedule":{"1":{"works":false,"start":null,"end":null},"2":{"works":false,"start":null,"end":null},"3":{"works":false,"start":null,"end":null},"4":{"works":false,"start":null,"end":null},"5":{"works":false,"start":null,"end":null},"6":{"works":false,"start":null,"end":null},"7":{"works":false,"start":null,"end":null}},"costCents":89000,"dependents":0,"costFrequency":"monthly","maritalStatus":"unmarried","employmentType":"recibosVerdes","socialSecurityNumber":"13233445588"}'::jsonb, now(), v_utilizador, v_tag);

  -- Veiculo adicional: furgoneta mais antiga, matricula no formato usado antes de 2020 (00-AA-00)
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'vehicle', '44444444-0000-4000-8000-000000000002', '{"id":"44444444-0000-4000-8000-000000000002","type":"Carrinha de recolha","alias":"Carrinha antiga","notes":"Furgoneta de apoio, comprada em segunda mao em 2016","plate":"58-GT-61","status":"active","archived":false,"insuranceCents":32000,"insuranceFrequency":"semiannual","monthlyPaymentCents":null}'::jsonb, now(), v_utilizador, v_tag);

  -- Clientes novos: dois particulares e duas empresas, para diversificar a carteira
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', '11111111-0000-4000-8000-000000000007', '{"id":"11111111-0000-4000-8000-000000000007","name":"Rita Salgado","email":null,"notes":"Cliente particular, entregas ao sabado de manha","phone":"916002233","taxId":"213456702","address":"Rua da Amendoeira 22","locality":"Nazare","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","postalCode":"2450-115"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', '11111111-0000-4000-8000-000000000008', '{"id":"11111111-0000-4000-8000-000000000008","name":"Fernando Alves","email":null,"notes":"Cliente particular, encomenda mensal de toalhas","phone":"938711045","taxId":"234567813","address":"Travessa do Poco 5","locality":"Sitio","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","postalCode":"2450-070"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', '11111111-0000-4000-8000-000000000009', '{"id":"11111111-0000-4000-8000-000000000009","name":"Pastelaria Boa Vista","email":"geral@pastelariaboavista.pt","notes":"Toalhas de cozinha e panos, recolha semanal","phone":"262561450","taxId":"503344125","address":"Rua Sub-Vila 40","locality":"Nazare","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","postalCode":"2450-135"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'customer', '11111111-0000-4000-8000-000000000010', '{"id":"11111111-0000-4000-8000-000000000010","name":"Residencial Atlantico","email":"reservas@residencialatlantico.pt","notes":"Alojamento local, 10 quartos, muda de roupa duas vezes por semana","phone":"262552200","taxId":"518899039","address":"Avenida Vieira Guimaraes 88","locality":"Nazare","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","postalCode":"2450-109"}'::jsonb, now(), v_utilizador, v_tag);

  -- Reservas espalhadas por semanas passadas e futuras: concluidas, confirmadas, pedido e uma cancelada
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000006', '{"id":"55555555-0000-4000-8000-000000000006","notes":"Roupa de cama, entrega ao domicilio","endsAt":"2026-03-13T18:00:00.000","status":"completed","startsAt":"2026-03-12T09:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000007","machineIds":["22222222-0000-4000-8000-000000000004"],"expectedValueCents":6500,"customerNameSnapshot":"Rita Salgado","collaboratorNameSnapshot":"Marta Vieira","collaboratorResponsibleId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000007', '{"id":"55555555-0000-4000-8000-000000000007","notes":"Toalhas de cozinha do mes","endsAt":"2026-05-21T13:00:00.000","status":"completed","startsAt":"2026-05-20T09:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000009","machineIds":["22222222-0000-4000-8000-000000000001"],"expectedValueCents":14000,"customerNameSnapshot":"Pastelaria Boa Vista","collaboratorNameSnapshot":"Sofia Nunes","collaboratorResponsibleId":"33333333-0000-4000-8000-000000000003"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000008', '{"id":"55555555-0000-4000-8000-000000000008","notes":"Muda de roupa quinzenal","endsAt":"2026-08-22T18:00:00.000","status":"confirmed","startsAt":"2026-08-20T08:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000010","machineIds":["22222222-0000-4000-8000-000000000002","22222222-0000-4000-8000-000000000004"],"expectedValueCents":42000,"customerNameSnapshot":"Residencial Atlantico","collaboratorNameSnapshot":"Tiago Ramos","collaboratorResponsibleId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000009', '{"id":"55555555-0000-4000-8000-000000000009","notes":"Ainda por confirmar quantidade","endsAt":"2026-09-06T18:00:00.000","status":"request","startsAt":"2026-09-05T09:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000008","machineIds":["22222222-0000-4000-8000-000000000005"],"expectedValueCents":8000,"customerNameSnapshot":"Fernando Alves","collaboratorNameSnapshot":"","collaboratorResponsibleId":null}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000010', '{"id":"55555555-0000-4000-8000-000000000010","notes":"Cliente cancelou por sobreposicao de agenda","endsAt":"2026-07-18T18:00:00.000","status":"cancelled","startsAt":"2026-07-18T09:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000004","machineIds":["22222222-0000-4000-8000-000000000003"],"expectedValueCents":9600,"customerNameSnapshot":"Ginasio Onda Forte","collaboratorNameSnapshot":"Tiago Ramos","collaboratorResponsibleId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'booking', '55555555-0000-4000-8000-000000000011', '{"id":"55555555-0000-4000-8000-000000000011","notes":"Fardas clinicas do mes","endsAt":"2026-08-29T18:00:00.000","status":"confirmed","startsAt":"2026-08-28T08:00:00.000","companyId":"1a267759-faeb-473e-828d-cea53cd8bbb3","customerId":"11111111-0000-4000-8000-000000000003","machineIds":["22222222-0000-4000-8000-000000000001"],"expectedValueCents":16000,"customerNameSnapshot":"Clinica Sol Nascente","collaboratorNameSnapshot":"Sofia Nunes","collaboratorResponsibleId":"33333333-0000-4000-8000-000000000003"}'::jsonb, now(), v_utilizador, v_tag);

  -- Despesas: renda + electricidade em 11 meses (ago/2025 a jun/2026), com extras pontuais
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000007', '{"id":"77777777-0000-4000-8000-000000000007","date":"2025-08-28T00:00:00.000","note":"Renda de 2025-08","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000008', '{"id":"77777777-0000-4000-8000-000000000008","date":"2025-08-26T00:00:00.000","note":"EDP 2025-08","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"qr","amountCents":43800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000009', '{"id":"77777777-0000-4000-8000-000000000009","date":"2025-09-28T00:00:00.000","note":"Renda de 2025-09","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000010', '{"id":"77777777-0000-4000-8000-000000000010","date":"2025-09-26T00:00:00.000","note":"EDP 2025-09","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"qr","amountCents":36800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000011', '{"id":"77777777-0000-4000-8000-000000000011","date":"2025-10-28T00:00:00.000","note":"Renda de 2025-10","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000012', '{"id":"77777777-0000-4000-8000-000000000012","date":"2025-10-26T00:00:00.000","note":"EDP 2025-10","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":28000,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000013', '{"id":"77777777-0000-4000-8000-000000000013","date":"2025-10-12T00:00:00.000","note":"Detergente industrial e amaciador","status":"paid","archived":false,"category":"supplies","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":18500,"description":"Detergente industrial e amaciador","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000014', '{"id":"77777777-0000-4000-8000-000000000014","date":"2025-11-28T00:00:00.000","note":"Renda de 2025-11","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000015', '{"id":"77777777-0000-4000-8000-000000000015","date":"2025-11-26T00:00:00.000","note":"EDP 2025-11","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":22800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000016', '{"id":"77777777-0000-4000-8000-000000000016","date":"2025-12-28T00:00:00.000","note":"Renda de 2025-12","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000017', '{"id":"77777777-0000-4000-8000-000000000017","date":"2025-12-26T00:00:00.000","note":"EDP 2025-12","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":26200,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000018', '{"id":"77777777-0000-4000-8000-000000000018","date":"2026-01-28T00:00:00.000","note":"Renda de 2026-01","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000019', '{"id":"77777777-0000-4000-8000-000000000019","date":"2026-01-26T00:00:00.000","note":"EDP 2026-01","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":19200,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000020', '{"id":"77777777-0000-4000-8000-000000000020","date":"2026-01-12T00:00:00.000","note":"Abastecimento carrinha","status":"paid","archived":false,"category":"fuel","machineId":null,"vehicleId":"44444444-0000-4000-8000-000000000001","dataSource":"manual","amountCents":7200,"description":"Abastecimento carrinha","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000021', '{"id":"77777777-0000-4000-8000-000000000021","date":"2026-02-28T00:00:00.000","note":"Renda de 2026-02","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000022', '{"id":"77777777-0000-4000-8000-000000000022","date":"2026-02-26T00:00:00.000","note":"EDP 2026-02","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":19200,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000023', '{"id":"77777777-0000-4000-8000-000000000023","date":"2026-03-28T00:00:00.000","note":"Renda de 2026-03","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000024', '{"id":"77777777-0000-4000-8000-000000000024","date":"2026-03-26T00:00:00.000","note":"EDP 2026-03","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":22800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000025', '{"id":"77777777-0000-4000-8000-000000000025","date":"2026-04-28T00:00:00.000","note":"Renda de 2026-04","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000026', '{"id":"77777777-0000-4000-8000-000000000026","date":"2026-04-26T00:00:00.000","note":"EDP 2026-04","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":26200,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000027', '{"id":"77777777-0000-4000-8000-000000000027","date":"2026-04-12T00:00:00.000","note":"Manutencao preventiva lavadoras","status":"paid","archived":false,"category":"machineMaintenance","machineId":"22222222-0000-4000-8000-000000000001","vehicleId":null,"dataSource":"manual","amountCents":15600,"description":"Manutencao preventiva lavadoras","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000028', '{"id":"77777777-0000-4000-8000-000000000028","date":"2026-05-28T00:00:00.000","note":"Renda de 2026-05","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000029', '{"id":"77777777-0000-4000-8000-000000000029","date":"2026-05-26T00:00:00.000","note":"EDP 2026-05","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":29800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000030', '{"id":"77777777-0000-4000-8000-000000000030","date":"2026-05-12T00:00:00.000","note":"Impulsionamento redes sociais epoca alta","status":"paid","archived":false,"category":"advertising","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":12000,"description":"Impulsionamento redes sociais epoca alta","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000031', '{"id":"77777777-0000-4000-8000-000000000031","date":"2026-06-28T00:00:00.000","note":"Renda de 2026-06","status":"paid","archived":false,"category":"rent","machineId":null,"vehicleId":null,"dataSource":"manual","amountCents":95000,"description":"Renda do armazem","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'expense', '77777777-0000-4000-8000-000000000032', '{"id":"77777777-0000-4000-8000-000000000032","date":"2026-06-26T00:00:00.000","note":"EDP 2026-06","status":"paid","archived":false,"category":"electricity","machineId":null,"vehicleId":null,"dataSource":"qr","amountCents":36800,"description":"Electricidade","documentPath":null,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);

  -- Recebimentos: 1-2 por mes, valor e metodo variando com a epoca
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000009', '{"id":"66666666-0000-4000-8000-000000000009","date":"2025-08-06T10:15:00.000","note":"Servico de 2025/08","method":"transfer","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000001","amountCents":45500,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000010', '{"id":"66666666-0000-4000-8000-000000000010","date":"2025-08-16T13:40:00.000","note":"Servico de 2025/08","method":"mbWay","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000002","amountCents":37500,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000011', '{"id":"66666666-0000-4000-8000-000000000011","date":"2025-09-06T10:15:00.000","note":"Servico de 2025/09","method":"mbWay","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000002","amountCents":34200,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000012', '{"id":"66666666-0000-4000-8000-000000000012","date":"2025-09-16T13:40:00.000","note":"Servico de 2025/09","method":"cash","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000003","amountCents":33600,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000013', '{"id":"66666666-0000-4000-8000-000000000013","date":"2025-10-06T10:15:00.000","note":"Servico de 2025/10","method":"cash","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000003","amountCents":59900,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000014', '{"id":"66666666-0000-4000-8000-000000000014","date":"2025-11-06T10:15:00.000","note":"Servico de 2025/11","method":"multibanco","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000004","amountCents":47900,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000015', '{"id":"66666666-0000-4000-8000-000000000015","date":"2025-12-06T10:15:00.000","note":"Servico de 2025/12","method":"transfer","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000005","amountCents":58600,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000016', '{"id":"66666666-0000-4000-8000-000000000016","date":"2026-01-06T10:15:00.000","note":"Servico de 2026/01","method":"mbWay","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000006","amountCents":33700,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000017', '{"id":"66666666-0000-4000-8000-000000000017","date":"2026-02-06T10:15:00.000","note":"Servico de 2026/02","method":"cash","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000007","amountCents":37500,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000018', '{"id":"66666666-0000-4000-8000-000000000018","date":"2026-03-06T10:15:00.000","note":"Servico de 2026/03","method":"multibanco","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000008","amountCents":39000,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000019', '{"id":"66666666-0000-4000-8000-000000000019","date":"2026-04-06T10:15:00.000","note":"Servico de 2026/04","method":"transfer","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000009","amountCents":48000,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000020', '{"id":"66666666-0000-4000-8000-000000000020","date":"2026-05-06T10:15:00.000","note":"Servico de 2026/05","method":"mbWay","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000010","amountCents":29700,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000021', '{"id":"66666666-0000-4000-8000-000000000021","date":"2026-05-16T13:40:00.000","note":"Servico de 2026/05","method":"cash","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000001","amountCents":25500,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000022', '{"id":"66666666-0000-4000-8000-000000000022","date":"2026-06-06T10:15:00.000","note":"Servico de 2026/06","method":"cash","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000001","amountCents":33400,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000001"}'::jsonb, now(), v_utilizador, v_tag);
  insert into public.punho_operacoes
    (id, empresa_id, entidade, entidade_id, payload, feito_em, por_utilizador, por_dispositivo)
  values (gen_random_uuid(), v_empresa, 'receipt', '66666666-0000-4000-8000-000000000023', '{"id":"66666666-0000-4000-8000-000000000023","date":"2026-06-16T13:40:00.000","note":"Servico de 2026/06","method":"multibanco","archived":false,"bookingId":null,"customerId":"11111111-0000-4000-8000-000000000002","amountCents":38400,"recordedByCollaboratorId":"33333333-0000-4000-8000-000000000002"}'::jsonb, now(), v_utilizador, v_tag);
end $$;

-- =============================================================================
-- LIMPEZA — repor o estado anterior a este seed
-- =============================================================================
-- Descomenta e corre este bloco para remover TUDO o que este ficheiro semeou
-- para a Lavandaria Mare Alta (mesma empresa e mesma tag do bloco acima).
-- Nao apaga os registos manuais dos testes nem os que outros seeds ("seed-
-- servidor", "seed-precos", "seed-campainha") ja tinham inserido.
--
-- delete from public.punho_operacoes
--  where empresa_id = '1a267759-faeb-473e-828d-cea53cd8bbb3'
--    and por_dispositivo = 'seed-mare-alta';
