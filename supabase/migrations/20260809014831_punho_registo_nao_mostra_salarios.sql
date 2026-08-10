-- O registo mostrava salários a quem a tabela escondia.
--
-- `punho_colaboradores` é só-gestor desde sempre. Mas o payload das operações
-- `collaborator` traz `costCents`, `socialSecurityNumber`, `taxId`,
-- `dependents` e `maritalStatus` — e a política de leitura de
-- `punho_operacoes` só excluía `expense`. Ou seja: qualquer operador com sessão
-- iniciada podia pedir `punho_operacoes?entidade=eq.collaborator` e ler o
-- salário, o NIF e a segurança social de todos os colegas.
--
-- A porta da tabela estava fechada; a do registo, que tem exactamente os mesmos
-- dados, estava aberta. Descoberto a 9/8/2026, ao preparar a passagem das
-- tabelas derivadas a vistas — que teria herdado o buraco em vez de o criar.
--
-- `vehicle` vai no mesmo lote pela mesma razão: a tabela é só-gestor.

drop policy if exists punho_operacoes_membro_le on public.punho_operacoes;

create policy punho_operacoes_membro_le on public.punho_operacoes
  for select
  using (
    case public.punho_perfil_na_empresa(empresa_id)
      when 'gestor' then true
      -- O operador precisa de clientes, máquinas, reservas, leads e
      -- recebimentos para trabalhar. Não precisa das contas da empresa nem das
      -- fichas de pessoal, e são essas que doem se saírem.
      when 'colaborador' then entidade not in ('expense', 'vehicle', 'collaborator')
      else false
    end
  );

-- Um registo que aceita apagar não é um registo.
--
-- `authenticated` tinha DELETE e TRUNCATE nesta tabela por omissão do Supabase.
-- O RLS tapa o DELETE (não há política, logo não passa), mas **TRUNCATE não é
-- abrangido por RLS de todo** — é só privilégio de tabela. Não é alcançável
-- pela API REST, mas é uma porta sem fechadura e não há motivo para existir.
--
-- UPDATE fica por agora: o cliente ainda manda `upsert` com `on conflict do
-- update`, e o Postgres exige o privilégio em tempo de planeamento mesmo quando
-- não há conflito. Sai quando a app passar a `do nothing` — ver
-- 20260809140000_punho_reservas_com_posicao.sql.
revoke delete, truncate on public.punho_operacoes from anon, authenticated;
