-- A última linha de defesa das regras de negócio.
--
-- Tudo o que a app grava passa por `punho_operacoes.payload` (jsonb livre), e
-- até aqui o servidor aceitava o que lá viesse: uma reserva a acabar antes de
-- começar, um recebimento negativo, um preço/dia abaixo de zero. A UI valida,
-- mas a UI é a primeira linha e nunca pode ser a última — quem chama a API não
-- é obrigado a passar por ela.
--
-- Trigger e não `check constraint`: validar datas obriga a converter texto para
-- `timestamptz`, e essa conversão depende do fuso — não é imutável, que é o que
-- um `check` exige. O trigger não tem essa limitação.
--
-- **`errcode` 23514 de propósito**: é assim que o cliente distingue uma recusa
-- permanente (este payload nunca vai ser aceite, por muito que insista) de uma
-- falha de rede (vale a pena tentar outra vez). Sem essa distinção, uma única
-- operação malformada prendia a fila inteira a reenviar para sempre — foi
-- exactamente o que aconteceu à ficha de empresa com NIF inválido na Faixa D.
create or replace function public.punho_validar_payload_operacao()
returns trigger
language plpgsql
as $$
declare
  inicio timestamptz;
  fim timestamptz;
  valor numeric;
  chave text;
begin
  if new.entidade = 'booking'
     and new.payload ? 'startsAt' and new.payload ? 'endsAt' then
    begin
      inicio := (new.payload->>'startsAt')::timestamptz;
      fim := (new.payload->>'endsAt')::timestamptz;
    exception when others then
      raise exception 'punho: datas da reserva ilegíveis'
        using errcode = '23514';
    end;
    if fim <= inicio then
      raise exception 'punho: uma reserva não pode acabar antes de começar'
        using errcode = '23514';
    end if;
  end if;

  -- Dinheiro nunca é negativo neste domínio. Uma despesa é uma saída, mas o
  -- valor guardado é a grandeza — o sinal está na natureza do registo, não no
  -- número. Um valor negativo aqui é sempre erro, e envenena todos os KPIs
  -- que somam sem olhar.
  foreach chave in array array[
    'amountCents', 'dailyRateCents', 'purchasePriceCents', 'expectedValueCents'
  ] loop
    -- Só valida o que existe e é número: fichas antigas não têm estes campos,
    -- e uma app velha não pode deixar de sincronizar por isso.
    if new.payload ? chave and jsonb_typeof(new.payload->chave) = 'number' then
      valor := (new.payload->>chave)::numeric;
      if valor < 0 then
        raise exception 'punho: % não pode ser negativo (recebido %)',
          chave, valor using errcode = '23514';
      end if;
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists punho_operacoes_payload_coerente on public.punho_operacoes;
create trigger punho_operacoes_payload_coerente
  before insert or update on public.punho_operacoes
  for each row execute function public.punho_validar_payload_operacao();
