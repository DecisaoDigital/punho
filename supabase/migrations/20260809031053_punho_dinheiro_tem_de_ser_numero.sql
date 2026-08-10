-- Um valor em dinheiro que não seja um número JSON desaparece calado.
--
-- ## O que se viu, com o token de um gestor a sério
--
--   POST receipt {"amountCents":"500", ...}   → 201  (aceite)
--   punho_recebimentos lê amountCents = "500" (string)
--   punho_cobrancas soma:  case when jsonb_typeof(amountCents)='number'
--                               then ... else 0   → conta 0
--
-- Ou seja: o recibo fica guardado, mas os 5 € **não entram** na reconciliação
-- de cobranças. O cliente continua a dever e a caixa nunca fecha — e não há
-- nada no ecrã que deixe suspeitar porquê. É a mesma perda silenciosa do
-- `1.200` que valia 1,20 €, agora do lado do servidor.
--
-- ## Porque é que a validação deixava passar
--
-- O `punho_validar_payload_operacao` só olhava para o valor **quando já era um
-- número** (`jsonb_typeof = 'number'`), para lhe verificar o sinal. Uma string
-- caía fora do `if` inteiro e escapava. A porta e o leitor discordavam: o
-- leitor só conta números, a porta aceitava qualquer coisa.
--
-- ## A regra
--
-- Se uma chave de dinheiro está presente e não é número nem `null`, recusa-se.
-- `null` continua a valer «não preenchido» (o design diz: em falta = null), e a
-- ausência da chave também. O que deixa de passar é texto, booleano, objecto ou
-- lista onde devia estar um número — precisamente o que hoje se guardava para
-- ser lido como zero.
--
-- Nenhum cliente verdadeiro envia dinheiro em texto: a OP e a app do gestor
-- serializam `int` como número JSON. Isto fecha a porta a um payload
-- adulterado ou a um cliente com bug, não a ninguém que hoje funcione.

create or replace function public.punho_validar_payload_operacao()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  inicio timestamptz;
  fim timestamptz;
  valor numeric;
  chave text;
  tipo text;
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

  foreach chave in array array[
    'amountCents', 'dailyRateCents', 'purchasePriceCents', 'expectedValueCents'
  ] loop
    if new.payload ? chave then
      tipo := jsonb_typeof(new.payload->chave);
      -- `null` e ausência querem dizer «não preenchido» — deixam-se passar.
      if tipo is not null and tipo <> 'null' then
        if tipo <> 'number' then
          raise exception
            'punho: % tem de ser um número, não % (recebido %)',
            chave, tipo, (new.payload->chave)
            using errcode = '23514';
        end if;
        valor := (new.payload->>chave)::numeric;
        if valor < 0 then
          raise exception 'punho: % não pode ser negativo (recebido %)',
            chave, valor using errcode = '23514';
        end if;
      end if;
    end if;
  end loop;

  return new;
end;
$function$;
