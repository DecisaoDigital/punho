-- Fecha as sete tabelas partilhadas com o WashInvoice.
--
-- O que estava mal: `auth.role() = 'authenticated'` não é uma autorização, é
-- uma constatação de que alguém fez login. Qualquer das oito contas do projecto
-- — incluindo um colaborador de uma lavandaria — lia a carteira de clientes com
-- NIF, os IP públicos e o GPS dos terminais, e as provas de aceitação de termos.
-- Em `clientes` a política era `FOR ALL` sem `with_check`, e nesse caso o
-- Postgres reaproveita o `using` para escrever: também alterava.
--
-- As três políticas chamadas `*_admin_read` guardavam a intenção no nome e
-- tinham `using (true)`. O nome nunca chegou a ser escrito em SQL.
--
-- Quem escreve mesmo, levantado ficheiro a ficheiro antes de tocar em nada
-- (docs/PUNHO_MAPA_DE_ACESSOS_2026-08-08.md, revisto a 10/08 com as 16 edge
-- functions já em repositório):
--
--   clientes ......................  Control, e `sincronizar-empresa` com
--                                    service_role — que ignora RLS
--   licencas_audit ................  `assinar-licenca` e `gerir-licenca`, ambas
--                                    com service_role
--   pings, aceites_termos .........  o POS e o Punho, ANÓNIMOS, por PostgREST
--                                    directo. O POS não tem conta nenhuma em
--                                    auth.users; este é o único caminho que tem
--   pedidos_renovacao .............  ninguém, nunca. Zero linhas desde sempre
--   company_signature_settings,
--   invoice_signature_logs ........  ninguém no código que existe hoje
--
-- Daí a assimetria que se segue: o INSERT anónimo fica de pé em `pings` e
-- `aceites_termos` porque tirá-lo cega os seis terminais, e cai em todo o resto.
-- A dívida que isso deixa em aberto — qualquer um forja uma aceitação de termos
-- com o machine_id de outro — está em docs/LIMITACOES_CONHECIDAS.md, com a
-- solução e a data em que passa a ser urgente.
--
-- Cinto e suspensórios: além das políticas, revogam-se os GRANT ao papel `anon`.
-- Uma política só é avaliada depois de o privilégio de tabela passar; sem GRANT,
-- o pedido morre antes. Revoga-se também TRUNCATE a toda a gente — TRUNCATE não
-- passa por RLS, é a única porta que uma política nunca fecharia.

-- ---------------------------------------------------------------- clientes --
drop policy if exists all_clientes on public.clientes;

create policy clientes_admin_tudo on public.clientes
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

revoke all on public.clientes from anon;
revoke truncate, trigger, references on public.clientes from authenticated;
grant select, insert, update, delete on public.clientes to authenticated;

-- ------------------------------------------------------------------- pings --
-- INSERT anónimo mantém-se: é assim que os terminais reportam que estão vivos.
drop policy if exists select_pings on public.pings;

create policy pings_admin_le on public.pings
  for select to authenticated
  using (public.is_admin());

revoke all on public.pings from anon;
grant insert on public.pings to anon;
revoke truncate, trigger, references on public.pings from authenticated;

-- ---------------------------------------------------------- aceites_termos --
drop policy if exists select_termos on public.aceites_termos;

create policy aceites_termos_admin_le on public.aceites_termos
  for select to authenticated
  using (public.is_admin());

revoke all on public.aceites_termos from anon;
grant insert on public.aceites_termos to anon;
revoke truncate, trigger, references on public.aceites_termos from authenticated;

-- ------------------------------------------------------- pedidos_renovacao --
-- Fecha inteira, INSERT incluído. Nunca teve uma linha; se houver código no POS
-- à espera desta porta, mais vale que falhe alto agora — enquanto os dados são
-- todos de teste — do que ficar aberta sem ninguém saber para quê.
drop policy if exists insert_pedidos on public.pedidos_renovacao;
drop policy if exists select_pedidos on public.pedidos_renovacao;
drop policy if exists update_pedidos on public.pedidos_renovacao;

create policy pedidos_renovacao_admin_tudo on public.pedidos_renovacao
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

revoke all on public.pedidos_renovacao from anon;
revoke truncate, trigger, references on public.pedidos_renovacao from authenticated;
grant select, insert, update, delete on public.pedidos_renovacao to authenticated;

-- ----------------------------------- as três que só o service_role escreve --
-- Leitura de admin, e mais nada. Quem as alimenta é `assinar-licenca` e
-- `gerir-licenca` com service_role, que não passa por aqui.
drop policy if exists licencas_audit_admin_read on public.licencas_audit;
drop policy if exists company_signature_settings_admin_read on public.company_signature_settings;
drop policy if exists invoice_signature_logs_admin_read on public.invoice_signature_logs;

create policy licencas_audit_admin_le on public.licencas_audit
  for select to authenticated
  using (public.is_admin());

create policy company_signature_settings_admin_le on public.company_signature_settings
  for select to authenticated
  using (public.is_admin());

create policy invoice_signature_logs_admin_le on public.invoice_signature_logs
  for select to authenticated
  using (public.is_admin());

revoke all on public.licencas_audit from anon, authenticated;
revoke all on public.company_signature_settings from anon, authenticated;
revoke all on public.invoice_signature_logs from anon, authenticated;

grant select on public.licencas_audit to authenticated;
grant select on public.company_signature_settings to authenticated;
grant select on public.invoice_signature_logs to authenticated;
