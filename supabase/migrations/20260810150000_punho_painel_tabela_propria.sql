-- =============================================================================
-- O painel do gestor sai do instantâneo e passa a ter tabela própria.
-- =============================================================================
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
-- Esta migration é reversível e não destrói nada. Para a desfazer:
--
--   drop function if exists public.punho_painel_gravar(jsonb, timestamptz);
--   drop table if exists public.punho_painel;
--
-- O painel volta a viajar no instantâneo sem mais nenhuma alteração no
-- servidor — o `payload` nunca deixou de aceitar a chave `painel`, e a app
-- antiga continua a escrevê-la lá. Nenhum dado do negócio depende desta
-- tabela: o pior que acontece a desfazê-la é o gestor voltar a compor o
-- painel uma vez.
--
-- À data de escrita (10 Ago 2026) **nenhum instantâneo em produção contém a
-- chave `painel`** — a versão que a escreve ainda não chegou aos telemóveis.
-- A tabela nasce vazia e não há dados para migrar.
--
-- ── Porque é que o painel NÃO está no registo (`punho_operacoes`) ────────────
--
-- O registo é para **factos do negócio em disputa entre pessoas**: uma reserva
-- que o operador entrega enquanto o gestor a factura, uma máquina que dois
-- telemóveis editam no mesmo minuto. É por isso que tem ordem do servidor,
-- carimbo de quem fez, e uma linha por alteração — precisa de resolver quem
-- ganha, porque há mesmo uma disputa.
--
-- A disposição do painel não é um facto do negócio. É **preferência de uma
-- pessoa**: que KPIs o gestor quer ver primeiro. Não há segunda pessoa a
-- disputá-la — o operador nem sequer tem painel. Pô-la no registo obrigava a
-- inventar uma entidade que não é entidade nenhuma, e a alargar a lista de
-- entidades válidas do servidor para resolver um conflito que não existe.
--
-- Mas também não pode continuar no instantâneo. O instantâneo sobe o estado
-- inteiro de uma vez, e compor o painel são cinco a dez gestos seguidos —
-- cinco a dez subidas do estado inteiro, cada uma a fazer avançar a revisão da
-- empresa e a mandar os outros aparelhos deitar fora o que tivessem por subir.
-- Um acto raro (o onboarding) podia dar-se a esse luxo; um acto repetido não.
--
-- Fica portanto num sítio só seu: uma linha por empresa, sem gatilho, sem
-- projecção, sem entrar no registo. Escreve-se sozinha e não arrasta ninguém.
--
-- ── Guarda de ordem ──────────────────────────────────────────────────────────
--
-- O upsert compara `updated_at` e recusa-se a andar para trás. Sem isto, um
-- telemóvel com relógio atrasado ou uma sincronização que chegue fora de ordem
-- reescreviam a arrumação mais recente com uma mais velha — exactamente a
-- avaria que esta fase veio fechar do lado das entidades. Não se repete o erro
-- na tabela que a substitui.
-- =============================================================================

create table if not exists public.punho_painel (
  empresa_id       uuid primary key
                   references public.punho_empresas(id) on delete cascade,
  dados            jsonb       not null default '{}'::jsonb,
  updated_at       timestamptz not null default now(),
  revision         integer     not null default 1,
  actualizado_por  uuid        references auth.users(id)
);

comment on table public.punho_painel is
  'Disposição do painel de KPIs, uma linha por empresa. Preferência do gestor, '
  'não facto do negócio: fora do registo de operações e fora do instantâneo. '
  'Ver o cabeçalho de 20260810150000_punho_painel_tabela_propria.sql.';

alter table public.punho_painel enable row level security;

-- Só o gestor da empresa, e só da sua. O operador não tem painel nenhum —
-- não lê, não escreve. Sem DELETE: um painel vazio diz-se com `dados = '{}'`,
-- e apagar a linha só serviria para perder a revisão.
drop policy if exists "gestor le o painel da sua empresa" on public.punho_painel;
create policy "gestor le o painel da sua empresa"
  on public.punho_painel for select
  using (empresa_id = public.punho_empresa_atual() and public.punho_e_gestor());

drop policy if exists "gestor cria o painel da sua empresa" on public.punho_painel;
create policy "gestor cria o painel da sua empresa"
  on public.punho_painel for insert
  with check (empresa_id = public.punho_empresa_atual() and public.punho_e_gestor());

drop policy if exists "gestor altera o painel da sua empresa" on public.punho_painel;
create policy "gestor altera o painel da sua empresa"
  on public.punho_painel for update
  using (empresa_id = public.punho_empresa_atual() and public.punho_e_gestor())
  with check (empresa_id = public.punho_empresa_atual() and public.punho_e_gestor());

revoke delete on public.punho_painel from authenticated, anon;

-- -----------------------------------------------------------------------------
-- Gravar, com a guarda de ordem
-- -----------------------------------------------------------------------------
--
-- Tem de ser função e não um upsert do PostgREST: a cláusula `on conflict do
-- update` que o PostgREST gera não leva `where`, e é precisamente o `where`
-- que impede o painel de andar para trás.
--
-- `security invoker` de propósito: a RLS acima é que decide se esta pessoa
-- pode escrever. Uma função `security definer` aqui seria uma porta lateral
-- para o operador escrever o painel que não pode sequer ler.
--
-- Devolve a linha como ficou — que pode ser a que já lá estava, se a que
-- chegou for mais velha. Quem chama fica a saber, em vez de assumir que
-- ganhou.
create or replace function public.punho_painel_gravar(
  p_dados      jsonb,
  p_updated_at timestamptz default now()
) returns public.punho_painel
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_empresa uuid := public.punho_empresa_atual();
  v_linha   public.punho_painel;
begin
  if v_empresa is null then
    raise exception 'sem empresa na sessão' using errcode = '42501';
  end if;

  insert into public.punho_painel as p (empresa_id, dados, updated_at, actualizado_por)
  values (v_empresa, coalesce(p_dados, '{}'::jsonb), p_updated_at, auth.uid())
  on conflict (empresa_id) do update
    set dados           = excluded.dados,
        updated_at      = excluded.updated_at,
        actualizado_por = excluded.actualizado_por,
        revision        = p.revision + 1
    where p.updated_at <= excluded.updated_at
  returning * into v_linha;

  -- O upsert não devolveu linha nenhuma: a guarda de ordem barrou a escrita
  -- por ser mais velha do que a que lá está. Devolve-se a que ficou.
  if v_linha.empresa_id is null then
    select * into v_linha from public.punho_painel where empresa_id = v_empresa;
  end if;

  return v_linha;
end;
$$;

comment on function public.punho_painel_gravar(jsonb, timestamptz) is
  'Grava a disposição do painel com guarda de ordem: uma arrumação mais velha '
  'nunca escreve por cima de uma mais recente. Devolve a linha como ficou.';

grant execute on function public.punho_painel_gravar(jsonb, timestamptz) to authenticated;
