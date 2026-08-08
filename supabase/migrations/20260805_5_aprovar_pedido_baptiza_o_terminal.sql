-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805152906). Estava em
-- produção sem ficheiro no repo. O número no nome é a ordem em que
-- correu nesse dia — por ordem alfabética ficaria trocada com a que
-- lhe acrescenta a coluna que usa.

-- Aprovar um pedido passa a dar nome ao terminal.
--
-- O Control mostrava `M2101K6G` na Actividade recente muito depois de já haver
-- nome verdadeiro. A cascata de `ContextoInstalacoes.nomeDe` está certa — nome
-- comercial → designação social → nome da máquina → NIF —, o que faltava era
-- alguém escrever o nome na licença. O modelo do aparelho é um substituto para
-- quando não se sabe nada; deixa de o ser no instante em que se sabe.
--
-- É na aprovação e não no pedido de propósito: o nome que vem no pedido é uma
-- declaração de quem o faz, e uma declaração não é identidade. Depois de
-- aprovada, a empresa existe em `punho_empresas` e o nome é do servidor.
--
-- Só toca em licenças `app = 'punho'` e só quando ainda não têm nome. O POS
-- fica de fora, e um nome já sincronizado da ficha da empresa não é
-- substituído por um mais pobre.
create or replace function public.punho_decidir_pedido(
  p_pedido_id uuid,
  p_decisao text,
  p_empresa_id uuid default null,
  p_limite_utilizadores integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pedido public.punho_pedidos_acesso%rowtype;
  v_empresa uuid;
  v_perfil text;
  v_membro uuid;
  v_estado text;
  v_nome_empresa text;
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global decide pedidos do Punho.'
      using errcode = 'P0001';
  end if;
  if p_decisao not in ('aprovar', 'recusar', 'revogar') then
    raise exception 'Decisão inválida: %', p_decisao using errcode = 'P0001';
  end if;

  select * into v_pedido from public.punho_pedidos_acesso
   where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;

  if p_decisao = 'recusar' then
    if v_pedido.estado <> 'pendente' then
      raise exception
        'Só um pedido pendente pode ser recusado (este está %). Para tirar o acesso a uma conta já aprovada, revogue.',
        v_pedido.estado using errcode = 'P0001';
    end if;
    update public.punho_pedidos_acesso
       set estado = 'recusado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object(
      'estado_novo', 'recusado', 'empresa_id', null, 'membro_id', null
    );
  end if;

  if p_decisao = 'revogar' then
    if v_pedido.estado <> 'aprovado' then
      raise exception 'Só um pedido aprovado pode ser revogado (este está %).',
        v_pedido.estado using errcode = 'P0001';
    end if;
    update public.punho_membros
       set ativo = false, updated_at = now()
     where user_id = v_pedido.user_id
    returning id into v_membro;

    update public.punho_pedidos_acesso
       set estado = 'revogado', decidido_em = now(), decidido_por = auth.uid()
     where id = p_pedido_id;
    return jsonb_build_object(
      'estado_novo', 'revogado',
      'empresa_id', v_pedido.empresa_id,
      'membro_id', v_membro
    );
  end if;

  if v_pedido.origem = 'convite' then
    select c.empresa_id into v_empresa
      from public.punho_convites c where c.id = v_pedido.convite_id;
    v_empresa := coalesce(v_empresa, v_pedido.empresa_id);
    if v_empresa is null then
      raise exception
        'Pedido por convite sem empresa associada — convite apagado? Trate à mão antes de aprovar.'
        using errcode = 'P0001';
    end if;
    v_perfil := v_pedido.perfil;
  else
    v_empresa := p_empresa_id;
    if v_empresa is null then
      insert into public.punho_empresas (nome)
      values (coalesce(nullif(btrim(v_pedido.empresa_indicada), ''), 'Empresa sem nome'))
      returning id into v_empresa;

      insert into public.punho_subscricoes
        (empresa_id, dados, limite_colaboradores_ativos)
      values (
        v_empresa,
        jsonb_build_object('estado', 'aprovada-pelo-control'),
        greatest(coalesce(p_limite_utilizadores, 1), 1)
      );

      insert into public.punho_instalacoes (empresa_id, dados)
      values (v_empresa, jsonb_build_object('origem', 'aprovacao-control'));
    else
      if not exists (select 1 from public.punho_empresas where id = v_empresa) then
        raise exception 'Empresa indicada não existe.' using errcode = 'P0001';
      end if;
    end if;
    v_perfil := 'gestor';
  end if;

  insert into public.punho_membros (empresa_id, user_id, perfil, ativo)
  values (v_empresa, v_pedido.user_id, v_perfil, true)
  on conflict (user_id) do update
    set empresa_id = excluded.empresa_id,
        perfil = excluded.perfil,
        ativo = true,
        updated_at = now()
  returning id into v_membro;

  update public.punho_pedidos_acesso
     set estado = 'aprovado',
         empresa_id = v_empresa,
         decidido_em = now(),
         decidido_por = auth.uid()
   where id = p_pedido_id;

  -- O terminal deixa de se chamar pelo modelo do aparelho.
  select nome into v_nome_empresa from public.punho_empresas where id = v_empresa;
  if v_pedido.machine_id is not null and v_nome_empresa is not null then
    update public.licencas
       set nome = v_nome_empresa
     where machine_id = v_pedido.machine_id
       and app = coalesce(v_pedido.app, 'punho')
       and coalesce(btrim(nome), '') = '';
  end if;

  v_estado := 'aprovado';
  return jsonb_build_object(
    'estado_novo', v_estado, 'empresa_id', v_empresa, 'membro_id', v_membro
  );
end;
$function$;
