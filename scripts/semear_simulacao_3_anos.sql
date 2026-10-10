-- =============================================================================
-- Simulação de 3 anos — Depilconcept (empresa de demonstração), pedida pelo César a 10/10/2026
-- =============================================================================
-- Dados INVENTADOS para a Depilconcept, a empresa que se mostra a clientes
-- (o que já lá estava, lançado pela app, NÃO se toca):
--   2024: 75 000 € facturados, 80 clientes, 2 carros, 6 colaboradores + gestor
--   2025: 98 000 € facturados, 120 clientes, 4 carros, 8 colaboradores no fim do ano
--   2026: 118 000 € até 2 de Outubro, 180 clientes, 5 carros, 10 colaboradores
--         (um saiu a 30/6 e outro entrou a 1/7). Quem saiu fica como «Inativo».
-- Clientes entram e saem: uns facturam 8 meses e deixam de contratar; a última
-- reserva de cada um é a «última facturação» (agrupável por ano).
-- Lucro positivo nos três anos (despesas modeladas à volta de salários, renda,
-- energia, consumíveis a 7 % das vendas, carros e manutenção).
--
-- Escreve só em `punho_operacoes` (por_dispositivo = 'simulacao-3-anos'); o
-- carimbo atira tudo para hoje, por isso o `feito_em` corrige-se no fim com
-- UPDATE (ver semear_historico_kpis.sql). Idempotente.
-- Apagar:  delete from punho_operacoes where por_dispositivo = 'simulacao-3-anos';
-- =============================================================================
do $sim$
declare
  v_emp uuid := '3d9d0b65-16a1-4078-8b30-9f5659a9baac';
  v_d   text := 'simulacao-3-anos';
  v_hoje date := date '2026-10-10';
begin
  if not exists (select 1 from punho_empresas where id = v_emp) then
    raise exception 'empresa não existe';
  end if;
  delete from punho_operacoes where empresa_id = v_emp and por_dispositivo = v_d;

  create temp table sim_c on commit drop as
  select g, ini, case
      when g <= 80 and g % 4 = 0 then ini + interval '8 months'
      when g <= 80 and g % 7 = 1 then date '2025-01-01' + ((g*11) % 240)
      when g <= 80 and g % 11 = 2 then date '2026-01-01' + ((g*17) % 200)
      when g between 81 and 120 and g % 4 = 0 then ini + interval '8 months'
      when g between 81 and 120 and g % 9 = 1 then date '2026-01-01' + ((g*11) % 200)
      when g > 120 and g % 10 = 3 then ini + interval '4 months'
      else date '2099-12-31' end::date as fim
  from (select g, case
          when g <= 80  then date '2024-01-01' + ((g*13) % 150)
          when g <= 120 then date '2025-01-01' + ((g*13) % 170)
          else               date '2026-01-01' + ((g*13) % 170) end as ini
        from generate_series(1,180) g) q;

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'customer', 'sim-cli-' || g,
    jsonb_build_object('id','sim-cli-'||g,
      'name', (array['Ana','Bruno','Carla','Diogo','Eva','Filipe','Graça','Hugo','Inês','João','Lúcia','Miguel'])[1+(g-1)%12]
              || ' ' ||
              (array['Almeida','Barbosa','Cardoso','Duarte','Esteves','Ferreira','Gomes','Henriques','Lopes','Machado','Neves','Oliveira','Pinto','Queirós','Rocha'])[1+((g-1)/12)%15],
      'phone','9'||(10000000+g*37151)::text,'taxId',null,'email',null,'address',null,
      'postalCode',null,'locality','Braga','notes','','companyId','local-company','archived',false),
    ini::timestamptz, v_d
  from sim_c;

  -- colaboradores: entradas, saídas (ficam como Inativo, com a saída nas notas)
  create temp table sim_col on commit drop as
  select * from (values
    (1,'Beatriz Costa','Esteticista',125000,date '2024-01-01',null::date,true),
    (2,'Sara Pinto','Rececionista',95000,date '2024-01-01',null,true),
    (3,'Mariana Vaz','Esteticista',36000,date '2024-01-01',null,false),
    (4,'Patrícia Soares','Esteticista',34000,date '2024-01-01',date '2026-06-30',false),
    (5,'Cláudia Ramos','Rececionista',32000,date '2024-01-01',null,false),
    (6,'Filipa Rego','Esteticista',30000,date '2024-01-01',date '2025-10-31',false),
    (7,'Susana Brito','Esteticista',32000,date '2025-02-01',null,false),
    (8,'Carla Mendes','Esteticista',110000,date '2025-08-01',null,true),
    (9,'Ines Duarte','Esteticista',110000,date '2025-10-01',null,true),
    (10,'Vera Antunes','Esteticista',35000,date '2026-01-01',null,false),
    (11,'Lara Campos','Esteticista',33000,date '2026-02-01',null,false),
    (12,'Elisa Moura','Esteticista',34000,date '2026-07-01',null,false)
  ) c(n, nome, papel, custo, ini, fim, ja_existe);

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'collaborator', 'sim-col-' || n,
    jsonb_build_object('id','sim-col-'||n,'name',nome,
      'status', case when fim is null then 'active' else 'inactive' end,
      'phone',null,'role',papel,
      'costFrequency','monthly','costCents',custo,'schedule','{}'::jsonb,
      'notes', case when fim is null then 'Entrou em '||to_char(ini,'DD/MM/YYYY')
                    else 'Entrou em '||to_char(ini,'DD/MM/YYYY')||' · saiu em '||to_char(fim,'DD/MM/YYYY') end,
      'archived',false,
      'employmentType','contrato','socialSecurityNumber',null,'taxId',null,
      'maritalStatus','unmarried','dependents',0),
    ini::timestamptz, v_d
  from sim_col where not ja_existe;

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'vehicle', 'sim-vei-' || n,
    jsonb_build_object('id','sim-vei-'||n,'plate',matricula,'type',tipo,'status','active',
      'alias',alias,'monthlyPaymentCents',null,'paymentDayOfMonth',null,'insuranceCents',null,
      'insuranceFrequency',null,'maintenanceCents',null,'notes','','archived',false),
    now(), v_d
  from (values
    (2,'56-CD-78','Carrinha','Carrinha 2'),
    (3,'90-EF-12','Carrinha','Carrinha 3'),
    (4,'34-GH-56','Carro','Carro 4'),
    (5,'78-IJ-90','Carrinha','Carrinha 5')
  ) v(n, matricula, tipo, alias);

  -- reservas: cada dia só tem como clientes os que estão a contratar nesse dia
  create temp table sim_ativos on commit drop as
  select d::date dia, (select array_agg(g order by g) from sim_c where ini <= d::date and fim >= d::date) arr
  from generate_series(date '2024-01-01', date '2026-10-02', interval '1 day') d;

  create temp table sim_b on commit drop as
  select q.ano, q.i, q.dia,
         a.arr[1 + (q.i * 7 + q.ano) % cardinality(a.arr)] as cli,
         1 + (q.i % 3) as maq, q.valor, q.n, q.alvo
  from (
    select y.ano, i,
           (y.ini + ((i * 977) % y.nd) * interval '1 day')::date as dia,
           ((y.alvo / y.n) * 0.6)::int + (i * 1373) % (((y.alvo / y.n) * 0.8)::int) as valor,
           y.n, y.alvo
    from (values
      (2024, date '2024-01-01', 366, 1500, 7500000),
      (2025, date '2025-01-01', 365, 1850, 9800000),
      (2026, date '2026-01-01', 275, 2150, 11800000)
    ) y(ano, ini, nd, n, alvo),
    lateral generate_series(1, y.n) i
  ) q
  join sim_ativos a on a.dia = q.dia;

  -- escala o ano para a soma bater no alvo e acerta o cêntimo na última
  update sim_b b set valor = round(b.valor * b.alvo::numeric / t.soma)::int
  from (select ano, sum(valor) soma from sim_b group by ano) t where b.ano = t.ano;
  update sim_b b set valor = valor + (b.alvo - t.soma)
  from (select ano, sum(valor) soma from sim_b group by ano) t
  where b.ano = t.ano and b.i = (select max(i) from sim_b x where x.ano = b.ano);

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'booking', 'sim-res-' || ano || '-' || i,
    jsonb_build_object('id','sim-res-'||ano||'-'||i,'customerId','sim-cli-'||cli,
      'machineIds', jsonb_build_array((array['m1791560797173357','m1791560839855636','m1791560886323897'])[maq]),
      'startsAt', to_char(dia,'YYYY-MM-DD')||'T09:00:00.000',
      'endsAt',   to_char(dia,'YYYY-MM-DD')||'T18:00:00.000',
      'status','completed','expectedValueCents',valor,
      'collaboratorResponsibleId',null,'companyId','local-company',
      'customerNameSnapshot','','collaboratorNameSnapshot','','notes',''),
    now(), v_d
  from sim_b;

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'receipt', 'sim-rec-' || ano || '-' || i,
    jsonb_build_object('id','sim-rec-'||ano||'-'||i,
      'date', to_char(dia + (i % 25),'YYYY-MM-DD')||'T12:00:00.000',
      'amountCents', valor,'customerId','sim-cli-'||cli,'bookingId','sim-res-'||ano||'-'||i,
      'method',(array['transfer','mbWay','cash','multibanco'])[1+(i%4)],
      'note','','recordedByCollaboratorId',null,'archived',false),
    now(), v_d
  from sim_b
  where i % 17 <> 0 and dia + (i % 25) <= v_hoje;

  create temp table sim_e (id text, dia date, cents int, cat text, descr text, vei text) on commit drop;

  insert into sim_e
  with m as (
    select mes::date mes, extract(year from mes)::int - 2023 k, extract(month from mes)::int mm,
           (mes::date >= date '2026-10-01') parcial
    from generate_series(date '2024-01-01', date '2026-10-01', interval '1 month') mes
  ), vendas as (
    select date_trunc('month', dia)::date mes, sum(valor) soma from sim_b group by 1
  )
  select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-rent', m.mes, (array[40000,43000,47000])[m.k], 'rent', 'Renda', null from m
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-sal', m.mes,
      (select sum(custo) from sim_col c where c.ini <= m.mes and (c.fim is null or c.fim >= m.mes + 14)),
      'salaries', 'Salários', null from m
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-pub', m.mes, (array[10000,17000,20000])[m.k], 'advertising', 'Publicidade', null from m
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-lim', m.mes, (array[5000,6000,6000])[m.k], 'cleaning', 'Limpeza', null from m
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-ele', m.mes,
      (array[30000,33000,36000])[m.k] + ((m.mm*313)%4000) + case when m.mm in (1,2,7,8,12) then 3500 else 0 end,
      'electricity', 'Electricidade', null from m where not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-agu', m.mes,
      (array[15000,17000,18500])[m.k] + ((m.mm*97)%1500), 'water', 'Água', null from m where not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-con', m.mes, round(0.07*v.soma)::int,
      'supplies', 'Detergentes e consumíveis', null from m join vendas v on v.mes = m.mes where not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-man', m.mes,
      (array[60000,75000,80000])[m.k], 'machineMaintenance', 'Revisão das máquinas', null from m where m.mm % 3 = 0 and not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-comb'||vv.n, m.mes,
      15000 + ((vv.n*7 + m.mm*13) % 4000), 'fuel', 'Combustível', case when vv.n = 1 then 'v1791567434854807' else 'sim-vei-'||vv.n end
      from m join (values (1,2024),(2,2024),(3,2025),(4,2025),(5,2026)) vv(n, desde) on vv.desde <= 2023 + m.k where not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-seg'||vv.n, m.mes,
      5500, 'vehicleInsurance', 'Seguro', case when vv.n = 1 then 'v1791567434854807' else 'sim-vei-'||vv.n end
      from m join (values (1,2024),(2,2024),(3,2025),(4,2025),(5,2026)) vv(n, desde) on vv.desde <= 2023 + m.k where not m.parcial
  union all select 'sim-desp-'||to_char(m.mes,'YYYYMM')||'-mv'||vv.n, m.mes,
      case when m.mm % 3 = 1 then 12000 else 4000 end, 'vehicleMaintenance', 'Manutenção da viatura', case when vv.n = 1 then 'v1791567434854807' else 'sim-vei-'||vv.n end
      from m join (values (1,2024),(2,2024),(3,2025),(4,2025),(5,2026)) vv(n, desde) on vv.desde <= 2023 + m.k where not m.parcial;

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'expense', id,
    jsonb_build_object('id',id,'date',to_char(dia,'YYYY-MM-DD')||'T10:00:00.000','amountCents',cents,
      'category',cat,'status','paid','note','','description',descr,'machineId',null,'vehicleId',vei,
      'documentPath',null,'recordedByCollaboratorId',null,'dataSource','manual','archived',false),
    now(), v_d
  from sim_e;

  -- o carimbo atirou tudo para hoje: devolve cada operação ao seu dia
  update punho_operacoes set feito_em = (payload->>'startsAt')::timestamptz
   where empresa_id = v_emp and por_dispositivo = v_d and entidade = 'booking';
  update punho_operacoes set feito_em = (payload->>'date')::timestamptz
   where empresa_id = v_emp and por_dispositivo = v_d and entidade in ('expense','receipt');
  update punho_operacoes o set feito_em = c.ini::timestamptz
    from sim_c c where o.empresa_id = v_emp and o.por_dispositivo = v_d
     and o.entidade = 'customer' and o.entidade_id = 'sim-cli-' || c.g;
  update punho_operacoes o set feito_em = c.ini::timestamptz
    from sim_col c where o.empresa_id = v_emp and o.por_dispositivo = v_d
     and o.entidade = 'collaborator' and o.entidade_id = 'sim-col-' || c.n;
  update punho_operacoes set feito_em = case
      when substring(entidade_id from '[0-9]+$')::int <= 2 then timestamptz '2024-01-02'
      when substring(entidade_id from '[0-9]+$')::int <= 4 then timestamptz '2025-01-02'
      else timestamptz '2026-01-02' end
   where empresa_id = v_emp and por_dispositivo = v_d and entidade = 'vehicle';
end $sim$;
