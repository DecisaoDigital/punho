create or replace function punho_criar_empresa_inicial(nome_empresa text)
returns uuid language plpgsql security definer set search_path=public as $$
declare empresa uuid;
begin
 if auth.uid() is null then raise exception 'Sessão inválida'; end if;
 if exists(select 1 from punho_membros where user_id=auth.uid()) then raise exception 'O utilizador já pertence a uma empresa'; end if;
 insert into punho_empresas(nome) values(trim(nome_empresa)) returning id into empresa;
 insert into punho_membros(empresa_id,user_id,perfil) values(empresa,auth.uid(),'gestor');
 insert into punho_subscricoes(empresa_id,dados,limite_colaboradores_ativos) values(empresa,jsonb_build_object('estado','desenvolvimento'),3);
 insert into punho_instalacoes(empresa_id,dados) values(empresa,'{}');
 return empresa;
end $$;
grant execute on function punho_criar_empresa_inicial(text) to authenticated;
