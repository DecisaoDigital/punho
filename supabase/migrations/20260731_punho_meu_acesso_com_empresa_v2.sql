-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260731224837). Estava em
-- produção sem ficheiro no repo.

-- Acrescenta `empresa_id` ao acesso.
--
-- A app precisa dele para sincronizar: as operações são por empresa, e sem
-- saber qual é não há onde as ler nem escrever. Vem de `punho_membros`, que a
-- app não deve consultar directamente — duplicaria a regra de quem é membro, e
-- a cópia é sempre a que fica desactualizada.
--
-- Aditivo do ponto de vista do cliente: uma coluna nova no fim, que apps
-- antigas ignoram. O `drop` é só porque o Postgres não deixa mudar o tipo de
-- retorno de uma função existente.
drop function if exists public.punho_meu_acesso();

create function public.punho_meu_acesso()
returns table(
  membro_ativo boolean,
  perfil text,
  estado text,
  empresa_id uuid
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select
    exists (select 1 from public.punho_membros m
             where m.user_id = auth.uid() and m.ativo),
    (select m.perfil from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1),
    coalesce((select p.estado from public.punho_pedidos_acesso p
               where p.user_id = auth.uid()), 'pendente'),
    (select m.empresa_id from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1);
$function$;

grant execute on function public.punho_meu_acesso() to authenticated, anon;
