-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805143707). Estava em
-- produção sem ficheiro no repo.

-- O pedido passa a dizer de que terminal veio, e como se chama esse terminal.
--
-- O nome legível sai do mesmo sítio de onde o WashInvoice o tira: o `info_host`
-- que o terminal enviou no `registar-terminal`. As duas apps escreveram-no com
-- chaves diferentes — o POS grava `hostname`, o Punho gravava `host` —, e é por
-- isso que se aceitam as duas: alinhar o cliente não faz aparecer o nome nas
-- instalações que já estão registadas.
--
-- A junção é por `(machine_id, app)`, a identidade canónica de um terminal. A
-- mesma chave dos dois lados, que era o ponto.
--
-- Colunas acrescentadas no fim: os clientes já instalados lêem por nome de
-- campo e ignoram o que não conhecem.
drop function if exists public.punho_listar_pedidos_admin(text);

create function public.punho_listar_pedidos_admin(
  p_estado text default 'pendente'
)
returns table(
  id uuid, user_id uuid, nome text, email text, organizacao_indicada text,
  perfil text, origem text, estado text,
  criado_em timestamptz, decidido_em timestamptz,
  convite_id uuid, convite_empresa_id uuid, convite_empresa_nome text,
  convite_criado_em timestamptz,
  empresa_id uuid, empresa_nome text,
  machine_id text, app text, maquina_nome text, maquina_versao text
)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    raise exception 'Só o administrador global lista pedidos do Punho.'
      using errcode = 'P0001';
  end if;
  return query
    select p.id, p.user_id, p.nome, p.email,
           p.empresa_indicada, p.perfil, p.origem, p.estado,
           p.criado_em, p.decidido_em,
           p.convite_id, c.empresa_id, ce.nome, c.criado_em,
           p.empresa_id, pe.nome,
           p.machine_id, p.app,
           nullif(trim(coalesce(
             l.info_host->>'hostname',
             l.info_host->>'host',
             ''
           )), ''),
           (select pi.versao from public.pings pi
             where pi.machine_id = p.machine_id and pi.app = p.app
             order by pi.created_at desc limit 1)
      from public.punho_pedidos_acesso p
      left join public.punho_convites c on c.id = p.convite_id
      left join public.punho_empresas ce on ce.id = c.empresa_id
      left join public.punho_empresas pe on pe.id = p.empresa_id
      left join public.licencas l
             on l.machine_id = p.machine_id and l.app = p.app
     where p_estado is null or p.estado = p_estado
     order by p.criado_em desc;
end;
$function$;

revoke all on function public.punho_listar_pedidos_admin(text) from public, anon;
grant execute on function public.punho_listar_pedidos_admin(text) to authenticated;
