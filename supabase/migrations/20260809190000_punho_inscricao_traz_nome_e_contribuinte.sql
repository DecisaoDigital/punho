-- O que a pessoa declara na inscrição passa a ficar guardado.
--
-- A app do operador já pedia o nome e passa a pedir o contribuinte, e ambos
-- iam nos metadados do registo. Só que o gatilho da inscrição escrevia o
-- pedido de acesso e mais nada: `punho_perfis` só nascia se a pessoa fosse,
-- **depois de entrar**, a "Os meus dados" escrever tudo outra vez.
--
-- A consequência era concreta e via-se ontem: `punho_gestor_decidir_pedido` lê
-- o NIF de `punho_perfis` para o pôr na ficha de empregado que cria. Como não
-- havia perfil, a ficha nascia com `taxId` nulo — e ficava mais uma coisa para
-- alguém andar a perguntar por telefone a quem já a tinha escrito.
--
-- Um campo que se preenche e não vai parar a lado nenhum é um placeholder com
-- teclado. Ou serve, ou não se pede.
--
-- O NIF é conferido aqui, e um NIF inválido rejeita a inscrição inteira — como
-- já acontece com um código de convite errado. É preferível a conta não nascer
-- a nascer com um contribuinte que ninguém vai reparar que está errado até
-- alguém emitir uma factura com ele.
create or replace function public.punho_criar_pedido_ao_registar()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_codigo text := nullif(trim(coalesce(new.raw_user_meta_data->>'convite', '')), '');
  v_convite public.punho_convites%rowtype;
  v_empresa text;
  v_perfil text;
  v_maquina text := nullif(trim(coalesce(new.raw_user_meta_data->>'machine_id', '')), '');
  v_app text := coalesce(new.raw_user_meta_data->>'app', '');
  v_nome text := nullif(btrim(coalesce(new.raw_user_meta_data->>'nome', '')), '');
  v_nif  text := nullif(regexp_replace(coalesce(new.raw_user_meta_data->>'nif', ''), '\s', '', 'g'), '');
begin
  if v_app not in ('punho', 'punho_op') then
    return new;
  end if;

  if v_nif is not null and not public.punho_nif_valido(v_nif) then
    raise exception 'O contribuinte não é válido.' using errcode = 'P0001';
  end if;

  -- O perfil da pessoa nasce com a conta. É dela e não da empresa: sobrevive a
  -- mudar de casa, e é de onde a aprovação tira o nome e o NIF para a ficha.
  if v_nome is not null or v_nif is not null then
    insert into public.punho_perfis (user_id, nome, nif, actualizado_em)
    values (new.id, coalesce(v_nome, ''), v_nif, now())
    on conflict (user_id) do update
      set nome = coalesce(nullif(excluded.nome, ''), punho_perfis.nome),
          nif  = coalesce(excluded.nif, punho_perfis.nif),
          actualizado_em = now();
  end if;

  if v_codigo is not null then
    select * into v_convite
      from public.punho_convites
     where upper(codigo) = upper(v_codigo)
       and not usado
       and expira_em > now()
       and lower(email) = lower(new.email)
     for update;

    if not found then
      raise exception 'Código de convite inválido, expirado ou já utilizado.'
        using errcode = 'P0001';
    end if;

    update public.punho_convites
       set usado = true, usado_por = new.id, usado_em = now()
     where id = v_convite.id;

    select nome into v_empresa from public.punho_empresas where id = v_convite.empresa_id;

    insert into public.punho_pedidos_acesso
      (user_id, nome, email, empresa_indicada, empresa_id, perfil, origem,
       convite_id, machine_id, app)
    values
      (new.id, v_nome, new.email,
       coalesce(v_empresa, 'Empresa por confirmar'), v_convite.empresa_id,
       case when v_app = 'punho_op' then 'colaborador' else v_convite.perfil end,
       'convite', v_convite.id, v_maquina, v_app);

    return new;
  end if;

  v_perfil := case
    when v_app = 'punho_op' then 'colaborador'
    when new.raw_user_meta_data->>'perfil' = 'gestor' then 'gestor'
    else 'colaborador'
  end;

  insert into public.punho_pedidos_acesso
    (user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app)
  values
    (new.id, v_nome, new.email,
     coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa por confirmar'),
     v_perfil, 'livre', v_maquina, v_app);

  return new;
end;
$fn$;
