-- =============================================================================
-- Simulação do painel — Depilconcept (empresa de demonstração), pedida pelo César a 11/10/2026
-- =============================================================================
-- Completa a simulação dos 3 anos com o que os ecrãs novos do painel precisam:
--   * ~60 contactos (leads) de agosto a 10 de outubro de 2026, de vários canais
--     (recomendação, chamada, site, porta a porta, veio ao local, Facebook,
--     Instagram, LinkedIn, Google), cerca de um terço já convertido num cliente
--     da simulação e os de terreno atribuídos a colaboradores;
--   * os recebimentos de setembro e outubro de 2026 repostos com o colaborador
--     que os cobrou (a última escrita ganha por `seq`).
-- Tudo INVENTADO. Escreve só em `punho_operacoes` (por_dispositivo = 'simulacao-painel').
-- Idempotente. Apagar:  delete from punho_operacoes where por_dispositivo = 'simulacao-painel';
-- =============================================================================
do $sim$
declare
  v_emp uuid := '74c0fe9e-099b-4108-a766-454f0fdc2397';
  v_d   text := 'simulacao-painel';
  v_cols text[];
  v_clis text[];
  v_fontes text[] := array[
    'referral','referral','referral','referral','referral',
    'call','call','call','call',
    'landingPage','landingPage','landingPage',
    'ownProspecting','ownProspecting','ownProspecting',
    'walkIn','walkIn',
    'facebook','instagram','linkedin'];
  v_nomes text[] := array['Ana','Rita','Sofia','Marta','Inês','Joana','Carla','Beatriz','Helena','Teresa'];
  v_apelidos text[] := array['Lopes','Ferreira','Santos','Oliveira','Pereira','Gomes','Martins','Rocha','Ribeiro','Teixeira'];
begin
  if not exists (select 1 from punho_empresas where id = v_emp) then
    raise exception 'empresa não existe';
  end if;
  delete from punho_operacoes where empresa_id = v_emp and por_dispositivo = v_d;

  select array_agg(entidade_id order by entidade_id) into v_cols
    from punho_operacoes where empresa_id = v_emp and entidade = 'collaborator'
     and por_dispositivo = 'simulacao-3-anos';
  select array_agg(entidade_id order by entidade_id) into v_clis
    from punho_operacoes where empresa_id = v_emp and entidade = 'customer'
     and por_dispositivo = 'simulacao-3-anos';

  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'lead', 'sim-lead-' || i,
    jsonb_build_object(
      'id', 'sim-lead-' || i,
      'name', v_nomes[1 + (i * 3) % 10] || ' ' || v_apelidos[1 + (i * 7) % 10],
      'phone', '91' || lpad(((i * 7919) % 10000000)::text, 7, '0'),
      'source', v_fontes[1 + (i * 13) % 20],
      'status', case when i % 3 = 0 then 'converted' when i % 7 = 0 then 'lost'
                     when i % 3 = 1 then 'contacted' else 'newLead' end,
      'summary', '',
      'bookingId', null,
      'createdAt', to_char(timestamp '2026-08-01 09:00' + ((i * 37) % 71) * interval '1 day'
                           + (i % 8) * interval '1 hour', 'YYYY-MM-DD"T"HH24:MI:SS'),
      'convertedCustomerId', case when i % 3 = 0 then v_clis[1 + (i * 11) % array_length(v_clis, 1)] else null end,
      'collaboratorResponsibleId',
        case when v_fontes[1 + (i * 13) % 20] in ('ownProspecting','walkIn','call')
             then v_cols[1 + (i * 5) % array_length(v_cols, 1)] else null end),
    timestamp '2026-08-01 09:00' + ((i * 37) % 71) * interval '1 day', v_d
  from generate_series(1, 60) i;

  -- Recebimentos de set/out 2026 repostos com quem os cobrou.
  insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
  select gen_random_uuid(), v_emp, 'receipt', o.entidade_id,
    o.payload || jsonb_build_object('recordedByCollaboratorId',
      -- Um colaborador cobra ~38%; os outros repartem o resto.
      v_cols[1 + case when abs(hashtext(o.entidade_id)) % 100 < 38 then 0
                      else 1 + abs(hashtext(o.entidade_id)) % (array_length(v_cols, 1) - 1) end]),
    o.feito_em, v_d
  from punho_operacoes o
  where o.empresa_id = v_emp and o.entidade = 'receipt'
    and o.por_dispositivo = 'simulacao-3-anos'
    and (o.payload->>'date')::timestamp >= timestamp '2026-09-01';
end
$sim$;
