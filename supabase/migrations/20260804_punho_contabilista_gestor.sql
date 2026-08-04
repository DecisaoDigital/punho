-- ---------------------------------------------------------------------------
-- Portal do contabilista — o lado de dentro
-- ---------------------------------------------------------------------------
--
-- `20260804_punho_contabilista.sql` montou a base e a porta por onde o
-- contabilista escreve. Falta o que a app precisa: criar o convite e deixar o
-- gestor escrever no mesmo sítio.
--
-- São duas funções e nenhuma tabela nova.

-- ---------------------------------------------------------------------------
-- 1. Criar o convite
-- ---------------------------------------------------------------------------
--
-- O token nasce aqui e é **a única vez que existe em claro**. A base guarda o
-- `sha256`; o valor devolvido vive o tempo de chegar ao ecrã, e depois só na
-- mensagem que o gestor enviar. Quem perder o link não o recupera — gera outro,
-- e é por isso que gerar outro tem de revogar o anterior: um link perdido que
-- continuasse a abrir era um link perdido a escrever na contabilidade.
--
-- A revogação é por email, não por empresa. Duas empresas de contabilidade
-- diferentes a preencher a mesma empresa é raro, mas legítimo; matar o convite
-- de uma porque se emitiu outro à outra não.
--
-- `p_anos` decide a janela. Cinco por omissão, que é o que o César pediu, e
-- termina no **mês passado**: o mês corrente ainda está a acontecer e o
-- contabilista não o tem fechado.
create or replace function public.punho_criar_convite_contabilista(
  p_nome text default null,
  p_email text default null,
  p_anos integer default 5
)
returns table (
  token text,
  convite_id uuid,
  mes_inicial date,
  mes_final date,
  expira_em timestamptz
)
language plpgsql
security definer
-- `extensions` e não só `public`: é lá que vive o `pgcrypto` deste projecto, e
-- sem isso `gen_random_bytes` e `digest` não resolvem. Ver
-- `20260804_punho_pgcrypto_no_search_path.sql` — foi assim que o convite de
-- colaborador esteve partido.
set search_path = public, extensions
as $$
declare
  v_empresa uuid;
  v_token text;
  v_email text := nullif(btrim(lower(coalesce(p_email, ''))), '');
  v_final date := (date_trunc('month', now()) - interval '1 month')::date;
  v_inicial date;
  v_id uuid;
  v_expira timestamptz;
begin
  if not public.punho_e_gestor() then
    raise exception 'Só um gestor aprovado pode convidar o contabilista.'
      using errcode = 'P0001';
  end if;

  v_empresa := public.punho_empresa_atual();
  if v_empresa is null then
    raise exception 'Conta sem empresa activa.' using errcode = 'P0001';
  end if;

  if p_anos is null or p_anos < 1 or p_anos > 10 then
    raise exception 'O período tem de ser entre 1 e 10 anos.'
      using errcode = 'P0001';
  end if;

  v_inicial := (v_final - make_interval(months => p_anos * 12 - 1))::date;

  -- Emitir um convite novo para o mesmo contabilista fecha o anterior. O que
  -- ele já escreveu fica: as respostas são da empresa, não do convite.
  if v_email is not null then
    update public.punho_convites_contabilista
       set revogado_em = now()
     where empresa_id = v_empresa
       and lower(email) = v_email
       and revogado_em is null;
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');

  insert into public.punho_convites_contabilista
    (empresa_id, nome, email, token_hash, mes_inicial, mes_final, criado_por)
  values
    (v_empresa, nullif(btrim(coalesce(p_nome, '')), ''), v_email,
     encode(digest(v_token, 'sha256'), 'hex'), v_inicial, v_final, auth.uid())
  returning id, punho_convites_contabilista.expira_em into v_id, v_expira;

  return query select v_token, v_id, v_inicial, v_final, v_expira;
end;
$$;

-- Chamável por quem tem sessão; quem não for gestor leva a excepção acima.
revoke all on function public.punho_criar_convite_contabilista(text, text, integer)
  from public, anon;
grant execute on function public.punho_criar_convite_contabilista(text, text, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. O gestor a escrever no mesmo sítio
-- ---------------------------------------------------------------------------
--
-- Simétrica de `punho_guardar_resposta_contabilista`, e existe pela mesma razão
-- técnica: os índices únicos são parciais e o `on conflict` do PostgREST não
-- sabe exprimir o predicado.
--
-- Três diferenças, todas deliberadas:
--
--  * A empresa vem de `punho_empresa_atual()` — sessão, não corpo do pedido.
--  * `origem = 'gestor'`, e é isso que faz o painel poder dizer de onde veio
--    cada número quando os dois discordarem.
--  * **Não há janela de convite.** O histórico é da empresa; o gestor escreve o
--    mês que quiser. Só o futuro é recusado, porque um mês que ainda não
--    aconteceu não é um dado, é um palpite a entrar por engano.
create or replace function public.punho_guardar_resposta_gestor(
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
  v_empresa uuid;
  afectadas integer;
begin
  if not public.punho_e_gestor() then
    raise exception 'Só um gestor aprovado pode alterar o histórico.'
      using errcode = 'P0001';
  end if;

  v_empresa := public.punho_empresa_atual();
  if v_empresa is null then
    raise exception 'Conta sem empresa activa.' using errcode = 'P0001';
  end if;

  if p_mes is not null and p_mes > date_trunc('month', now())::date then
    raise exception 'Esse mês ainda não aconteceu.' using errcode = '22007';
  end if;

  if p_ano is not null and p_ano > extract(year from now()) then
    raise exception 'Esse ano ainda não aconteceu.' using errcode = '22007';
  end if;

  if p_valor_centavos is null and (p_valor_texto is null or btrim(p_valor_texto) = '') then
    delete from public.punho_respostas_contabilista
     where empresa_id = v_empresa
       and rubrica = p_rubrica
       and mes is not distinct from p_mes
       and ano is not distinct from p_ano;
    return 'apagado';
  end if;

  update public.punho_respostas_contabilista
     set valor_centavos = p_valor_centavos,
         valor_texto = nullif(btrim(p_valor_texto), ''),
         origem = 'gestor',
         convite_id = null
   where empresa_id = v_empresa
     and rubrica = p_rubrica
     and mes is not distinct from p_mes
     and ano is not distinct from p_ano;

  get diagnostics afectadas = row_count;
  if afectadas > 0 then
    return 'actualizado';
  end if;

  insert into public.punho_respostas_contabilista
    (empresa_id, rubrica, mes, ano, valor_centavos, valor_texto, origem)
  values
    (v_empresa, p_rubrica, p_mes, p_ano, p_valor_centavos,
     nullif(btrim(p_valor_texto), ''), 'gestor');

  return 'criado';
end;
$$;

revoke all on function public.punho_guardar_resposta_gestor(
  text, date, integer, bigint, text
) from public, anon;
grant execute on function public.punho_guardar_resposta_gestor(
  text, date, integer, bigint, text
) to authenticated;
