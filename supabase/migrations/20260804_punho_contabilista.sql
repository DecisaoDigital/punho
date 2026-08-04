-- O portal do contabilista: os cinco anos que o Punho não viveu.
--
-- Uma empresa que instala o Punho hoje começa sem passado. `tesourariaDoMes`
-- calcula variação homóloga (`recebidoMesHomologoCents`) contra um ano que não
-- existe, e o painel fica cego durante doze meses — precisamente os doze meses
-- em que o empresário está a decidir se a app vale alguma coisa. Quem tem esse
-- passado escrito não é o gestor: é o contabilista.
--
-- O contabilista **não tem conta na app**. Recebe um link com um token, abre-o
-- no computador, vê a grelha de meses, preenche o que sabe e deixa em branco o
-- que não sabe. Nunca fala com esta base directamente: quem escreve é uma Edge
-- Function com `service_role`, depois de validar o token. Por isso não há aqui
-- uma única policy para `anon` — o portal não é um cliente da base, é um
-- consumidor de uma função.
--
-- Três regras que atravessam todas as tabelas:
--
--  1. Em branco não é zero. "Não sei quanto faturei em Março de 2022" e
--     "faturei zero em Março de 2022" são respostas diferentes e o Punho
--     decide diferente com cada uma. Em branco é a **ausência de linha**;
--     zero é uma linha com `valor_centavos = 0`.
--  2. Nada é definitivo. O contabilista volta ao link e corrige o que
--     escreveu mal — é a razão de existir de metade das correcções
--     contabilísticas. Cada correcção deixa rasto em
--     `punho_alteracoes_contabilista`.
--  3. O que ficou por responder vira tarefa do gestor, mas só quando o
--     contabilista **terminou**. Ver `punho_lacunas_contabilista`.

-- ---------------------------------------------------------------------------
-- 1. O catálogo: as perguntas são do Punho, não do formulário
-- ---------------------------------------------------------------------------
--
-- Vive em tabela e não em Dart porque tem dois leitores: a app e a Edge
-- Function que serve o formulário. Duas cópias divergiriam à segunda rubrica
-- acrescentada, e a que divergisse seria a que o contabilista vê.
create table if not exists public.punho_rubricas_contabilista (
  chave text primary key,
  rotulo text not null,
  -- Aparece por baixo do campo, no formulário. É onde se diz "sem IVA" antes
  -- de o contabilista somar o IVA por engano.
  ajuda text,
  -- 'mensal' pede-se uma vez por cada mês da janela; 'unica' é uma resposta só
  -- para a empresa toda.
  periodicidade text not null check (periodicidade in ('mensal', 'unica')),
  -- 'euros' grava em `valor_centavos`; 'texto' e 'opcao' gravam em
  -- `valor_texto`. 'opcao' restringe-se a `opcoes`.
  tipo text not null check (tipo in ('euros', 'texto', 'opcao')),
  opcoes text[] not null default '{}',
  -- Uma rubrica essencial é a que, por responder, muda o que o Punho mostra.
  -- Só essas viram tarefa do gestor: pedir-lhe o que não desbloqueia nada é
  -- gastar a única atenção que ele tem.
  essencial boolean not null default false,
  -- Aceita um total anual quando ninguém sabe os meses. "Faturei 12 000 € em
  -- 2025" vale menos do que doze números — não dá comparação homóloga nenhuma
  -- — mas vale muito mais do que o silêncio. Ver
  -- `punho_serie_mensal_contabilista` para o que se faz com ele.
  aceita_anual boolean not null default false,
  ordem integer not null default 0,
  activa boolean not null default true
);

insert into public.punho_rubricas_contabilista
  (chave, rotulo, ajuda, periodicidade, tipo, opcoes, essencial, aceita_anual, ordem)
values
  -- Mensais. A ordem é a do formulário, e é deliberada: começa no número que
  -- o contabilista tem à mão sem abrir nada.
  ('facturacao', 'Faturação do mês',
   'Prestação de serviços e vendas, sem IVA.',
   'mensal', 'euros', '{}', true, true, 10),
  ('iva_liquidado', 'IVA liquidado no mês',
   'O IVA cobrado aos clientes. Deixe em branco se a empresa não liquida IVA.',
   'mensal', 'euros', '{}', false, false, 20),
  ('compras_e_servicos', 'Compras e serviços externos',
   'Fornecimentos e serviços de terceiros no mês, sem IVA.',
   'mensal', 'euros', '{}', true, true, 30),
  ('custos_com_pessoal', 'Custos com pessoal',
   'Remunerações brutas mais encargos da entidade patronal.',
   'mensal', 'euros', '{}', true, true, 40),
  ('resultado', 'Resultado do mês',
   'Se tiver o apuramento mensal. Sem ele, o Punho estima a partir das rubricas acima.',
   'mensal', 'euros', '{}', false, true, 50),

  -- Únicas. A primeira é a mais valiosa de todas — e repare-se no que ela
  -- **não** pergunta: a forma jurídica. Essa o gestor já a deu no onboarding e
  -- perguntá-la outra vez criava duas verdades para o mesmo campo.
  --
  -- O que falta é o degrau a seguir. `regimeDaFormaJuridica()` manda todos os
  -- ENI para `eniSimplificado` e admite porquê em comentário
  -- (`lib/core/finance/regime_fiscal.dart:47`): a app não pergunta se o
  -- empresário optou por contabilidade organizada. Um ENI organizado é lido ao
  -- contrário o ano inteiro — despesas reais tratadas como custo presumido.
  --
  -- Numa Lda. a resposta é sempre "organizada" e o contabilista gasta dois
  -- segundos a confirmá-la. Vale mais essa confirmação barata do que uma
  -- máquina de perguntas condicionais no catálogo v1.
  ('regime_contabilidade', 'Regime de contabilidade',
   'A app já sabe a forma jurídica. Falta saber se a empresa está em regime simplificado ou em contabilidade organizada.',
   'unica', 'opcao',
   array['Regime simplificado', 'Contabilidade organizada'],
   true, false, 100),
  ('periodicidade_iva', 'Periodicidade do IVA',
   'Define quando o Punho avisa o gestor da entrega.',
   'unica', 'opcao', array['Mensal', 'Trimestral', 'Isento / não aplicável'],
   true, false, 110),
  ('cae', 'CAE principal',
   'Código de atividade económica.',
   'unica', 'texto', '{}', false, false, 120),
  ('inicio_actividade', 'Data de início de atividade',
   'No formato AAAA-MM-DD.',
   'unica', 'texto', '{}', false, false, 130),
  ('retencao_irs', 'Retenção de IRS nos recibos',
   'Se a empresa sofre retenção quando fatura a outras empresas.',
   'unica', 'opcao', array['Sim', 'Não', 'Depende do cliente'],
   false, false, 140)
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------------
-- 2. O convite: um link, uma empresa, uma janela de tempo
-- ---------------------------------------------------------------------------
create table if not exists public.punho_convites_contabilista (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null
    references public.punho_empresas(id) on delete cascade,
  nome text,
  email text,
  -- Nunca o token em claro. Quem puser as mãos nesta tabela não consegue abrir
  -- o formulário de ninguém — só confirmar um token que já tenha.
  token_hash text not null unique,
  -- A janela que este convite pede. Por omissão o Punho manda cinco anos até
  -- ao mês passado, mas uma empresa aberta há dois anos não deve receber uma
  -- grelha com trinta e seis meses impossíveis.
  mes_inicial date not null,
  mes_final date not null,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default (now() + interval '90 days'),
  aberto_em timestamptz,
  -- `submetido_em` marca "acabei", não "fechei". O link continua a abrir e a
  -- aceitar correcções até expirar — corrigir um valor errado é trabalho
  -- normal de contabilidade, não uma excepção.
  submetido_em timestamptz,
  revogado_em timestamptz,
  constraint punho_convite_janela_valida check (mes_inicial <= mes_final),
  constraint punho_convite_meses_no_dia_um check (
    extract(day from mes_inicial) = 1 and extract(day from mes_final) = 1
  )
);

create index if not exists punho_convites_contabilista_por_empresa
  on public.punho_convites_contabilista (empresa_id, criado_em desc);

-- ---------------------------------------------------------------------------
-- 3. As respostas
-- ---------------------------------------------------------------------------
--
-- Uma linha por (empresa, rubrica, mês). Chave-valor e não uma coluna por
-- rubrica porque o catálogo vai crescer, e crescer com `alter table` significa
-- que acrescentar uma pergunta é uma migração — o que garante que ninguém
-- acrescenta perguntas.
create table if not exists public.punho_respostas_contabilista (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null
    references public.punho_empresas(id) on delete cascade,
  rubrica text not null
    references public.punho_rubricas_contabilista(chave),
  -- Dia 1 do mês a que respeita. Uma resposta é mensal (`mes`), anual (`ano`)
  -- ou estrutural (nenhum dos dois) — nunca duas coisas ao mesmo tempo.
  mes date,
  -- O total do ano, para quando ninguém sabe os meses. Guarda-se **como
  -- anual**: doze linhas mensais de 1000 € fabricadas a partir de 12 000 €
  -- seriam indistinguíveis de doze meses realmente medidos, e a partir daí não
  -- há volta atrás — a app passaria a comparar Agosto contra um Agosto que
  -- ninguém viu. A repartição faz-se na leitura, e diz que é repartição.
  ano integer check (ano between 1990 and 2100),
  valor_centavos bigint,
  valor_texto text,
  -- Quem escreveu este valor. O gestor completa no Punho o que o contabilista
  -- deixou em branco, e o painel tem de poder dizer de onde veio o número.
  origem text not null default 'contabilista'
    check (origem in ('contabilista', 'gestor')),
  convite_id uuid
    references public.punho_convites_contabilista(id) on delete set null,
  actualizado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now(),
  -- Uma linha sem valor nenhum seria "não sei" escrito de forma cara. Não sei
  -- é não haver linha.
  constraint punho_resposta_tem_valor check (
    valor_centavos is not null or valor_texto is not null
  ),
  constraint punho_resposta_mes_no_dia_um check (
    mes is null or extract(day from mes) = 1
  ),
  constraint punho_resposta_mes_ou_ano check (not (mes is not null and ano is not null))
);

-- Índices parciais em vez de `nulls not distinct`: o mesmo efeito sem depender
-- da versão do Postgres por baixo.
create unique index if not exists punho_resposta_unica_mensal
  on public.punho_respostas_contabilista (empresa_id, rubrica, mes)
  where mes is not null;
create unique index if not exists punho_resposta_unica_anual
  on public.punho_respostas_contabilista (empresa_id, rubrica, ano)
  where ano is not null;
create unique index if not exists punho_resposta_unica_estrutural
  on public.punho_respostas_contabilista (empresa_id, rubrica)
  where mes is null and ano is null;
create index if not exists punho_respostas_contabilista_por_mes
  on public.punho_respostas_contabilista (empresa_id, mes);

-- A coerência entre a resposta e o catálogo não cabe num `check` — precisa de
-- ler a rubrica. Sem isto entrava um total anual numa rubrica que só existe em
-- versão mensal, e nada dava por isso até alguém tentar repartir.
create or replace function public.punho_validar_resposta_contabilista()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.punho_rubricas_contabilista%rowtype;
begin
  select * into r from public.punho_rubricas_contabilista where chave = new.rubrica;

  if r.periodicidade = 'unica' then
    if new.mes is not null or new.ano is not null then
      raise exception 'A rubrica % é única: não leva mês nem ano.', new.rubrica;
    end if;
  else
    if new.mes is null and new.ano is null then
      raise exception 'A rubrica % precisa de um mês ou de um ano.', new.rubrica;
    end if;
    if new.ano is not null and not r.aceita_anual then
      raise exception 'A rubrica % não aceita total anual.', new.rubrica;
    end if;
  end if;

  -- 'euros' vive em `valor_centavos`; o resto em `valor_texto`. Um número
  -- guardado como texto é um número que nenhuma soma encontra.
  if r.tipo = 'euros' and new.valor_centavos is null then
    raise exception 'A rubrica % é um valor em euros.', new.rubrica;
  end if;
  if r.tipo <> 'euros' and new.valor_texto is null then
    raise exception 'A rubrica % é texto.', new.rubrica;
  end if;
  if r.tipo = 'opcao' and not (new.valor_texto = any (r.opcoes)) then
    raise exception 'Resposta fora das opções de %.', new.rubrica;
  end if;

  return new;
end;
$$;

-- Função de trigger não é RPC. O PostgREST publica tudo o que está em `public`
-- e executável, e uma `security definer` exposta a `anon` é sempre uma porta a
-- mais — mesmo que chamá-la fora de um trigger só dê erro. Fechá-la custa uma
-- linha; deixá-la aberta obriga a explicar porquê a cada auditoria.
revoke all on function public.punho_validar_resposta_contabilista()
  from public, anon, authenticated;

drop trigger if exists punho_respostas_contabilista_validacao
  on public.punho_respostas_contabilista;
create trigger punho_respostas_contabilista_validacao
  before insert or update on public.punho_respostas_contabilista
  for each row execute function public.punho_validar_resposta_contabilista();

drop trigger if exists punho_respostas_contabilista_actualizado_em
  on public.punho_respostas_contabilista;
create trigger punho_respostas_contabilista_actualizado_em
  before update on public.punho_respostas_contabilista
  for each row execute function public.punho_tocar_actualizado_em();

-- ---------------------------------------------------------------------------
-- 4. O rasto das correcções
-- ---------------------------------------------------------------------------
--
-- Append-only. Um valor corrigido três meses depois de entrar pode já ter
-- mudado o que o painel disse ao gestor nesse intervalo; sem isto não há como
-- explicar porque é que o número de Maio mudou sozinho.
create table if not exists public.punho_alteracoes_contabilista (
  id bigserial primary key,
  resposta_id uuid,
  empresa_id uuid not null,
  rubrica text not null,
  mes date,
  ano integer,
  accao text not null check (accao in ('criou', 'corrigiu', 'apagou')),
  valor_centavos_antes bigint,
  valor_texto_antes text,
  valor_centavos_depois bigint,
  valor_texto_depois text,
  origem text,
  convite_id uuid,
  autor uuid,
  alterado_em timestamptz not null default now()
);

create index if not exists punho_alteracoes_contabilista_por_empresa
  on public.punho_alteracoes_contabilista (empresa_id, alterado_em desc);

create or replace function public.punho_registar_alteracao_contabilista()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.punho_alteracoes_contabilista (
      resposta_id, empresa_id, rubrica, mes, ano, accao,
      valor_centavos_depois, valor_texto_depois, origem, convite_id, autor
    ) values (
      new.id, new.empresa_id, new.rubrica, new.mes, new.ano, 'criou',
      new.valor_centavos, new.valor_texto, new.origem, new.convite_id,
      new.actualizado_por
    );
    return new;
  elsif tg_op = 'UPDATE' then
    -- Reescrever o mesmo valor não é uma correcção. O formulário devolve a
    -- grelha inteira a cada submissão; sem esta guarda o histórico enchia-se
    -- de linhas que não dizem nada.
    if new.valor_centavos is distinct from old.valor_centavos
       or new.valor_texto is distinct from old.valor_texto then
      insert into public.punho_alteracoes_contabilista (
        resposta_id, empresa_id, rubrica, mes, ano, accao,
        valor_centavos_antes, valor_texto_antes,
        valor_centavos_depois, valor_texto_depois, origem, convite_id, autor
      ) values (
        new.id, new.empresa_id, new.rubrica, new.mes, new.ano, 'corrigiu',
        old.valor_centavos, old.valor_texto,
        new.valor_centavos, new.valor_texto, new.origem, new.convite_id,
        new.actualizado_por
      );
    end if;
    return new;
  else
    insert into public.punho_alteracoes_contabilista (
      resposta_id, empresa_id, rubrica, mes, ano, accao,
      valor_centavos_antes, valor_texto_antes, origem, convite_id, autor
    ) values (
      old.id, old.empresa_id, old.rubrica, old.mes, old.ano, 'apagou',
      old.valor_centavos, old.valor_texto, old.origem, old.convite_id,
      old.actualizado_por
    );
    return old;
  end if;
end;
$$;

revoke all on function public.punho_registar_alteracao_contabilista()
  from public, anon, authenticated;

drop trigger if exists punho_respostas_contabilista_auditoria
  on public.punho_respostas_contabilista;
create trigger punho_respostas_contabilista_auditoria
  after insert or update or delete on public.punho_respostas_contabilista
  for each row execute function public.punho_registar_alteracao_contabilista();

-- ---------------------------------------------------------------------------
-- 5. A caixa do fim: o que o contabilista quer dizer e não cabe num campo
-- ---------------------------------------------------------------------------
create table if not exists public.punho_mensagens_contabilista (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null
    references public.punho_empresas(id) on delete cascade,
  convite_id uuid
    references public.punho_convites_contabilista(id) on delete set null,
  texto text not null,
  criado_em timestamptz not null default now(),
  lido_em timestamptz
);

create index if not exists punho_mensagens_contabilista_por_empresa
  on public.punho_mensagens_contabilista (empresa_id, criado_em desc);

-- ---------------------------------------------------------------------------
-- 6. A série mensal — onde o total anual se reparte, dizendo que se repartiu
-- ---------------------------------------------------------------------------
--
-- Doze números valem mais do que um. Mas um vale muito mais do que nenhum: um
-- gestor que só sabe "faturei 12 000 € em 2025" tem de conseguir dá-lo, e o
-- Punho tem de conseguir usá-lo.
--
-- O que **não** se faz é gravar 1000 € doze vezes. Uma média achatada destrói
-- precisamente aquilo que se foi buscar ao contabilista — a sazonalidade — e,
-- pior, fica indistinguível de doze meses medidos a sério. Duas semanas depois
-- ninguém sabe quais dos números na base é que alguém viu mesmo.
--
-- Por isso o anual guarda-se anual e reparte-se aqui, na leitura, com `origem`
-- a dizer o que é cada linha:
--
--  * `declarado` — o contabilista escreveu este mês.
--  * `repartido` — saiu de uma divisão do total anual.
--
-- E reparte-se melhor do que ÷12: desconta os meses já declarados desse ano e
-- divide **só o resto** pelos que faltam. Quem declarou Janeiro a Março e deu o
-- total do ano fica com nove meses estimados sobre o remanescente, não com doze
-- médias que contradizem os três meses reais.
--
-- Limita-se à janela do convite de propósito: no ano corrente o total pedido
-- vai até ao mês passado, e repartir por doze meses num ano que ainda vai em
-- Agosto encolheria todos os meses a dois terços do que valem.
create or replace function public.punho_serie_mensal_contabilista(
  p_empresa uuid default null,
  p_rubrica text default 'facturacao'
)
returns table (
  mes date,
  valor_centavos bigint,
  origem text
)
language sql
stable
security invoker
set search_path = public
as $$
  with alvo as (
    select coalesce(p_empresa, punho_empresa_atual()) as empresa_id
  ),
  janela as (
    select c.mes_inicial, c.mes_final
      from public.punho_convites_contabilista c, alvo
     where c.empresa_id = alvo.empresa_id
       and c.revogado_em is null
     order by c.criado_em desc
     limit 1
  ),
  declarados as (
    select r.mes, r.valor_centavos
      from public.punho_respostas_contabilista r, alvo
     where r.empresa_id = alvo.empresa_id
       and r.rubrica = p_rubrica
       and r.mes is not null
  ),
  anuais as (
    select r.ano, r.valor_centavos as total
      from public.punho_respostas_contabilista r, alvo
     where r.empresa_id = alvo.empresa_id
       and r.rubrica = p_rubrica
       and r.ano is not null
  ),
  -- Os meses desse ano que cabem na janela e que ninguém declarou.
  por_repartir as (
    select a.ano,
           m.mes::date as mes,
           row_number() over (partition by a.ano order by m.mes) as ordem,
           count(*) over (partition by a.ano) as quantos
      from anuais a
      cross join janela j
      cross join lateral generate_series(
             greatest(make_date(a.ano, 1, 1), j.mes_inicial),
             least(make_date(a.ano, 12, 1), j.mes_final),
             interval '1 month'
           ) as m(mes)
     where not exists (
             select 1 from declarados d where d.mes = m.mes::date
           )
  ),
  sobra as (
    -- O cast a `bigint` não é decorativo: `sum()` sobre `bigint` devolve
    -- `numeric`, a divisão deixaria de ser inteira e cada mês vinha arredondado
    -- para cima. Num total de 1 200 005 cêntimos repartido por dez meses isso
    -- fabricava cinco cêntimos que ninguém faturou — e a série deixava de somar
    -- o que o contabilista escreveu.
    select a.ano,
           (a.total - coalesce((
             select sum(d.valor_centavos) from declarados d
              where extract(year from d.mes) = a.ano
           ), 0))::bigint as centavos
      from anuais a
  )
  select d.mes, d.valor_centavos, 'declarado'::text
    from declarados d
  union all
  -- O resto da divisão inteira vai todo para o último mês: a soma da série tem
  -- de bater certo com o total que o contabilista escreveu, ao cêntimo.
  select p.mes,
         (s.centavos / p.quantos)
           + case when p.ordem = p.quantos
                  then s.centavos - (s.centavos / p.quantos) * p.quantos
                  else 0 end,
         'repartido'::text
    from por_repartir p
    join sobra s on s.ano = p.ano
   -- Sobra negativa é conflito, não estimativa: os meses declarados já somam
   -- mais do que o total do ano. Devolve-se só o que foi declarado e deixa-se o
   -- conflito à vista de quem comparar as duas coisas, em vez de inventar
   -- meses negativos que ninguém sabe ler.
   where s.centavos > 0
   order by 1;
$$;

-- ---------------------------------------------------------------------------
-- 7. As lacunas — o que vira tarefa do gestor
-- ---------------------------------------------------------------------------
--
-- Agregada de propósito. Cinco rubricas mensais em sessenta meses são
-- trezentas células; trezentas tarefas não são uma lista de tarefas, são um
-- muro. Devolve uma linha por rubrica, com a contagem e o intervalo, e o Punho
-- faz disso uma tarefa só ("Faltam 14 meses de faturação entre 2021 e 2023").
--
-- Só conta depois de o contabilista ter dito que acabou (`submetido_em`) ou de
-- o convite ter expirado. Antes disso o silêncio não é uma lacuna, é alguém a
-- meio do trabalho — e empurrar o gestor para preencher o que o contabilista
-- ainda está a escrever é a melhor forma de ficar com dois números diferentes.
create or replace function public.punho_lacunas_contabilista(
  p_empresa uuid default null
)
returns table (
  rubrica text,
  rotulo text,
  periodicidade text,
  -- Sem cobertura nenhuma: nem mês declarado, nem total anual que o abranja.
  -- Numa rubrica 'unica' é 1 ou 0.
  em_falta integer,
  -- Meses que só o total anual cobre. Não são um buraco — são um número de
  -- pior qualidade. Valem uma sugestão ao gestor ("discrimine 2023 e passa a
  -- haver comparação homóloga"), nunca um alarme.
  so_anual integer,
  -- O intervalo sem discriminação mensal, somando os dois casos acima. Nulo
  -- nas rubricas 'unica'.
  primeiro_mes date,
  ultimo_mes date
)
language sql
stable
security invoker
set search_path = public
as $$
  with alvo as (
    select coalesce(p_empresa, punho_empresa_atual()) as empresa_id
  ),
  convite as (
    select c.*
      from public.punho_convites_contabilista c, alvo
     where c.empresa_id = alvo.empresa_id
       and c.revogado_em is null
       and (c.submetido_em is not null or c.expira_em < now())
     order by c.criado_em desc
     limit 1
  ),
  esperado as (
    select r.chave, r.rotulo, r.periodicidade,
           case when r.periodicidade = 'mensal'
                then m.mes::date
                else null::date
           end as mes
      from public.punho_rubricas_contabilista r
     cross join convite c
      left join lateral generate_series(
             c.mes_inicial, c.mes_final, interval '1 month'
           ) as m(mes)
             on r.periodicidade = 'mensal'
     where r.activa and r.essencial
  ),
  em_aberto as (
    select e.chave, e.rotulo, e.periodicidade, e.mes,
           -- Há total anual a cobrir este mês? Então não é um buraco, é um
           -- número grosso à espera de ser desdobrado.
           exists (
             select 1
               from public.punho_respostas_contabilista ra
              where ra.empresa_id = (select empresa_id from alvo)
                and ra.rubrica = e.chave
                and ra.ano is not null
                and e.mes is not null
                and ra.ano = extract(year from e.mes)::integer
           ) as coberto_por_anual
      from esperado e
      cross join alvo
      left join public.punho_respostas_contabilista resp
             on resp.empresa_id = alvo.empresa_id
            and resp.rubrica = e.chave
            and resp.ano is null
            and resp.mes is not distinct from e.mes
     where resp.id is null
  )
  select chave, rotulo, periodicidade,
         count(*) filter (where not coberto_por_anual)::integer,
         count(*) filter (where coberto_por_anual)::integer,
         min(mes), max(mes)
    from em_aberto
   group by chave, rotulo, periodicidade
   order by chave;
$$;

-- ---------------------------------------------------------------------------
-- 8. Gravar uma resposta — a única porta de escrita do portal
-- ---------------------------------------------------------------------------
--
-- Existe por duas razões, e a segunda é a que importa.
--
-- A primeira é técnica: os índices únicos acima são **parciais**, e o
-- `on conflict` do PostgREST não sabe exprimir o predicado. Um upsert vindo de
-- fora falharia com "no unique or exclusion constraint matching".
--
-- A segunda é de desenho: a empresa **deriva-se do convite**, aqui dentro.
-- Nunca vem no corpo do pedido. Um portal que aceitasse `empresa_id` do
-- formulário era um portal em que qualquer token escrevia na empresa de
-- qualquer outro — e o token é o que o contabilista tem no histórico do
-- browser, num email reencaminhado, numa conversa de WhatsApp.
--
-- Valor vazio apaga a linha: é assim que se volta atrás para "não sei" depois
-- de ter escrito um número por engano.
create or replace function public.punho_guardar_resposta_contabilista(
  p_convite uuid,
  p_rubrica text,
  p_mes date default null,
  p_ano integer default null,
  p_valor_centavos bigint default null,
  p_valor_texto text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.punho_convites_contabilista%rowtype;
  afectadas integer;
begin
  select * into c
    from public.punho_convites_contabilista
   where id = p_convite
     and revogado_em is null
     and expira_em > now();

  if not found then
    raise exception 'Convite inválido ou expirado.' using errcode = '28000';
  end if;

  -- A janela do convite obriga aqui dentro, não na página.
  --
  -- A página só desenha os meses do período pedido, portanto o formulário
  -- nunca envia outros. Mas o token é a autenticação toda: quem o tiver pode
  -- montar o `POST` à mão. Sem esta guarda, um convite para os últimos cinco
  -- anos escrevia facturação em meses futuros ou em 2009, e esses números
  -- entravam nos KPIs sem ninguém os ter pedido.
  --
  -- Rubricas de resposta única (mês e ano nulos) não têm período: passam.
  if p_mes is not null and (p_mes < c.mes_inicial or p_mes > c.mes_final) then
    raise exception 'Mês fora do período do convite.' using errcode = '22007';
  end if;

  if p_ano is not null and (p_ano < extract(year from c.mes_inicial)
                            or p_ano > extract(year from c.mes_final)) then
    raise exception 'Ano fora do período do convite.' using errcode = '22007';
  end if;

  -- Apagar é uma resposta: devolve o campo a "não sei", que é diferente de
  -- zero e diferente de estar errado.
  if p_valor_centavos is null and (p_valor_texto is null or btrim(p_valor_texto) = '') then
    delete from public.punho_respostas_contabilista
     where empresa_id = c.empresa_id
       and rubrica = p_rubrica
       and mes is not distinct from p_mes
       and ano is not distinct from p_ano;
    return 'apagado';
  end if;

  update public.punho_respostas_contabilista
     set valor_centavos = p_valor_centavos,
         valor_texto = nullif(btrim(p_valor_texto), ''),
         origem = 'contabilista',
         convite_id = c.id
   where empresa_id = c.empresa_id
     and rubrica = p_rubrica
     and mes is not distinct from p_mes
     and ano is not distinct from p_ano;

  get diagnostics afectadas = row_count;
  if afectadas > 0 then
    return 'actualizado';
  end if;

  insert into public.punho_respostas_contabilista
    (empresa_id, rubrica, mes, ano, valor_centavos, valor_texto, origem, convite_id)
  values
    (c.empresa_id, p_rubrica, p_mes, p_ano, p_valor_centavos,
     nullif(btrim(p_valor_texto), ''), 'contabilista', c.id);

  return 'criado';
end;
$$;

-- Só o `service_role` chama isto: quem entra por aqui é a Edge Function depois
-- de validar o token. Um cliente anónimo com a chave pública não tem como.
revoke all on function public.punho_guardar_resposta_contabilista(
  uuid, text, date, integer, bigint, text
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. RLS
-- ---------------------------------------------------------------------------
--
-- O portal do contabilista não aparece em lado nenhum destas policies porque
-- não chega aqui: passa pela Edge Function, que valida o token e escreve com
-- `service_role`. Do lado da app, isto é matéria do gestor — um colaborador
-- não tem que ver a massa salarial de cinco anos.
alter table public.punho_rubricas_contabilista enable row level security;
alter table public.punho_convites_contabilista enable row level security;
alter table public.punho_respostas_contabilista enable row level security;
alter table public.punho_alteracoes_contabilista enable row level security;
alter table public.punho_mensagens_contabilista enable row level security;

-- O catálogo não tem nada de secreto e a app precisa dele para desenhar os
-- ecrãs: leitura para quem tem sessão, escrita só por migração.
drop policy if exists catalogo_legivel on public.punho_rubricas_contabilista;
create policy catalogo_legivel on public.punho_rubricas_contabilista
  for select to authenticated
  using (true);

drop policy if exists empresa_gestor on public.punho_convites_contabilista;
create policy empresa_gestor on public.punho_convites_contabilista
  for all to authenticated
  using (empresa_id = punho_empresa_atual() and punho_e_gestor())
  with check (empresa_id = punho_empresa_atual() and punho_e_gestor());

drop policy if exists empresa_gestor on public.punho_respostas_contabilista;
create policy empresa_gestor on public.punho_respostas_contabilista
  for all to authenticated
  using (empresa_id = punho_empresa_atual() and punho_e_gestor())
  with check (empresa_id = punho_empresa_atual() and punho_e_gestor());

drop policy if exists empresa_gestor on public.punho_mensagens_contabilista;
create policy empresa_gestor on public.punho_mensagens_contabilista
  for all to authenticated
  using (empresa_id = punho_empresa_atual() and punho_e_gestor())
  with check (empresa_id = punho_empresa_atual() and punho_e_gestor());

-- Auditoria só se lê. Nem o gestor reescreve o histórico das correcções —
-- é a única coisa aqui que tem de ser verdade mesmo quando desagrada.
drop policy if exists empresa_gestor_le on public.punho_alteracoes_contabilista;
create policy empresa_gestor_le on public.punho_alteracoes_contabilista
  for select to authenticated
  using (empresa_id = punho_empresa_atual() and punho_e_gestor());
