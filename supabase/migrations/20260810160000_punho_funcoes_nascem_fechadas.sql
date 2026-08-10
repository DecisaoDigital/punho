-- =============================================================================
-- As funções deixam de nascer abertas.
-- =============================================================================
--
-- ── O sintoma, três vezes ────────────────────────────────────────────────────
--
-- Uma função `security definer` que recebe um identificador como argumento e é
-- executável por qualquer sessão é uma porta para os dados de outra empresa.
-- Aconteceu três vezes em três dias:
--
--   * 8 Ago — as funções de projecção (`punho_projectar_entidade`,
--     `punho_reprojectar_empresa`), fechadas à mão depois de aplicadas;
--   * 9 Ago — `punho_colaborador_pode_escrever`;
--   * 10 Ago — `punho_migrar_entidades_do_instantaneo`, corrigida em
--     `20260810153000` minutos depois de aplicada, e só porque se correram os
--     advisors.
--
-- Correr os advisors a seguir a cada migration trata o sintoma. Isto trata a
-- causa: a partir daqui, uma função nova nasce sem EXECUTE para ninguém a não
-- ser `postgres` e `service_role`. Quem quiser abri-la tem de o escrever.
--
-- ── Porque é que `revoke ... from public` não chegava ────────────────────────
--
-- Há DUAS fontes de EXECUTE por omissão, não uma:
--
--   1. o Postgres dá EXECUTE a **PUBLIC** em cada `create function` (no ACL
--      vê-se como `=X/postgres` — um `=X` sem papel à esquerda é PUBLIC);
--   2. a Supabase tem um `pg_default_acl` próprio, declarado para o papel
--      `postgres` e para o schema `public`, que dá EXECUTE a **anon**,
--      **authenticated** e **service_role** em cada função criada. É de lá que
--      vêm os `anon=X/postgres` que se vêem em quase todas as funções.
--
-- Revogar só de PUBLIC deixava a segunda fonte de pé, e as funções continuavam
-- a nascer abertas a `anon`. Daí `from public, anon, authenticated`.
--
-- `service_role` fica: é a chave secreta das edge functions, nunca sai do
-- servidor, e mantê-la por omissão poupa um grant a cada função de serviço.
--
-- ── Papel para quem se declara o default ────────────────────────────────────
--
-- `postgres`. É quem corre as migrations (confirmado: `current_user` =
-- `session_user` = `postgres`). Há uma segunda linha em `pg_default_acl` para
-- `supabase_admin`, mas essa só vale para objectos criados por eles, e
-- `postgres` não é membro desse papel — não lhe podemos nem precisamos tocar.
--
-- ── Duas armadilhas que este ficheiro respeita ──────────────────────────────
--
-- 1. **Políticas RLS.** As expressões de uma policy correm com os privilégios
--    de quem consulta. Uma função referida numa policy que o papel não possa
--    executar dá `permission denied for function` em vez de «vazio» — e a app
--    morre inteira, não um bocado dela.
--
-- 2. **Vistas `security_invoker`.** O mesmo, sem aviso nenhum e sem aparecer em
--    `pg_policies`: `punho_id_estavel` está no corpo das sete vistas do painel
--    (`punho_maquinas`, `punho_clientes`, `punho_leads`, `punho_despesas`,
--    `punho_recebimentos`, `punho_veiculos`, `punho_colaboradores`). Fechá-la a
--    `authenticated` matava as sete listas. Fica escrito num `comment on
--    function`, no fim deste ficheiro, para quem olhar antes de revogar.
--
-- A terceira armadilha desta forma será noutro sítio qualquer. Antes de fechar
-- uma função, procurá-la em `pg_policies`, em `pg_get_viewdef` e no corpo das
-- outras funções — a consulta está no cabeçalho de
-- `supabase/tests/rls_funcoes_fechadas.sql`.
--
-- ── Como se desfaz ───────────────────────────────────────────────────────────
--
--   grant execute on all functions in schema public to anon, authenticated;
--   alter default privileges in schema public
--     grant execute on functions to anon, authenticated;
--
-- (Não repõe o EXECUTE de PUBLIC, e não deve: PUBLIC nunca foi uma decisão de
-- ninguém, era o valor de fábrica. Se mesmo assim for preciso:
-- `grant execute on all functions in schema public to public;`.)
--
-- Nenhum dado é tocado. Isto são privilégios de execução e mais nada — nem uma
-- política, nem um gatilho, nem uma linha.
--
-- ── O que fica pendente, e é tarefa própria ─────────────────────────────────
--
-- Cinco funções ficam executáveis por `anon`, e a causa não são elas: são as
-- políticas com `roles = {public}` que as referem. Enquanto a policy servir
-- PUBLIC, o `anon` tem de poder executar o que ela chama. Passá-las a
-- `to authenticated` fecha as cinco de uma vez — mexe em políticas e exige o
-- smoke de isolamento a correr por cima, portanto não é aqui.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Fechar tudo
-- -----------------------------------------------------------------------------
-- Todas as funções de `public` são nossas: nenhuma extensão vive neste schema
-- (pgcrypto, uuid-ossp, pg_net e pg_stat_statements estão em `extensions`) e
-- todas têm `postgres` por dono. A varredura não apanha nada de terceiros.
--
-- Funções de gatilho também levam com o revoke, e não faz mal: o Postgres
-- confere o EXECUTE de uma função de gatilho quando o gatilho é CRIADO, não
-- quando dispara.

revoke execute on all functions in schema public from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Reabrir, uma a uma, só a quem precisa
-- -----------------------------------------------------------------------------
-- Esta lista é a fronteira pública da base de dados. Uma função que não esteja
-- aqui não é chamável por nenhum cliente — e é isso que se quer.
--
-- Quem falta de propósito: `punho_projectar_entidade`,
-- `punho_reprojectar_empresa`, `punho_migrar_entidades_do_instantaneo`,
-- `punho_criar_empresa_inicial`, `ler_secret_at`, `gerar_chave_mestre`,
-- `obter_ou_criar_chave_mestre`, `punho_definir_periodo_contabilista`,
-- `punho_guardar_resposta_contabilista` — todas de serviço, todas alcançáveis
-- por `service_role`, nenhuma com razão para estar ao alcance de um telemóvel.

-- ── anon: as cinco de identidade ────────────────────────────────────────────
-- Quatro delas não recebem argumentos e derivam tudo de `auth.uid()`; para uma
-- sessão anónima devolvem null ou false. Estão abertas a `anon` porque as
-- políticas que as referem servem `{public}` — ver o pendente no cabeçalho.
grant execute on function public.punho_empresa_atual()             to anon, authenticated;
grant execute on function public.punho_e_gestor()                  to anon, authenticated;
grant execute on function public.punho_membro_ativo()              to anon, authenticated;
grant execute on function public.punho_perfil_na_empresa(uuid)     to anon, authenticated;

-- Esta é diferente: é chamada **antes do `signUp`**, em `registo_screen.dart`,
-- para dar a razão concreta de um código imprestável em vez do erro genérico
-- do gatilho. Sem `anon`, o registo com convite parte.
grant execute on function public.punho_validar_convite(text)       to anon, authenticated;

-- ── Punho (gestor), por RPC ─────────────────────────────────────────────────
grant execute on function public.punho_meu_acesso()                                    to authenticated;
grant execute on function public.punho_pedir_acesso(text, text, text, text, text)      to authenticated;
grant execute on function public.punho_criar_convite(text, text)                       to authenticated;
grant execute on function public.punho_guardar_estado_operacional(jsonb, integer)      to authenticated;
grant execute on function public.punho_painel_gravar(jsonb, timestamptz)               to authenticated;
grant execute on function public.punho_pedidos_da_minha_empresa()                      to authenticated;
grant execute on function public.punho_pedidos_decididos_da_minha_empresa()            to authenticated;
grant execute on function public.punho_gestor_decidir_pedido(uuid, text, text)         to authenticated;
grant execute on function public.punho_criar_convite_contabilista(text, text, integer) to authenticated;
grant execute on function public.punho_lacunas_contabilista(uuid)                      to authenticated;
grant execute on function public.punho_guardar_resposta_gestor(text, date, integer, bigint, text) to authenticated;

-- ── Punho OP (operador), por RPC ────────────────────────────────────────────
-- O terceiro cliente. Faltou-lhe a conta na primeira leitura e teria fechado
-- duas funções que ele chama todos os dias.
grant execute on function public.punho_guardar_o_meu_perfil(text, text) to authenticated;
grant execute on function public.punho_reservas_em_dia()                to authenticated;

-- ── Control (admin), por RPC ────────────────────────────────────────────────
-- Mesmo projecto Supabase, mesmo schema. Fechar aqui parte o Control.
grant execute on function public.is_admin()                                     to authenticated;
grant execute on function public.meu_estado_acesso()                            to authenticated;
grant execute on function public.criar_convite_organizacao(text, text)          to authenticated;
grant execute on function public.decidir_pedido_acesso(uuid, text, uuid)        to authenticated;
grant execute on function public.apagar_pedido_acesso(uuid)                     to authenticated;
grant execute on function public.apagar_licenca(uuid)                           to authenticated;
grant execute on function public.licenca_dependentes(uuid)                      to authenticated;
grant execute on function public.punho_apagar_pedido(uuid)                      to authenticated;
grant execute on function public.punho_decidir_pedido(uuid, text, uuid, integer) to authenticated;
grant execute on function public.punho_definir_limite(uuid, integer)            to authenticated;
grant execute on function public.punho_listar_empresas_admin()                  to authenticated;
grant execute on function public.punho_listar_pedidos_admin(text)               to authenticated;
grant execute on function public.punho_nomes_por_terminal()                     to authenticated;

-- ── Referidas dentro de políticas e de vistas ───────────────────────────────
-- Ninguém as chama por RPC. Se fecharem, a RLS deixa de poder ser avaliada.
grant execute on function public.punho_colaborador_pode_escrever(text, jsonb) to authenticated;  -- policy em punho_operacoes
grant execute on function public.punho_nome_empresa_atual()                   to authenticated;  -- policy em punho_pedidos_acesso
grant execute on function public.punho_id_estavel(uuid, text)                 to authenticated;  -- SETE vistas security_invoker

-- ── Compatibilidade com o que já está instalado ─────────────────────────────
-- Substituída por `punho_meu_acesso` a 5 de Agosto, e desde então não é
-- chamada por nenhum dos três repositórios. Mas um APK que já esteja num
-- telemóvel pode ser da versão anterior, e um cliente que não entra na app é
-- um telefonema. Custo de a manter: zero — não recebe argumentos e devolve o
-- estado de quem pergunta. Tirar quando não houver instalações antigas.
grant execute on function public.punho_meu_estado_acesso() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. E o que fecha isto para sempre
-- -----------------------------------------------------------------------------
-- Sem esta linha, o ficheiro inteiro é uma limpeza pontual: a função seguinte
-- volta a nascer aberta e volta a ser preciso um advisor para dar por ela.

alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. A armadilha, onde quem revoga a vai ver
-- -----------------------------------------------------------------------------
comment on function public.punho_id_estavel(uuid, text) is
  'Id determinístico de uma entidade (empresa + id local). ATENÇÃO ANTES DE '
  'REVOGAR: está no corpo das SETE vistas security_invoker do painel — '
  'punho_maquinas, punho_clientes, punho_leads, punho_despesas, '
  'punho_recebimentos, punho_veiculos, punho_colaboradores. Uma vista invoker '
  'avalia-se com os privilégios de quem consulta, portanto `authenticated` '
  'precisa de EXECUTE aqui. Não aparece em pg_policies: quem procurar a '
  'dependência só nas políticas não a encontra.';
