-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805153126). Estava em
-- produção sem ficheiro no repo.

-- Como se chama o terminal, segundo quem pediu acesso a partir dele.
--
-- O nome da máquina (`M2101K6G`) é um substituto para quando não se sabe nada.
-- Deixa de o ser no instante em que alguém escreve "DepilConcept" no pedido —
-- e isso acontece muito antes de haver NIF, ficha ou aprovação. O ecrã de pedir
-- acesso não pede NIF nenhum.
--
-- [aprovado] separa o que é identidade do que é declaração. Um pedido pendente
-- é o que o requerente diz que é: mostra-se, porque é melhor do que o modelo do
-- aparelho, mas vai marcado — quem decide não pode confundir uma pretensão com
-- um facto. Aprovado, o nome vem de `punho_empresas` e é do servidor.
--
-- Um terminal pode ter mais do que um pedido (duas pessoas no mesmo aparelho):
-- ganha o aprovado, e entre pendentes o mais recente.
create or replace function public.punho_nomes_por_terminal()
returns table(machine_id text, app text, nome text, aprovado boolean)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global lê os terminais do Punho.'
      using errcode = 'P0001';
  end if;
  return query
    select distinct on (p.machine_id, p.app)
           p.machine_id,
           p.app,
           coalesce(nullif(btrim(e.nome), ''), nullif(btrim(p.empresa_indicada), '')),
           (p.estado = 'aprovado')
      from public.punho_pedidos_acesso p
      left join public.punho_empresas e on e.id = p.empresa_id
     where p.machine_id is not null
       and p.estado in ('pendente', 'aprovado')
       and coalesce(nullif(btrim(e.nome), ''), nullif(btrim(p.empresa_indicada), '')) is not null
     order by p.machine_id, p.app, (p.estado = 'aprovado') desc, p.criado_em desc;
end;
$function$;

revoke all on function public.punho_nomes_por_terminal() from public, anon;
grant execute on function public.punho_nomes_por_terminal() to authenticated;
