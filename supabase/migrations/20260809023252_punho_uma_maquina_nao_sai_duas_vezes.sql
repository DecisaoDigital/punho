-- Uma máquina não pode estar em dois sítios ao mesmo tempo.
--
-- ## O que se encontrou
--
-- `punho_conflitos_pendentes` tinha três linhas de 8/8/2026, todas do mesmo
-- tipo `reservaMaquina`. Fui ver o que eram:
--
--   b1786146706077779  Maquina1, Maquina2  8/8 08:00 → 17:00
--   b1786146783619457  Maquina1, Maquina2  8/8 08:00 → 17:00
--   b1786148013921213  Maquina1, Maquina2  8/8 08:00 → 17:00
--
-- As mesmas duas máquinas, prometidas três vezes, para a mesma janela. A app
-- do gestor **detectou-o** e escreveu o conflito. Depois disso não há ecrã
-- nenhum que leia esta tabela, e as três linhas ficaram lá quatro dias.
--
-- ## Porque é que o calendário não chega
--
-- A app do operador impede marcar por cima de uma célula ocupada, e há teste
-- para isso. Mas essa verificação é feita contra o que aquele telemóvel leu da
-- última vez. Dois operadores em dois telemóveis, ou o operador e o gestor ao
-- mesmo tempo, lêem os dois «livre» e escrevem os dois. Nenhum está a fazer
-- nada de errado, e o servidor aceita ambos.
--
-- Uma regra que só existe no cliente não é uma regra: é uma sugestão que o
-- primeiro cliente a não a conhecer ignora.
--
-- ## Onde é que a guarda fica
--
-- No carimbo (`before insert` em `punho_operacoes`) e **só quando há sessão**.
-- Não no projector, de propósito: pôr a verificação lá fazia com que qualquer
-- reprojecção — `punho_reservas_em_dia`, `punho_reprojectar_empresa` — passasse
-- a rebentar ao chegar a estas três linhas que já existem. A recuperação de
-- uma projecção atrasada não pode ficar refém de dados antigos que já lá estão.
--
-- Estados que ocupam: `confirmed` e `rented`. Um pedido não ocupa — é
-- precisamente o que ainda não foi prometido —, e `completed` ou `cancelled`
-- já não ocupam. É por isso que se pode marcar para o dia a seguir a uma
-- devolução sem que a app diga que não.

create index if not exists punho_reservas_janela_idx
  on public.punho_reservas (empresa_id, estado, inicio, fim);

create or replace function public.punho_operacoes_carimbar()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_perfil  text;
  v_estado  text;
  v_inicio  timestamptz;
  v_fim     timestamptz;
  v_choque  record;
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
    return new;  -- é o próprio servidor a escrever
  end if;

  v_perfil := punho_perfil_na_empresa(new.empresa_id);

  -- A despesa de um operador é dele.
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

  -- Uma máquina de cada vez.
  if new.entidade = 'booking' then
    v_estado := coalesce(new.payload->>'status', 'request');

    if v_estado in ('confirmed', 'rented')
       and new.payload ? 'startsAt' and new.payload ? 'endsAt' then
      begin
        v_inicio := (new.payload->>'startsAt')::timestamptz;
        v_fim    := (new.payload->>'endsAt')::timestamptz;
      exception when others then
        return new;  -- datas ilegíveis: o gatilho de validação trata disso
      end;

      select r.id_local, r.cliente_nome_snapshot, m.dados->>'name' as maquina
        into v_choque
        from punho_reserva_maquinas rm
        join punho_reservas r on r.id = rm.reserva_id
        join punho_maquinas  m on m.id = rm.maquina_id
       where r.empresa_id = new.empresa_id
         and r.estado in ('confirmed', 'rented')
         -- A própria reserva não choca consigo: mudar-lhe o estado, o valor ou
         -- as notas é escrever outra vez sobre a mesma entidade.
         and r.id_local is distinct from new.entidade_id
         -- Meia-aberto: quem devolve às 17h e quem leva às 17h não chocam.
         and r.inicio < v_fim
         and r.fim    > v_inicio
         and m.id_local in (
           select jsonb_array_elements_text(
             case jsonb_typeof(new.payload->'machineIds')
               when 'array' then new.payload->'machineIds'
               else '[]'::jsonb
             end
           )
         )
       limit 1;

      if found then
        raise exception
          'A % já está com % nessas datas. Escolhe outra máquina ou outras datas.',
          coalesce(v_choque.maquina, 'máquina'),
          coalesce(nullif(btrim(v_choque.cliente_nome_snapshot), ''), 'outra reserva')
          using errcode = '23514';
      end if;
    end if;
  end if;

  return new;
end;
$fn$;

revoke all on function public.punho_operacoes_carimbar() from public, anon, authenticated;
