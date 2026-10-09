-- Reuniões no calendário de Reservas (Punho, CRM fase 1).
--
-- Uma reunião é uma `booking` com `tipo = 'reuniao'`, sem máquinas. Duas
-- coisas têm de ser garantidas pelo servidor:
--
-- 1. QUEM MARCOU vem do servidor (`criadoPorUid`), como `por_utilizador`: é
--    nessa conta, e só nela, que o alarme toca. O cliente não o escolhe.
--    `tipo` não muda depois de nascer.
-- 2. O colaborador pode remarcar/editar a reunião QUE ELE MARCOU (hora,
--    cliente, aviso, notas, estado). Nas reservas de máquina continua só
--    estado, notas e responsável.
--
-- Retrocompatível: reservas antigas não têm `tipo`; `tipo = 'maquina'`
-- vale o mesmo que ausente (senão cada app nova que reenviasse uma reserva
-- antiga seria recusada por «alterar o tipo»).
-- Aditiva: nenhuma tabela nem coluna muda.

create or replace function public.punho_operacoes_campos_do_colaborador()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_antes     jsonb;
  v_antes_n   jsonb;
  v_depois_n  jsonb;
  v_alterados text[];
  v_proibidos text[];
  v_lista     text;
  v_reuniao   text[] := array[
    'startsAt', 'endsAt', 'customerId', 'customerNameSnapshot',
    'lembreteMinutos', 'notes', 'status', 'criadoPorUid'
  ];
begin
  if auth.uid() is null then
    return new;
  end if;

  if punho_perfil_na_empresa(new.empresa_id) is distinct from 'colaborador' then
    return new;
  end if;

  select o.payload
    into v_antes
    from punho_operacoes o
   where o.entidade   = new.entidade
     and o.empresa_id = new.empresa_id
     and o.entidade_id = new.entidade_id
   order by o.seq desc
   limit 1;

  if v_antes is null then
    if not punho_colaborador_pode_criar(new.entidade) then
      raise exception 'Criar % é do gestor.',
        punho_entidade_no_plural(new.entidade)
        using errcode = '42501';
    end if;
    return new;
  end if;

  v_antes_n  := v_antes;
  v_depois_n := new.payload;
  if new.entidade = 'booking' then
    -- «maquina» é o valor de omissão: igual a ausente.
    if v_antes_n ->> 'tipo' = 'maquina' then
      v_antes_n := v_antes_n - 'tipo';
    end if;
    if v_depois_n ->> 'tipo' = 'maquina' then
      v_depois_n := v_depois_n - 'tipo';
    end if;
  end if;

  v_alterados := punho_campos_alterados(v_antes_n, v_depois_n);

  if punho_colaborador_pode_alterar(new.entidade, v_alterados) then
    return new;
  end if;

  -- A reunião que ele próprio marcou é dele. `tipo` não está na lista: não
  -- muda. Reunião de outra pessoa cai na matriz normal (estado, notas...).
  if new.entidade = 'booking'
     and v_antes ->> 'tipo' = 'reuniao'
     and new.payload ->> 'tipo' = 'reuniao'
     and v_antes ->> 'criadoPorUid' = auth.uid()::text
     and not exists (
       select 1 from unnest(v_alterados) as c where not (c = any(v_reuniao))
     )
  then
    return new;
  end if;

  select array_agg(punho_rotulo_do_campo(c) order by c)
    into v_proibidos
    from unnest(v_alterados) as c
   where not (c = any(punho_colaborador_campos_livres(new.entidade)));

  if new.entidade = 'receipt' then
    raise exception
      'Um recebimento já registado não se altera. Fala com o gestor.'
      using errcode = '42501';
  end if;

  v_lista := array_to_string(v_proibidos, ', ');

  raise exception 'Não podes alterar % %. Isso é do gestor.',
    v_lista, punho_entidade_com_de(new.entidade)
    using errcode = '42501';
end;
$fn$;

revoke all on function public.punho_operacoes_campos_do_colaborador()
  from public, anon, authenticated;

-- O carimbo do autor da reunião. Gatilho próprio para não tocar no
-- `punho_operacoes_carimbar` (já redefinido várias vezes). Dispara depois do
-- `..._campos_do_colaborador` e do `..._carimbo`, antes de
-- `..._payload_coerente`.
create or replace function public.punho_operacoes_carimbar_reuniao()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_antes jsonb;
begin
  if new.entidade <> 'booking' or auth.uid() is null then
    return new;
  end if;

  select o.payload
    into v_antes
    from punho_operacoes o
   where o.entidade   = 'booking'
     and o.empresa_id = new.empresa_id
     and o.entidade_id = new.entidade_id
   order by o.seq desc
   limit 1;

  if v_antes ->> 'tipo' = 'reuniao' then
    -- Já era reunião: o tipo e o autor ficam como estavam.
    new.payload := jsonb_set(new.payload, '{tipo}', '"reuniao"'::jsonb);
    new.payload := jsonb_set(
      new.payload, '{criadoPorUid}',
      coalesce(v_antes -> 'criadoPorUid', to_jsonb(auth.uid()::text))
    );
  elsif v_antes is null and new.payload ->> 'tipo' = 'reuniao' then
    -- Nasce agora: o autor é quem a escreve, diga o cliente o que disser.
    new.payload := jsonb_set(
      new.payload, '{criadoPorUid}', to_jsonb(auth.uid()::text)
    );
  end if;

  return new;
end;
$fn$;

revoke all on function public.punho_operacoes_carimbar_reuniao()
  from public, anon, authenticated;

drop trigger if exists punho_operacoes_carimbo_reuniao on public.punho_operacoes;
create trigger punho_operacoes_carimbo_reuniao
  before insert on public.punho_operacoes
  for each row execute function public.punho_operacoes_carimbar_reuniao();
