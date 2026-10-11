-- O limite de operadores é o que o César autoriza no Control, e pode ser 0:
-- o gerente e a administrativa (perfil 'gestor') vêm com a compra da app e
-- nunca contam como operadores. Só perfil 'colaborador' conta, como já fazia
-- punho_gestor_decidir_pedido.

-- 1. Definir o limite: aceita 0.
create or replace function public.punho_definir_limite(p_empresa_id uuid, p_novo_limite integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_subscricao_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global define o limite do Punho.'
      using errcode = 'P0001';
  end if;
  if p_novo_limite < 0 then
    raise exception 'O limite não pode ser negativo.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.punho_empresas where id = p_empresa_id) then
    raise exception 'Empresa indicada não existe.' using errcode = 'P0001';
  end if;

  update public.punho_subscricoes s
     set limite_colaboradores_ativos = p_novo_limite,
         updated_at = now()
   where s.id = (
     select id from public.punho_subscricoes
      where empresa_id = p_empresa_id
      order by created_at
      limit 1
   )
  returning s.id into v_subscricao_id;

  if v_subscricao_id is null then
    raise exception 'Empresa sem subscrição — não há linha para actualizar.'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'empresa_id', p_empresa_id,
    'limite_novo', p_novo_limite,
    'subscricao_id', v_subscricao_id
  );
end;
$function$;

-- 2. Listagem: os activos são os operadores (perfil 'colaborador').
create or replace function public.punho_listar_empresas_admin()
returns table(id uuid, nome text, limite_utilizadores integer, ativos_count integer)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global lista empresas do Punho.'
      using errcode = 'P0001';
  end if;
  return query
    select e.id,
           e.nome,
           coalesce((
             select s.limite_colaboradores_ativos
               from public.punho_subscricoes s
              where s.empresa_id = e.id
              order by s.created_at
              limit 1
           ), 0)::int,
           (
             select count(*)
               from public.punho_membros m
              where m.empresa_id = e.id and m.ativo and m.perfil = 'colaborador'
           )::int
      from public.punho_empresas e
     order by e.nome;
end;
$function$;

-- 3. Aprovar um pedido livre: o limite escolhido pode ser 0 (antes subia a 1).
do $$
declare
  v_def text := pg_get_functiondef('public.punho_decidir_pedido(uuid,text,uuid,integer)'::regprocedure);
  v_novo text := replace(v_def,
    'greatest(coalesce(p_limite_utilizadores, 3), 1)',
    'greatest(coalesce(p_limite_utilizadores, 3), 0)');
begin
  if v_novo = v_def then
    raise exception 'punho_decidir_pedido: trecho do limite não encontrado';
  end if;
  execute v_novo;
end $$;
