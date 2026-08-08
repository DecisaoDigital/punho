-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805162409). Estava em
-- produção sem ficheiro no repo.

-- O onboarding não pode perguntar o que o servidor já sabe.
--
-- Quem pede acesso escreve o nome e a empresa no pedido, e o admin aprova-os
-- no Control. Aprovado, o Punho abria na mesma em «Como te chamas?» — a app
-- não tinha por onde saber, porque `punho_meu_acesso` só devolvia o estado.
--
-- Passa a devolver também o que já foi declarado *e confirmado*: o nome do
-- pedido e o nome da empresa criada na aprovação. Serve para **preencher** os
-- três primeiros passos, não para os saltar: a ficha continua por fazer e
-- saltá-la seria marcar como concluído um onboarding que nunca correu.
--
-- Colunas novas no fim: quem já tem a app instalada continua a ler as quatro
-- de sempre e ignora estas.
drop function if exists public.punho_meu_acesso();

create function public.punho_meu_acesso()
returns table(
  membro_ativo boolean,
  perfil text,
  estado text,
  empresa_id uuid,
  nome text,
  empresa_nome text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    exists (select 1 from public.punho_membros m
             where m.user_id = auth.uid() and m.ativo),
    (select m.perfil from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1),
    (select p.estado from public.punho_pedidos_acesso p
      where p.user_id = auth.uid()),
    (select m.empresa_id from public.punho_membros m
      where m.user_id = auth.uid() and m.ativo limit 1),
    -- O nome que a pessoa declarou no pedido. Vazio fica nulo: um espaço em
    -- branco pré-preenchido é pior do que o campo vazio.
    (select nullif(btrim(p.nome), '') from public.punho_pedidos_acesso p
      where p.user_id = auth.uid()),
    -- O nome da empresa vem de `punho_empresas` — a linha que a aprovação
    -- criou —, não de `empresa_indicada`. Sem adesão activa não há empresa
    -- nenhuma para dizer, e o campo fica por preencher.
    (select nullif(btrim(e.nome), '')
       from public.punho_membros m
       join public.punho_empresas e on e.id = m.empresa_id
      where m.user_id = auth.uid() and m.ativo limit 1);
$$;

revoke execute on function public.punho_meu_acesso() from public, anon;
grant execute on function public.punho_meu_acesso() to authenticated;
