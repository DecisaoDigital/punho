-- O resto do achado 2.2 — e a razão por que ele não tinha ficado fechado.
--
-- A migração de 11/8 (`anon_deixa_de_ter_a_chave_da_porta`) revogou os GRANT do
-- `anon` em 25 tabelas, escritas à mão numa lista. Ao verificar o resultado da
-- migração seguinte, a sonda mostrou o que a lista tinha deixado para trás:
-- **mais ~20 tabelas onde o `anon` continuava com INSERT, UPDATE, DELETE e
-- TRUNCATE** — `punho_operacoes`, `punho_clientes`, `punho_despesas`,
-- `punho_reservas`, `punho_documentos`, `punho_recebimentos`, entre outras.
--
-- Não havia buraco aberto: a RLS recusa na mesma, e é ela que manda. Mas é
-- exactamente a defesa em profundidade que o 2.2 existia para pôr — uma
-- política mal escrita amanhã encontra a porta destrancada.
--
-- ## Porquê por varrimento e não por lista
--
-- A lista à mão é que falhou. Aqui revoga-se de **todas** as relações do
-- esquema e devolve-se depois, à unha, o mínimo que o anónimo precisa. Assim
-- não há tabela que escape por distracção, e uma tabela nova nasce fechada.
--
-- ## O que o anónimo continua a poder fazer, e porquê
--
--   pings           INSERT  telemetria de terminal, antes de haver sessão
--   punho_erros     INSERT  relatório de erro — precisa de funcionar
--                           precisamente quando a app está partida
--   aceites_termos  INSERT  aceitação de termos no primeiro arranque
--   sugestoes       INSERT  caixa de sugestões partilhada com o WashInvoice
--   pedidos_ajuda   INSERT  pedido de ajuda a partir de um terminal
--
-- Todas elas já tinham política `to anon` a dizer o mesmo. O que mudou é que os
-- GRANT deixaram de dizer mais do que a política.
--
-- Repare-se no que **não** está na lista: nenhuma leitura. O anónimo passa a
-- poder escrever nestas cinco e mais nada em lado nenhum.

do $$
declare r record;
begin
  for r in
    select c.oid::regclass as rel
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r','v','m','p')   -- tabelas, vistas, materializadas, partições
  loop
    execute format('revoke all on table %s from anon', r.rel);
  end loop;
end $$;

grant insert on table public.pings          to anon;
grant insert on table public.punho_erros    to anon;
grant insert on table public.aceites_termos to anon;
grant insert on table public.sugestoes      to anon;
grant insert on table public.pedidos_ajuda  to anon;

-- A raiz do problema: a Supabase declara que **tudo o que nascer** no esquema
-- public é dado ao anon. Enquanto isto estiver assim, a próxima tabela volta a
-- abrir a porta sozinha e ninguém repara — que é como as ~20 acima apareceram.
alter default privileges in schema public revoke all on tables from anon;
