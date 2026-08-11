-- 62 das 113 linhas de auditoria apontavam para licenças que já não existem.
--
-- ## Como é que se chega aqui
--
-- O `trg_audit_licencas` corre **AFTER DELETE**: apaga-se a licença e a seguir
-- escreve-se a linha de auditoria com `licenca_id = old.id` — um id que, nesse
-- instante, já não corresponde a nada. As linhas anteriores dessa licença
-- (INSERT, UPDATE) ficam órfãs pelo mesmo motivo.
--
-- Não havia chave estrangeira nenhuma a impedir, e por isso ninguém deu por
-- isso. O rasto sobrevivia ao apagamento — mas deixava de se saber de quem era,
-- a não ser abrindo o `antes`/`depois` à mão.
--
-- ## Porque é que a chave estrangeira sozinha não servia
--
-- Uma FK normal partia o apagamento: o trigger é AFTER DELETE, a licença já
-- desapareceu, e a linha de auditoria seria recusada — levando o `DELETE`
-- inteiro atrás. O `apagar_licenca` deixava de funcionar.
--
-- Por isso são duas peças:
--
-- 1. **A identidade passa a estar na linha.** `licenca_machine_id` e
--    `licenca_app` — que é o que identifica um terminal em toda a casa, e não
--    diz o nome nem o contribuinte de ninguém. O `licenca_id` continua a ser o
--    ponteiro; isto é o rasto de quem era, e sobrevive ao apagamento.
--
-- 2. **O ponteiro passa a ser honesto.** FK com `on delete set null`: enquanto
--    a licença existe, aponta para ela a sério; quando é apagada, fica `null`
--    em vez de apontar para o vazio. E o trigger, no DELETE, já escreve `null`
--    — porque nesse momento não há nada para onde apontar.
--
-- Nada se perde: o `id` antigo continua dentro do `antes`/`depois`, que não se
-- toca. O que sai é a mentira de haver ali uma referência.

alter table public.licencas_audit
  add column if not exists licenca_machine_id text,
  add column if not exists licenca_app text;

comment on column public.licencas_audit.licenca_machine_id is
  'De que terminal era a licença. Sobrevive ao apagamento — o licenca_id não.';

-- Backfill do que já lá está: o machine_id sempre esteve dentro do jsonb.
update public.licencas_audit
   set licenca_machine_id = coalesce(
         licenca_machine_id, antes->>'machine_id', depois->>'machine_id'),
       licenca_app = coalesce(licenca_app, antes->>'app', depois->>'app')
 where licenca_machine_id is null
    or licenca_app is null;

-- A coluna `app` é mais nova do que a tabela: as linhas antigas não a têm no
-- jsonb. Enquanto a licença existe, vai-se lá buscá-la.
update public.licencas_audit a
   set licenca_app = l.app
  from public.licencas l
 where a.licenca_id = l.id
   and a.licenca_app is null
   and l.app is not null;

-- Os 62 ponteiros que não apontam para nada. O id continua no jsonb.
update public.licencas_audit a
   set licenca_id = null
 where a.licenca_id is not null
   and not exists (select 1 from public.licencas l where l.id = a.licenca_id);

alter table public.licencas_audit
  drop constraint if exists licencas_audit_licenca_id_fkey;

alter table public.licencas_audit
  add constraint licencas_audit_licenca_id_fkey
  foreign key (licenca_id) references public.licencas (id) on delete set null;

-- Ler o histórico de um terminal deixa de obrigar a abrir o jsonb.
create index if not exists licencas_audit_terminal_idx
  on public.licencas_audit (licenca_machine_id, licenca_app, criado_em desc);

create or replace function public.registar_audit_licenca()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  antes_json jsonb;
  depois_json jsonb;
  campos text[];
begin
  if tg_op = 'INSERT' then
    antes_json := null;
    depois_json := to_jsonb(new);
    campos := null;
  elsif tg_op = 'UPDATE' then
    antes_json := to_jsonb(old);
    depois_json := to_jsonb(new);
    select array_agg(key)
      into campos
      from jsonb_each_text(to_jsonb(new)) n(key, val)
      where n.val is distinct from (antes_json ->> n.key);
    if campos is null or array_length(campos, 1) is null then
      return new;
    end if;
  elsif tg_op = 'DELETE' then
    antes_json := to_jsonb(old);
    depois_json := null;
    campos := null;
  end if;

  insert into public.licencas_audit(
    licenca_id, licenca_machine_id, licenca_app,
    operacao, actor_uid, actor_role, antes, depois, campos_alterados
  )
  values (
    -- No DELETE não há para onde apontar: a licença já não existe. Guardar o
    -- id aqui era o que criava os órfãos.
    case when tg_op = 'DELETE' then null else new.id end,
    case when tg_op = 'DELETE' then old.machine_id else new.machine_id end,
    case when tg_op = 'DELETE' then old.app else new.app end,
    tg_op,
    auth.uid(),
    coalesce(auth.role(), current_user),
    antes_json,
    depois_json,
    campos
  );

  return coalesce(new, old);
end;
$function$;
