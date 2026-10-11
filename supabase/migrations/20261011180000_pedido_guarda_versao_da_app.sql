-- A app que pede acesso diz que versão é (César, 11 Out 2026): o operador não
-- tem ping (a tabela `pings` só aceita pos|punho), por isso a versão viaja no
-- registo e fica no pedido. O Control mostra a do ping se houver, senão esta.
alter table public.punho_pedidos_acesso add column if not exists versao text;

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.punho_criar_pedido_ao_registar()'::regprocedure) into v_def;
  v_def := replace(v_def,
    'v_nif  text := nullif(regexp_replace(coalesce(new.raw_user_meta_data->>''nif'', ''''), ''\s'', '''', ''g''), '''');',
    'v_nif  text := nullif(regexp_replace(coalesce(new.raw_user_meta_data->>''nif'', ''''), ''\s'', '''', ''g''), '''');' || E'\n' ||
    '  v_versao text := nullif(left(btrim(coalesce(new.raw_user_meta_data->>''versao'', '''')), 40), '''');');
  v_def := replace(v_def, 'convite_id, machine_id, app)', 'convite_id, machine_id, app, versao)');
  v_def := replace(v_def, '''convite'', v_convite.id, v_maquina, v_app);', '''convite'', v_convite.id, v_maquina, v_app, v_versao);');
  v_def := replace(v_def, '(user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app)', '(user_id, nome, email, empresa_indicada, perfil, origem, machine_id, app, versao)');
  v_def := replace(v_def, '''livre'', v_maquina, v_app);', '''livre'', v_maquina, v_app, v_versao);');
  if position('v_versao' in v_def) = 0 or position('v_app, v_versao' in v_def) = 0 then
    raise exception 'substituicao falhou';
  end if;
  execute v_def;

  select pg_get_functiondef('public.punho_listar_pedidos_admin(text)'::regprocedure) into v_def;
  v_def := replace(v_def,
    '(select pi.versao from public.pings pi
             where pi.machine_id = p.machine_id and pi.app = p.app
             order by pi.created_at desc limit 1)',
    'coalesce((select pi.versao from public.pings pi
             where pi.machine_id = p.machine_id and pi.app = p.app
             order by pi.created_at desc limit 1), p.versao)');
  if position('p.versao' in v_def) = 0 then raise exception 'listar nao mudou'; end if;
  execute v_def;
end $$;
