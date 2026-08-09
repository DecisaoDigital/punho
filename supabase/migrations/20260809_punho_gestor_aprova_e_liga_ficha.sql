-- O gestor aprova quem convidou, e liga-o à ficha de empregado.
--
-- Até aqui só `is_admin()` — o Cesar, no Control — decidia pedidos de acesso.
-- Isso está certo para uma empresa nova, que é uma decisão comercial. Está
-- errado para o operador que o gestor convidou: quem sabe se aquela pessoa
-- trabalha lá é quem a contratou, não nós.
--
-- E há uma segunda coisa a decidir no mesmo gesto, que é a razão de esta
-- função existir em vez de um simples "aprovar": **a pessoa tem de aparecer na
-- lista de empregados**. É lá que vive o custo para a empresa e o que ela lhe
-- desconta. Um operador aprovado sem ficha é alguém a trabalhar que não custa
-- nada a ninguém — e as contas do negócio ficam a mentir por omissão.
--
-- Duas saídas, porque há dois casos reais:
--   * quem já estava na folha e agora vai passar a usar a app  -> ligar;
--   * quem é contratação nova                                  -> criar ficha.
-- Escolher é do gestor. Adivinhar por nós criava duplicados que ninguém
-- detectava: duas fichas da mesma pessoa, ambas com custo, ambas plausíveis.
--
-- O contribuinte que a pessoa declarou na app do operador entra aqui, e é
-- aqui que deixa de ser uma declaração e passa a ser um registo. Não há
-- quarta lista de contribuintes: há a da empresa (`punho_empresas`), a dos
-- empregados (esta) e a dos clientes (`punho_clientes`). O que está em
-- `punho_perfis` é a caixa de entrada, não um registo.

-- A ligação entre a conta e a ficha. Uma pessoa é membro da empresa (tem
-- acesso) e é empregado da empresa (tem custo). São coisas diferentes e vivem
-- em tabelas diferentes; isto amarra as duas.
alter table public.punho_membros
  add column if not exists colaborador_id uuid
  references public.punho_colaboradores (id) on delete set null;

comment on column public.punho_membros.colaborador_id is
  'A ficha de empregado desta pessoa. Nulo em quem tem acesso mas não está na '
  'folha — o gestor da própria empresa, tipicamente.';

-- Uma ficha não pode servir duas contas: seria a mesma pessoa a receber dois
-- ordenados, ou duas pessoas a partilhar um.
create unique index if not exists punho_membros_colaborador_unico
  on public.punho_membros (colaborador_id)
  where colaborador_id is not null;

-- -----------------------------------------------------------------------------
-- Quem está à espera de entrar na minha empresa
-- -----------------------------------------------------------------------------
--
-- Só pedidos com `empresa_id` preenchido, ou seja, os que vieram de um convite
-- desta empresa. Um registo livre não diz a que empresa pertence — escreve o
-- nome numa caixa de texto — e esse continua a ser decisão do Control, porque
-- pode ser uma empresa nova a querer o produto.
create or replace function public.punho_pedidos_da_minha_empresa()
returns table(
  pedido_id uuid,
  nome text,
  email text,
  nif_declarado text,
  perfil text,
  app text,
  criado_em timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    p.id,
    -- O que a pessoa declarou depois ganha ao que escreveu na inscrição: se
    -- corrigiu o nome na app, é o corrigido que o gestor deve ver.
    coalesce(
      nullif(btrim(f.nome), ''),
      nullif(btrim(p.nome), '')
    ),
    p.email,
    nullif(btrim(f.nif), ''),
    p.perfil,
    p.app,
    p.criado_em
  from public.punho_pedidos_acesso p
  left join public.punho_perfis f on f.user_id = p.user_id
  where p.estado = 'pendente'
    and p.empresa_id is not null
    and exists (
      select 1 from public.punho_membros m
       where m.user_id = auth.uid()
         and m.ativo
         and m.perfil = 'gestor'
         and m.empresa_id = p.empresa_id
    )
  order by p.criado_em;
$function$;

revoke all on function public.punho_pedidos_da_minha_empresa() from public, anon;
grant execute on function public.punho_pedidos_da_minha_empresa() to authenticated;

-- -----------------------------------------------------------------------------
-- Aprovar (ligando ou criando ficha), ou recusar
-- -----------------------------------------------------------------------------
--
-- `p_colaborador_id` nulo com decisão `aprovar` significa "criar ficha nova".
-- Não é um valor por omissão descuidado: é a escolha que o ecrã obriga a fazer,
-- e as duas hipóteses estão à vista lá.
create or replace function public.punho_gestor_decidir_pedido(
  p_pedido_id uuid,
  p_decisao text,
  p_colaborador_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pedido public.punho_pedidos_acesso%rowtype;
  v_empresa uuid;
  v_limite integer;
  v_activos integer;
  v_nome text;
  v_nif text;
  v_colaborador uuid := p_colaborador_id;
  v_id_local text;
  v_perfil text;
begin
  if p_decisao not in ('aprovar', 'recusar') then
    raise exception 'Decisão inválida.' using errcode = 'P0001';
  end if;

  select * into v_pedido
    from public.punho_pedidos_acesso where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if v_pedido.estado <> 'pendente' then
    raise exception 'Este pedido já foi decidido (está %).', v_pedido.estado
      using errcode = 'P0001';
  end if;

  v_empresa := v_pedido.empresa_id;
  if v_empresa is null then
    raise exception
      'Este pedido não está ligado a nenhuma empresa. Só o suporte o pode decidir.'
      using errcode = 'P0001';
  end if;

  -- Quem decide tem de ser gestor activo DESTA empresa. Sem isto, um gestor
  -- de outra empresa aprovava pessoas para a casa alheia.
  if not exists (
    select 1 from public.punho_membros m
     where m.user_id = auth.uid() and m.ativo
       and m.perfil = 'gestor' and m.empresa_id = v_empresa
  ) then
    raise exception 'Só o gestor desta empresa pode decidir este pedido.'
      using errcode = 'P0001';
  end if;

  if p_decisao = 'recusar' then
    update public.punho_pedidos_acesso
       set estado = 'recusado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object('estado_novo', 'recusado');
  end if;

  -- ── Limite de colaboradores ───────────────────────────────────────────────
  -- O limite é comercial e quem o define é o Control. O gestor não o pode
  -- exceder por muito que precise, e a mensagem diz-lhe o que fazer em vez de
  -- o deixar a olhar para um erro.
  select s.limite_colaboradores_ativos into v_limite
    from public.punho_subscricoes s where s.empresa_id = v_empresa;
  select count(*) into v_activos
    from public.punho_membros m
   where m.empresa_id = v_empresa and m.ativo and m.perfil = 'colaborador';

  if v_limite is not null and v_activos >= v_limite then
    raise exception
      'A empresa já tem % operadores activos, que é o limite contratado. Peça o alargamento ao suporte antes de aprovar mais.',
      v_activos using errcode = 'P0001';
  end if;

  -- ── Nome e contribuinte declarados ────────────────────────────────────────
  select
    coalesce(nullif(btrim(f.nome), ''), nullif(btrim(v_pedido.nome), '')),
    nullif(btrim(f.nif), '')
    into v_nome, v_nif
    from public.punho_perfis f where f.user_id = v_pedido.user_id;

  if v_nome is null then
    v_nome := nullif(btrim(v_pedido.nome), '');
  end if;

  -- ── A ficha de empregado ──────────────────────────────────────────────────
  if v_colaborador is not null then
    -- Ligar a uma que já existe. Tem de ser desta empresa — um id de outra
    -- casa aqui seria uma pessoa a aparecer na folha errada.
    if not exists (
      select 1 from public.punho_colaboradores c
       where c.id = v_colaborador and c.empresa_id = v_empresa
    ) then
      raise exception 'Essa ficha de empregado não é desta empresa.'
        using errcode = 'P0001';
    end if;
    if exists (
      select 1 from public.punho_membros m
       where m.colaborador_id = v_colaborador and m.user_id <> v_pedido.user_id
    ) then
      raise exception 'Essa ficha já está ligada a outra conta.'
        using errcode = 'P0001';
    end if;

    -- O contribuinte declarado só preenche o que está em falta. Se a ficha já
    -- tem um NIF, é o da folha de salários que manda: foi lá que alguém o
    -- confirmou com um documento na mão.
    if v_nif is not null then
      update public.punho_colaboradores
         set dados = jsonb_set(dados, '{taxId}', to_jsonb(v_nif), true),
             updated_at = now(),
             revision = revision + 1
       where id = v_colaborador
         and coalesce(nullif(btrim(dados->>'taxId'), ''), '') = '';
    end if;
  else
    if v_nome is null then
      raise exception
        'Não há nome para criar a ficha. Peça à pessoa para o escrever na app, ou ligue a uma ficha existente.'
        using errcode = 'P0001';
    end if;

    -- Ficha nova, pelo mesmo caminho por que a app cria as suas: uma linha em
    -- `punho_operacoes`, que o gatilho projecta. Escrever directamente na
    -- tabela deixava os outros aparelhos sem saber — é o registo de operações
    -- que os alimenta.
    v_id_local := 'col-servidor-' || replace(gen_random_uuid()::text, '-', '');

    -- `id` não tem valor por omissão: é o cliente que o gera, para poder
    -- reenviar a mesma operação sem a duplicar. Aqui não há reenvio, mas a
    -- coluna é obrigatória na mesma — e foi assim que o primeiro ensaio desta
    -- função rebentou.
    insert into public.punho_operacoes
      (id, empresa_id, entidade, entidade_id, payload, feito_em,
       por_utilizador, por_dispositivo)
    values (
      gen_random_uuid(), v_empresa, 'collaborator', v_id_local,
      jsonb_build_object(
        'id', v_id_local,
        'name', v_nome,
        'status', 'active',
        'phone', null,
        'role', null,
        'costFrequency', 'monthly',
        -- Custo por apurar, e não zero. Um zero aqui dizia que a pessoa não
        -- custa nada à empresa, e isso entrava nas contas como verdade.
        'costCents', null,
        'schedule', '{}'::jsonb,
        'notes', '',
        'archived', false,
        'employmentType', 'contrato',
        'socialSecurityNumber', null,
        'taxId', v_nif,
        'maritalStatus', 'unmarried',
        'dependents', 0
      ),
      now(), auth.uid(), 'aprovacao-do-gestor'
    );

    v_colaborador := public.punho_id_estavel(v_empresa, v_id_local);
  end if;

  -- ── O acesso ──────────────────────────────────────────────────────────────
  -- Pela app do operador é sempre colaborador, como no registo.
  v_perfil := case
    when v_pedido.app = 'punho_op' then 'colaborador'
    when v_pedido.perfil = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_membros
    (empresa_id, user_id, perfil, ativo, colaborador_id)
  values (v_empresa, v_pedido.user_id, v_perfil, true, v_colaborador)
  on conflict (user_id) do update
    set empresa_id = excluded.empresa_id,
        perfil = excluded.perfil,
        ativo = true,
        colaborador_id = excluded.colaborador_id,
        updated_at = now();

  update public.punho_pedidos_acesso
     set estado = 'aprovado', decidido_em = now(), decidido_por = auth.uid()
   where id = p_pedido_id;

  return jsonb_build_object(
    'estado_novo', 'aprovado',
    'colaborador_id', v_colaborador,
    'ficha_criada', p_colaborador_id is null
  );
end;
$function$;

revoke all on function public.punho_gestor_decidir_pedido(uuid, text, uuid)
  from public, anon;
grant execute on function public.punho_gestor_decidir_pedido(uuid, text, uuid)
  to authenticated;
