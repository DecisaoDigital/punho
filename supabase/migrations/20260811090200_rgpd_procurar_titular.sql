-- Um pedido de apagamento não vem com o id local.
--
-- ## O que a prova mostrou
--
-- Apagou-se `cli-prova-1000204` («Casa Ferreira») e ficou tudo limpo — desse
-- registo. Só que na mesma empresa havia mais **duas** fichas com o mesmo nome,
-- `cli-prova-998368` e `cli-prova-1008527`, e essas ficaram intactas.
--
-- Isto não é um defeito do apagamento; é o que acontece quando a app deixa
-- criar a mesma pessoa três vezes — e deixa, é para isso que existe
-- `punho_conflitos_pendentes`. O problema é o outro lado: quem recebe o pedido
-- («apaguem os dados da Casa Ferreira») não sabe que existem três fichas, e o
-- `punho_apagar_titular` só sabe apagar uma de cada vez.
--
-- Sem isto, a função dá uma resposta que parece completa e não é. É pior do que
-- não ter nada, porque fica escrito em `punho_apagamentos` que se apagou.
--
-- ## O que esta função faz
--
-- Procura por nome, NIF, telefone ou email, em `customer`, `collaborator` e
-- `lead`, e devolve **todas** as fichas que batem certo — já com a marca de
-- quais delas foram apagadas. O gestor vê as três, apaga as três, e o que
-- assina depois é verdade.

create or replace function punho_procurar_titular(p_termo text)
returns table (
  entidade text,
  entidade_id text,
  nome text,
  contacto text,
  revisoes integer,
  ja_apagado boolean
)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_empresa uuid;
  v_termo text;
begin
  if not punho_e_gestor() then
    raise exception 'punho: só o gestor da empresa pode procurar um titular'
      using errcode = '42501';
  end if;

  v_empresa := punho_empresa_atual();
  if v_empresa is null then
    raise exception 'punho: esta sessão não está ligada a nenhuma empresa'
      using errcode = '42501';
  end if;

  v_termo := nullif(trim(coalesce(p_termo, '')), '');
  if v_termo is null then
    raise exception 'punho: falta dizer por quem procurar' using errcode = '22023';
  end if;

  return query
  with ultima as (
    select
      o.entidade,
      o.entidade_id,
      o.payload,
      row_number() over (partition by o.entidade, o.entidade_id order by o.seq desc) as rn,
      count(*) over (partition by o.entidade, o.entidade_id) as revisoes
    from punho_operacoes o
    where o.empresa_id = v_empresa
      and o.entidade in ('customer', 'collaborator', 'lead')
  )
  select
    u.entidade,
    u.entidade_id,
    u.payload->>'name',
    coalesce(u.payload->>'phone', u.payload->>'email', u.payload->>'taxId'),
    u.revisoes::integer,
    (u.payload ? '_apagado_em')
  from ultima u
  where u.rn = 1
    and (
      u.payload->>'name'  ilike '%' || v_termo || '%'
      or u.payload->>'taxId' ilike '%' || v_termo || '%'
      or u.payload->>'phone' ilike '%' || v_termo || '%'
      or u.payload->>'email' ilike '%' || v_termo || '%'
    )
  order by u.entidade, u.payload->>'name', u.entidade_id;
end;
$$;

comment on function punho_procurar_titular(text) is
  'Encontra todas as fichas da mesma pessoa antes de a apagar. A mesma pessoa '
  'pode estar duplicada — apagar uma só dava uma resposta falsa.';

revoke all on function punho_procurar_titular(text) from public;
revoke all on function punho_procurar_titular(text) from anon;
grant execute on function punho_procurar_titular(text) to authenticated;
