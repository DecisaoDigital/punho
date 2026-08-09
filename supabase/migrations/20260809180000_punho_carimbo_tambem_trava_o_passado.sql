-- O carimbo travava o futuro e deixava passar o passado.
--
-- Apanhado a verificar a própria migração anterior: com o `por_utilizador` já
-- forçado, o mesmo pedido com `feito_em: 2020-01-01` continuou a entrar, e a
-- vista passou a mostrar `created_at` de 2020 para um cliente criado hoje. Meia
-- correcção não é correcção.
--
-- Porque é que não se força `feito_em := now()` e acabou: a fila offline. O
-- operador regista às 9h, no escritório, o que fez às 7h no estaleiro sem rede,
-- e essa é a hora que interessa ao gestor. A data do cliente é uma alegação
-- legítima — o que não é legítimo é uma alegação sem limite.
--
-- Sete dias. A fila mede-se em horas: é um telemóvel sem rede, não um arquivo.
-- Um aparelho desligado três semanas continua a conseguir enviar tudo; o que
-- perde é a pretensão de escolher a data. E `recebido_em`, que ninguém escreve,
-- guarda sempre a hora a que o servidor soube.
create or replace function public.punho_operacoes_carimbar()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_perfil text;
begin
  if auth.uid() is not null then
    new.por_utilizador := auth.uid();
  end if;

  new.recebido_em := now();

  if new.feito_em is null
     or new.feito_em > now() + interval '30 minutes'
     or new.feito_em < now() - interval '7 days' then
    new.feito_em := now();
  end if;

  if auth.uid() is null then
    return new;
  end if;

  v_perfil := punho_perfil_na_empresa(new.empresa_id);

  if v_perfil = 'colaborador' and new.entidade = 'expense' then
    if exists (
      select 1 from punho_operacoes o
      where o.empresa_id = new.empresa_id
        and o.entidade = 'expense'
        and o.entidade_id = new.entidade_id
        and o.por_utilizador is distinct from auth.uid()
    ) then
      raise exception 'Essa despesa foi lançada por outra pessoa.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$fn$;

revoke all on function public.punho_operacoes_carimbar() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- «Sem nome» não diz a ninguém quem gastou o dinheiro
-- ---------------------------------------------------------------------------
-- A primeira despesa de teste saiu com `lancada_por: 'Sem nome'`. A conta que a
-- lançou é membro activo mas não tem ficha de empregado (`colaborador_id` nulo)
-- nem perfil preenchido — é uma adesão criada antes de a aprovação passar a
-- criar a ficha.
--
-- O nome existe: está no pedido de acesso, que é onde a pessoa o escreveu.
-- Buscá-lo lá é ir à mesma origem de onde `punho_meu_acesso` já o tira.
create or replace view public.punho_despesas
with (security_invoker = true) as
with ult as (
  select o.empresa_id, o.entidade_id, o.payload, o.feito_em, o.recebido_em, o.seq,
         o.por_utilizador,
         row_number() over (partition by o.empresa_id, o.entidade_id order by o.seq desc) as rn,
         min(o.feito_em) over (partition by o.empresa_id, o.entidade_id) as nasceu_em,
         count(*)       over (partition by o.empresa_id, o.entidade_id) as revisoes,
         first_value(o.por_utilizador) over (
           partition by o.empresa_id, o.entidade_id order by o.seq) as autor
  from public.punho_operacoes o
  where o.entidade = 'expense'
)
select public.punho_id_estavel(u.empresa_id, u.entidade_id) as id,
       u.empresa_id,
       u.autor         as created_by,
       u.feito_em      as updated_at,
       u.nasceu_em     as created_at,
       u.revisoes::int as revision,
       u.payload       as dados,
       u.entidade_id   as id_local,
       coalesce(
         nullif(btrim(c.dados->>'name'), ''),
         nullif(btrim(f.nome), ''),
         nullif(btrim(pa.nome), ''),
         'Sem nome'
       ) as lancada_por,
       u.por_utilizador as lancada_por_user_id,
       u.recebido_em    as recebida_em
from ult u
left join public.punho_membros m
       on m.user_id = u.por_utilizador and m.empresa_id = u.empresa_id
left join public.punho_perfis f
       on f.user_id = u.por_utilizador
left join public.punho_pedidos_acesso pa
       on pa.user_id = u.por_utilizador
left join public.punho_colaboradores c
       on c.id = m.colaborador_id
where u.rn = 1;

grant select on public.punho_despesas to authenticated;
