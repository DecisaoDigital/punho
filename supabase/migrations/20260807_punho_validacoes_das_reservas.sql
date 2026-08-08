-- =============================================================================
-- As validações das reservas deixam de bloquear a projecção.
-- =============================================================================
--
-- As quatro validações em `punho_reservas` e `punho_reserva_maquinas` foram
-- escritas para um mundo em que o telemóvel escrevia nestas tabelas
-- directamente. Já não escreve: quem escreve é a projecção
-- (`20260807_punho_projeccao_das_tabelas.sql`), e o que ela põe cá é uma cópia
-- fiel do que está no registo de operações.
--
-- Uma validação que recusa a projecção não protege dado nenhum. O que faz é
-- afastar a tabela de leitura da verdade — e a verdade fica na mesma no
-- registo, agora sem ninguém a conseguir lê-la.
--
-- REFERÊNCIAS: passam a tolerar o que ainda não chegou
-- ---------------------------------------------------
-- O registo não promete ordem entre entidades. Um telemóvel que esteve sem rede
-- sobe o lote todo de uma vez e a reserva pode chegar antes do cliente. Exigir
-- que o cliente já exista transformava isso em "este telemóvel não sincroniza".
--
-- O que se mantém é o que interessa: se a linha **existir**, tem de ser da mesma
-- empresa. Empresas cruzadas continuam a rebentar; ordem de chegada não.
--
-- (Na prática os ids derivam de `md5(empresa_id || ':' || id_local)`, portanto
-- um cliente calculado para uma empresa nunca calha num registo de outra. Fica
-- a verificação na mesma — uma garantia que só existe por aritmética é uma
-- garantia que se perde na próxima vez que se mexer na aritmética.)
--
-- CONFLITOS: saem
-- ---------------
-- `punho_reserva_conflito_ao_ativar` e `punho_reserva_conflict` recusam gravar
-- uma reserva que se sobreponha a outra na mesma máquina.
--
-- **Quem decide uma sobreposição é o gestor.** Nem o servidor nem a app:
-- `_detectarConflitoDeReserva` não escolhe vencedor nenhum — regista a disputa
-- em `punho_conflitos_pendentes` e é o gestor que a resolve. Duas máquinas
-- prometidas ao mesmo tempo são um problema de negócio, e quem tem de o
-- resolver é quem responde ao cliente que fica sem giratória.
--
-- Por isso o servidor tem de **aceitar as duas** e deixá-las chegar ao gestor.
-- A recusar a escrita não resolvia o conflito: perdia a segunda reserva, e o
-- gestor nunca chegava a saber que houve uma disputa para decidir.
--
-- Hoje nem sequer disparam — comparam contra `'confirmada'` e `'em_aluguer'`, e
-- a app escreve `'confirmed'` e `'rented'`. Ficarem inertes é pior do que
-- saírem: quem um dia traduzisse os estados punha-os a recusar reservas sem
-- perceber de onde vinha.

-- -----------------------------------------------------------------------------
-- Referências: existir noutra empresa é erro; ainda não existir não é.
-- -----------------------------------------------------------------------------
create or replace function public.punho_validar_referencias_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cliente_empresa     uuid;
  colaborador_empresa uuid;
begin
  select empresa_id into cliente_empresa
  from punho_clientes where id = new.cliente_id;
  if cliente_empresa is not null and cliente_empresa <> new.empresa_id then
    raise exception 'O cliente tem de pertencer à mesma empresa da reserva.';
  end if;

  -- `punho_colaboradores` e não `punho_membros`: o responsável por uma reserva é
  -- o colaborador do negócio, que pode nem ter conta para entrar na app. Com a
  -- procura na tabela errada, qualquer reserva com responsável era recusada.
  if new.colaborador_responsavel_id is not null then
    select empresa_id into colaborador_empresa
    from punho_colaboradores where id = new.colaborador_responsavel_id;
    if colaborador_empresa is not null
       and colaborador_empresa <> new.empresa_id then
      raise exception 'O colaborador tem de pertencer à mesma empresa da reserva.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.punho_validar_maquina_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  empresa_reserva uuid;
  empresa_maquina uuid;
begin
  select empresa_id into empresa_reserva from punho_reservas where id = new.reserva_id;
  select empresa_id into empresa_maquina from punho_maquinas where id = new.maquina_id;
  if empresa_reserva is not null
     and empresa_maquina is not null
     and empresa_reserva <> empresa_maquina then
    raise exception 'A máquina tem de pertencer à mesma empresa da reserva.';
  end if;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Conflitos: quem decide é uma pessoa, na app.
-- -----------------------------------------------------------------------------
drop trigger if exists punho_reserva_conflito_ao_ativar on public.punho_reservas;
drop trigger if exists punho_reserva_conflict on public.punho_reserva_maquinas;
drop function if exists public.punho_validar_conflito_ao_ativar_reserva();
drop function if exists public.punho_validar_conflito_reserva();
