-- =============================================================================
-- Semente de histórico para os KPIs — 15 meses de operação (Punho)
-- =============================================================================
--
-- PORQUÊ
-- ------
-- A Fase 0 do plano de KPIs (docs/kpis/MAPA_DADOS.md) parou no portão: a
-- Depilconcept tinha 3 reservas de dois dias, zero despesas e zero
-- recebimentos. Sem despesas não há Lucro nem Margem nem Estrutura; sem
-- recebimentos não há Fluxo de Caixa nem prazos; sem 13 meses não há
-- comparação homóloga. Autorizado pelo César a 13/8/2026: «todas as empresas
-- em punho são de teste e podem perfeitamente ser alteradas ou enriquecidas».
--
-- O QUE SEMEIA
-- ------------
-- 15 meses (o mês corrente e os 14 anteriores) de um estúdio de depilação:
-- clientes, leads com funil, reservas com valor, recebimentos com atraso de
-- pagamento realista, e despesas de estrutura recorrentes mês a mês.
--
-- Escreve **só** em `punho_operacoes`, que é de onde a app lê — o gatilho
-- `punho_operacoes_projectar` trata das tabelas projectadas. Os nomes das
-- chaves do payload vêm de `_bookingToJson` / `_expenseToJson` /
-- `_receiptToJson` / `_leadToJson` / `_customerToJson` em
-- lib/data/repositories/operation_repository.dart, e os valores de enum de
-- lib/domain/models/finance.dart e operations.dart.
--
-- ECONOMIA SEMEADA (para os KPIs terem o que dizer)
-- --------------------------------------------------
--   * sazonalidade real de depilação: pico de Maio a Agosto, vale no Inverno
--   * margem apertada mas positiva na maioria dos meses
--   * **um mês mau de propósito** — o 4.º a contar do fim: as vendas
--     mantêm-se e o lucro cai, porque a Estrutura sobe (salários e renda).
--     É o caso que o ecrã de atenção tem de saber explicar: «o lucro caiu, a
--     margem manteve-se, o que subiu foi a Estrutura».
--   * ~12% das reservas ficam por receber, e as pagas levam de 3 a 38 dias —
--     senão o prazo médio de recebimento é zero e não há buraco de tesouraria
--
-- O CARIMBO NÃO DEIXA ESCREVER NO PASSADO
-- ---------------------------------------
-- `punho_operacoes_carimbar` é um BEFORE INSERT que atira para `now()` tudo o
-- que traga `feito_em` com mais de 7 dias. É uma boa defesa — impede um
-- telemóvel com o relógio trocado de reescrever a história — e por isso não se
-- mexe nela. A semente insere, deixa-se carimbar, e **depois** corrige o
-- `feito_em` com um UPDATE, que o carimbo não vê (só corre no INSERT).
--
-- IDEMPOTENTE
-- -----------
-- Apaga o que ele próprio semeou antes (`por_dispositivo = 'semente-kpis'`)
-- para esta empresa, e volta a semear. Não toca no que veio da app.
--
-- COMO SE APAGA
--   delete from public.punho_operacoes
--    where empresa_id = '<uuid>' and por_dispositivo = 'semente-kpis';
-- =============================================================================

-- A citação leva nome — `$semente$` e não `$$` — porque um `$$` perdido num
-- comentário fecha o bloco a meio e o resto do ficheiro passa a lixo. Já
-- aconteceu aqui, a 13/8/2026: uma linha de pontinhos acabada em `$$`.
do $semente$
declare
  v_empresa   uuid := '3d9d0b65-16a1-4078-8b30-9f5659a9baac';  -- Depilconcept
  v_disp      text := 'semente-kpis';
  v_hoje      date := date_trunc('month', now())::date;
  v_maquinas  text[] := array[
    'm1786396242960338', 'm1786396276842628', 'm1786396311494699'
  ];
  v_nomes     text[] := array[
    'Marta Nogueira','Sofia Antunes','Rita Vilela','Inês Coutinho',
    'Carla Bettencourt','Joana Ramalho','Patrícia Seabra','Helena Quaresma',
    'Beatriz Falcão','Mónica Teixeira','Vera Mascarenhas','Cátia Lourenço'
  ];
  v_mes       int;
  v_i         int;
  v_inicio    date;
  v_sessoes   int;
  v_preco     int;
  v_cli       text;
  v_cli_nome  text;
  v_res       text;
  v_dia       date;
  v_pago      boolean;
  v_atraso    int;
  v_estrutura int;
  v_mau       boolean;
  v_cat       text;
  v_valor     int;
  v_n_leads   int;
  v_span      int;
  -- Quantos meses de história. 26 = o mês corrente mais 25 atrás, que é o
  -- mínimo para o último ano inteiro ter homólogo.
  v_meses     int := 26;
begin
  if not exists (select 1 from punho_empresas where id = v_empresa) then
    raise exception 'empresa % não existe', v_empresa;
  end if;

  delete from punho_operacoes
   where empresa_id = v_empresa and por_dispositivo = v_disp;

  -- ---------------------------------------------------------------- clientes
  for v_i in 1 .. array_length(v_nomes, 1) loop
    insert into punho_operacoes
      (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
    values (
      gen_random_uuid(), v_empresa, 'customer', 'k-cli-' || v_i,
      jsonb_build_object(
        'id', 'k-cli-' || v_i,
        'name', v_nomes[v_i],
        'phone', '9' || (10000000 + v_i * 37151)::text,
        'taxId', null, 'email', null, 'address', null,
        'postalCode', null, 'locality', 'Braga', 'notes', '',
        'companyId', 'local-company', 'archived', false
      ),
      (v_hoje - (v_meses || ' months')::interval
                + (v_i || ' days')::interval)::timestamptz,
      v_disp
    );
  end loop;

  -- ------------------------------------------------------- meses de operação
  -- **Porquê 26 e não 15.** O homólogo precisa do mesmo mês do ano passado.
  -- Com 15 meses só Junho, Julho e Agosto de 2026 tinham com que comparar —
  -- o KPI existia e não tinha o que dizer em 12 dos 15 ecrãs. Com 26, todos os
  -- meses do último ano têm homólogo.
  for v_mes in reverse v_meses - 1 .. 0 loop
    v_inicio := (v_hoje - (v_mes || ' months')::interval)::date;

    -- **O mês mau, de propósito.** É Abril — mês de ombro, igual a Março em
    -- procura. Assim as vendas ficam na mesma e o lucro cai, e a única
    -- explicação possível é a Estrutura: é este o caso que o ecrã de atenção
    -- tem de saber nomear. Escolher um mês de pico estragava a leitura, porque
    -- as vendas subiam ao mesmo tempo e a queda do lucro ficava ambígua.
    v_mau := (v_mes = 4);

    -- Sazonalidade: a depilação vive de Maio a Agosto. O Inverno abranda, mas
    -- não afunda — um estúdio que dá prejuízo cinco meses por ano não serve de
    -- padrão para nada, porque o alarme fica sempre aceso e deixa de se ler.
    v_sessoes := case
      when extract(month from v_inicio) between 5 and 8 then 38
      when extract(month from v_inicio) in (11, 12, 1, 2) then 26
      else 32
    end;

    -- O mês corrente vai a meio: semeia-se só até hoje, e os dias espalham-se
    -- pelos que já passaram em vez de pelo mês inteiro.
    v_span := 27;
    if v_mes = 0 then
      v_sessoes := greatest(4, (v_sessoes * extract(day from now())::int) / 30);
      v_span    := greatest(1, extract(day from now())::int - 1);
    end if;

    -- .................................. reservas e o dinheiro que elas trazem
    for v_i in 1 .. v_sessoes loop
      v_cli      := 'k-cli-' || (1 + (v_i * 7 + v_mes * 3) % array_length(v_nomes,1));
      v_cli_nome := v_nomes[1 + (v_i * 7 + v_mes * 3) % array_length(v_nomes,1)];
      v_res      := 'k-res-' || v_mes || '-' || v_i;
      v_dia      := v_inicio + ((v_i * 29) % v_span || ' days')::interval;
      -- Sessão entre 70 € e 150 €, média perto de 110 €. Estava em 55–140 e
      -- dava uma casa que não pagava a própria renda no Inverno: a margem
      -- ficava negativa metade do ano e o mês mau desaparecia no meio.
      v_preco    := 7000 + ((v_i * 1300 + v_mes * 700) % 8000);

      -- **Nada com data no futuro.** Os dias espalham-se pelo mês inteiro, e no
      -- mês corrente isso punha reservas a 27 marcadas «concluída» a 13 — um
      -- trabalho dado por feito antes de acontecer. Somava receita que ainda
      -- não existe e estragava justamente o mês que se está a olhar.
      continue when v_dia > now()::date;

      insert into punho_operacoes
        (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
      values (
        gen_random_uuid(), v_empresa, 'booking', v_res,
        jsonb_build_object(
          'id', v_res,
          'customerId', v_cli,
          'machineIds', jsonb_build_array(v_maquinas[1 + (v_i % 3)]),
          'startsAt', to_char(v_dia, 'YYYY-MM-DD') || 'T09:00:00.000',
          'endsAt',   to_char(v_dia, 'YYYY-MM-DD') || 'T18:00:00.000',
          -- 5% cancelam. O resto já passou, portanto o relógio dá-as por
          -- concluídas — semeia-se já no estado a que ele chegaria.
          'status', case when v_i % 20 = 0 then 'cancelled' else 'completed' end,
          'expectedValueCents', v_preco,
          'collaboratorResponsibleId', null,
          'companyId', 'local-company',
          'customerNameSnapshot', v_cli_nome,
          'collaboratorNameSnapshot', '',
          'notes', ''
        ),
        v_dia::timestamptz, v_disp
      );

      -- Recebimento: 88% pagam, com atraso de 3 a 38 dias.
      v_pago   := (v_i % 20 <> 0) and ((v_i * 3 + v_mes) % 8 <> 0);
      v_atraso := 3 + ((v_i * 11 + v_mes * 5) % 36);
      if v_pago and (v_dia + v_atraso) <= now()::date then
        insert into punho_operacoes
          (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
        values (
          gen_random_uuid(), v_empresa, 'receipt', 'k-rec-' || v_mes || '-' || v_i,
          jsonb_build_object(
            'id', 'k-rec-' || v_mes || '-' || v_i,
            'date', to_char(v_dia + v_atraso, 'YYYY-MM-DD') || 'T12:00:00.000',
            'amountCents', v_preco,
            'customerId', v_cli,
            'bookingId', v_res,
            'method', (array['transfer','mbWay','cash','multibanco'])[1 + (v_i % 4)],
            'note', '', 'recordedByCollaboratorId', null, 'archived', false
          ),
          (v_dia + v_atraso)::timestamptz, v_disp
        );
      end if;
    end loop;

    -- ................................................ despesas de estrutura
    -- Renda, electricidade, água, limpeza, salários, consumíveis, publicidade.
    -- É isto que faz a Estrutura Compactada existir mês a mês.
    for v_i in 1 .. 7 loop
      v_cat := (array['rent','electricity','water','cleaning','salaries',
                      'supplies','advertising'])[v_i];
      v_valor := case v_cat
        when 'rent'        then case when v_mau then 62000 else 45000 end
        when 'electricity' then 7800 + (case when extract(month from v_inicio) between 5 and 8
                                             then 5500 else 0 end)
                                + ((v_mes * 313) % 1900)
        when 'water'       then 2800 + ((v_mes * 97) % 1400)
        when 'cleaning'    then 9000
        when 'salaries'    then case when v_mau then 210000 else 135000 end
        when 'supplies'    then 21000 + ((v_mes * 517) % 17000)
        else                    6000 + ((v_mes * 271) % 12000)
      end;

      insert into punho_operacoes
        (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
      values (
        gen_random_uuid(), v_empresa, 'expense', 'k-desp-' || v_mes || '-' || v_i,
        jsonb_build_object(
          'id', 'k-desp-' || v_mes || '-' || v_i,
          'date', to_char(v_inicio + interval '4 days', 'YYYY-MM-DD') || 'T10:00:00.000',
          'amountCents', v_valor,
          'category', v_cat,
          'status', 'paid',
          'note', '', 'description', '',
          'machineId', null, 'vehicleId', null, 'documentPath', null,
          'recordedByCollaboratorId', null,
          'dataSource', 'manual', 'archived', false
        ),
        (v_inicio + interval '4 days')::timestamptz, v_disp
      );
    end loop;

    -- Manutenção de máquina de três em três meses: é a despesa que não é
    -- estrutura e que faz a margem oscilar sem a estrutura mexer.
    if v_mes % 3 = 1 then
      insert into punho_operacoes
        (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
      values (
        gen_random_uuid(), v_empresa, 'expense', 'k-desp-man-' || v_mes,
        jsonb_build_object(
          'id', 'k-desp-man-' || v_mes,
          'date', to_char(v_inicio + interval '18 days', 'YYYY-MM-DD') || 'T15:00:00.000',
          'amountCents', 18000 + ((v_mes * 911) % 24000),
          'category', 'machineMaintenance', 'status', 'paid',
          'note', '', 'description', 'Revisão periódica',
          'machineId', v_maquinas[1 + (v_mes % 3)], 'vehicleId', null,
          'documentPath', null, 'recordedByCollaboratorId', null,
          'dataSource', 'manual', 'archived', false
        ),
        (v_inicio + interval '18 days')::timestamptz, v_disp
      );
    end if;

    -- ............................................................... leads
    -- Sem leads não há funil, nem taxa de conversão, nem CAC. Converte cerca
    -- de um terço, que é o que um estúdio destes faz.
    v_n_leads := 9 + (v_mes % 6);
    for v_i in 1 .. v_n_leads loop
      v_dia := v_inicio + ((v_i * 17) % v_span || ' days')::interval;
      continue when v_dia > now()::date;
      insert into punho_operacoes
        (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
      values (
        gen_random_uuid(), v_empresa, 'lead', 'k-lead-' || v_mes || '-' || v_i,
        jsonb_build_object(
          'id', 'k-lead-' || v_mes || '-' || v_i,
          'name', 'Contacto ' || v_mes || '.' || v_i,
          'phone', '9' || (20000000 + v_mes * 1000 + v_i * 31)::text,
          'status', case when v_i % 3 = 0 then 'converted'
                         when v_i % 7 = 0 then 'lost'
                         else 'contacted' end,
          'source', (array['whatsapp','call','google','referral'])[1 + (v_i % 4)],
          'createdAt', to_char(v_dia, 'YYYY-MM-DD') || 'T11:00:00.000',
          'summary', '',
          'collaboratorResponsibleId', null,
          'convertedCustomerId', case when v_i % 3 = 0
            then 'k-cli-' || (1 + (v_i * 7 + v_mes * 3) % array_length(v_nomes,1))
            else null end,
          'bookingId', null
        ),
        v_dia::timestamptz, v_disp
      );
    end loop;
  end loop;

  -- ------------------------------------------------- pôr o log na data certa
  -- O carimbo já atirou tudo para hoje. Aqui devolve-se cada operação ao dia
  -- em que aconteceu, lido do próprio payload — é o UPDATE que o carimbo não
  -- intercepta. Sem isto, o log dá 15 meses de história como se tivesse sido
  -- toda lançada esta tarde, e qualquer leitura por `feito_em` mente.
  update punho_operacoes
     set feito_em = (payload->>'startsAt')::timestamptz
   where empresa_id = v_empresa and por_dispositivo = v_disp
     and entidade = 'booking';

  update punho_operacoes
     set feito_em = (payload->>'date')::timestamptz
   where empresa_id = v_empresa and por_dispositivo = v_disp
     and entidade in ('expense', 'receipt');

  update punho_operacoes
     set feito_em = (payload->>'createdAt')::timestamptz
   where empresa_id = v_empresa and por_dispositivo = v_disp
     and entidade = 'lead';

  update punho_operacoes
     set feito_em = v_hoje - (v_meses || ' months')::interval
   where empresa_id = v_empresa and por_dispositivo = v_disp
     and entidade = 'customer';

  raise notice 'semente-kpis: % operações', (
    select count(*) from punho_operacoes
     where empresa_id = v_empresa and por_dispositivo = v_disp
  );
end $semente$;
