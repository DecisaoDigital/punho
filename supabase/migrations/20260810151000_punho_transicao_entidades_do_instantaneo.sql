-- =============================================================================
-- Transição: o que o instantâneo ainda tem e o registo não, passa ao registo.
-- =============================================================================
--
-- Corre uma vez por empresa, antes de as entidades saírem do instantâneo
-- (`_operationalPayload()`) e do gatilho `punho_estado_operacional_projectar`.
-- Depois disto, o instantâneo deixa de ser dono de máquinas, clientes, leads,
-- reservas, despesas, recebimentos, veículos e colaboradores — e nada se perde
-- na passagem.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
--   -- 1. as operações que esta migration criou (e só essas)
--   delete from public.punho_operacoes where por_dispositivo = 'migracao-fase3';
--
--   -- 2. as tabelas voltam a bater certo com o registo
--   select public.punho_reprojectar_empresa(id) from public.punho_empresas;
--
--   -- 3. a marca
--   alter table public.punho_empresas drop column if exists entidades_migradas_em;
--   drop function if exists public.punho_migrar_entidades_do_instantaneo(uuid);
--
-- O passo 2 é o que devolve as tabelas ao estado anterior: `punho_reprojectar_
-- empresa` reconstrói tudo a partir do registo, e sem as operações apagadas no
-- passo 1 o resultado é o de antes. Nenhuma linha do negócio é destruída em
-- nenhum dos sentidos.
--
-- ── O que esta migration encontra hoje: nada ─────────────────────────────────
--
-- Medido na produção a 10 Ago 2026, por id e não por contagem: **nenhuma
-- entidade existe só no instantâneo**, nas duas empresas, em nenhuma das oito
-- listas. As que existem em ambos têm `dados` idêntico. O instantâneo está
-- atrasado (Aluguer Nogueira: 2 reservas contra 8 nas tabelas), nunca à frente.
--
-- Escreve-se na mesma, e completa, porque o instantâneo de uma empresa pode
-- mudar entre hoje e o dia em que isto for aplicado — e o modo de falhar de
-- uma transição destas é perder em silêncio o que ninguém verificou.
--
-- ── Porque é que só cria o que FALTA ─────────────────────────────────────────
--
-- Uma entidade que já exista na projecção não é tocada, mesmo que o
-- instantâneo dela discorde. Duas razões:
--
--   * o registo é a fonte de verdade declarada (ver o cabeçalho de
--     20260807211049, linha 36) e as tabelas são a sua leitura. O instantâneo é
--     o canal que estava a opinar a mais — não é ele que resolve empates;
--   * a projecção não tem guarda de ordem. Inserir uma operação com o carimbo
--     do instantâneo para uma entidade que já existe reescrevia-a com dados
--     mais velhos — que é exactamente a avaria que esta fase veio fechar.
--
-- O carimbo das operações criadas é o `updated_at` do instantâneo de onde
-- vieram, não `now()`: o facto é dessa data, e uma operação de transição não
-- deve ganhar antiguidade que não tem.
-- =============================================================================

alter table public.punho_empresas
  add column if not exists entidades_migradas_em timestamptz;

comment on column public.punho_empresas.entidades_migradas_em is
  'Quando as entidades do instantâneo passaram ao registo (Fase 3). Não nulo '
  'significa: o instantâneo desta empresa já não é dono de entidade nenhuma.';

create or replace function public.punho_migrar_entidades_do_instantaneo(
  p_empresa uuid
) returns table (entidade text, criadas integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lista    record;
  v_item     jsonb;
  v_id_local text;
  v_quando   timestamptz;
  v_payload  jsonb;
  v_criadas  integer;
  v_existe   boolean;
begin
  select s.payload, s.updated_at into v_payload, v_quando
  from punho_estado_operacional s
  where s.empresa_id = p_empresa;

  -- Sem instantâneo não há nada para migrar, e a empresa fica marcada na mesma:
  -- o instantâneo dela nunca foi dono de entidade nenhuma.
  if v_payload is null then
    update punho_empresas set entidades_migradas_em = coalesce(entidades_migradas_em, now())
    where id = p_empresa;
    return;
  end if;

  for v_lista in
    select * from (values
      ('machines',      'machine',      'punho_maquinas'),
      ('customers',     'customer',     'punho_clientes'),
      ('leads',         'lead',         'punho_leads'),
      ('bookings',      'booking',      'punho_reservas'),
      ('expenses',      'expense',      'punho_despesas'),
      ('receipts',      'receipt',      'punho_recebimentos'),
      ('vehicles',      'vehicle',      'punho_veiculos'),
      ('collaborators', 'collaborator', 'punho_colaboradores')
    ) as t(chave, ent, tabela)
  loop
    v_criadas := 0;

    if jsonb_typeof(v_payload->v_lista.chave) = 'array' then
      for v_item in select * from jsonb_array_elements(v_payload->v_lista.chave)
      loop
        v_id_local := nullif(v_item->>'id', '');
        continue when v_id_local is null;

        -- Já está projectada? Então o registo já a tem (ou já a teve) e esta
        -- migration não opina sobre o conteúdo. Ver o cabeçalho.
        execute format(
          'select exists (select 1 from %I where empresa_id = $1 and id_local = $2)',
          v_lista.tabela
        ) into v_existe using p_empresa, v_id_local;
        continue when v_existe;

        -- O id da operação é determinístico: correr isto duas vezes não cria
        -- duas linhas, mesmo que a projecção da primeira tenha falhado.
        insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
        values (
          punho_id_estavel(p_empresa, 'migracao-fase3:' || v_lista.ent || ':' || v_id_local),
          p_empresa, v_lista.ent, v_id_local, v_item, v_quando, 'migracao-fase3'
        )
        on conflict (id) do nothing;

        if found then
          v_criadas := v_criadas + 1;
        end if;
      end loop;
    end if;

    if v_criadas > 0 then
      entidade := v_lista.ent;
      criadas  := v_criadas;
      return next;
    end if;
  end loop;

  update punho_empresas
  set entidades_migradas_em = coalesce(entidades_migradas_em, now())
  where id = p_empresa;
end;
$$;

comment on function public.punho_migrar_entidades_do_instantaneo(uuid) is
  'Passa ao registo as entidades que só existem no instantâneo. Idempotente: '
  'o id da operação é determinístico e o que já está projectado não é tocado.';

revoke execute on function public.punho_migrar_entidades_do_instantaneo(uuid) from authenticated, anon;

-- -----------------------------------------------------------------------------
-- Correr agora, para todas as empresas, e deixar o resultado no log
-- -----------------------------------------------------------------------------
do $$
declare
  v_empresa record;
  v_r       record;
  v_total   integer := 0;
begin
  for v_empresa in select id, nome from punho_empresas order by nome loop
    for v_r in select * from punho_migrar_entidades_do_instantaneo(v_empresa.id) loop
      raise notice 'transicao: % — % x % criadas no registo', v_empresa.nome, v_r.criadas, v_r.entidade;
      v_total := v_total + v_r.criadas;
    end loop;
  end loop;
  raise notice 'transicao: % operacoes criadas no total', v_total;
end;
$$;
