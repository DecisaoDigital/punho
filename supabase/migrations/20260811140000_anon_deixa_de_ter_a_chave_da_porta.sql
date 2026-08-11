-- O `anon` tinha INSERT, UPDATE e DELETE em 25 tabelas onde não tem nada que
-- fazer. Entre elas: `chaves_mestre`, `credenciais_wse_cliente`, `licencas`,
-- `punho_empresas` e a `punho_apagamentos` — a tabela que serve de prova de que
-- um apagamento RGPD aconteceu.
--
-- ## Isto estava a ser explorado?
--
-- Não, e não podia estar: as 25 têm RLS ligado e nenhuma política que nomeie o
-- `anon`, portanto o RLS nega tudo antes de a permissão chegar a contar. A
-- auditoria de 11/8 (achado 2.2) chamou-lhe «RLS sem políticas»; olhando de
-- perto, a ausência de políticas é deliberada — o que está errado é o outro
-- lado, os GRANT.
--
-- ## Então porque é que se mexe
--
-- Porque a casa está a segurar-se num prego só. No dia em que alguém puser uma
-- política permissiva numa destas tabelas — ou desligar o RLS por um minuto
-- para depurar — o `anon` passa a poder escrever em `chaves_mestre` sem
-- ninguém ter mudado permissão nenhuma. Uma tabela que ninguém sem sessão pode
-- ler também não deve ter a chave da porta na mão.
--
-- ## Como se sabe que não parte nada
--
-- Pelo mesmo motivo que o torna seguro: o que hoje funciona não pode estar a
-- usar estes GRANT, porque o RLS já lhes nega tudo. Confirmado também do lado
-- do código — nenhuma das 25 é lida antes de haver sessão; as que são (`pings`,
-- `punho_leads_entrada`, `aceites_termos`, `sugestoes`, `pedidos_ajuda`,
-- `clientes`, `pedidos_renovacao`) têm política para o `anon` e ficam de fora.
--
-- O `authenticated` não se toca: é com esse papel que as apps trabalham, e as
-- permissões por coluna dele foram desenhadas na Fase 2 do hardening.
--
-- ## O que NÃO se faz aqui, e porquê
--
-- Não se revoga o EXECUTE das funções `punho_e_gestor`, `punho_empresa_atual`,
-- `punho_membro_ativo` e `punho_perfil_na_empresa` ao `anon` (achado 3.5).
-- Parecia de graça e não é: 22 políticas estão declaradas `to public`, o que
-- inclui o `anon`, e é o `anon` que as avalia quando lhe toca. Sem EXECUTE, uma
-- leitura sem sessão deixaria de devolver zero linhas e passaria a rebentar com
-- «permission denied for function». O caminho certo é passar essas políticas de
-- `to public` para `to authenticated` — e isso é uma migração por si.

revoke all on table public.admin_dispositivos              from anon;
revoke all on table public.admins                          from anon;
revoke all on table public.assinaturas_log                 from anon;
revoke all on table public.chaves_mestre                   from anon;
revoke all on table public.convites_organizacao            from anon;
revoke all on table public.credenciais_wse_cliente         from anon;
revoke all on table public.guias_comunicadas               from anon;
revoke all on table public.licencas                        from anon;
revoke all on table public.organizacoes                    from anon;
revoke all on table public.pedidos_acesso                  from anon;
revoke all on table public.punho_alteracoes_contabilista   from anon;
revoke all on table public.punho_apagamentos               from anon;
revoke all on table public.punho_conflitos_pendentes       from anon;
revoke all on table public.punho_convites                  from anon;
revoke all on table public.punho_convites_contabilista     from anon;
revoke all on table public.punho_empresas                  from anon;
revoke all on table public.punho_estado_operacional        from anon;
revoke all on table public.punho_expurgos                  from anon;
revoke all on table public.punho_membros                   from anon;
revoke all on table public.punho_mensagens_contabilista    from anon;
revoke all on table public.punho_pedidos_acesso            from anon;
revoke all on table public.punho_respostas_contabilista    from anon;
revoke all on table public.punho_rubricas_contabilista     from anon;
revoke all on table public.series_comunicadas              from anon;
revoke all on table public.versoes_apps                    from anon;

-- Uma tabela nova nasce hoje com ALL para o anon, por causa das permissões por
-- omissão que a Supabase instala no esquema `public`. Enquanto isso não mudar,
-- este ficheiro é uma limpeza e não uma correcção — a próxima tabela volta a
-- trazer a chave da porta. Mudar o padrão é:
--
--   alter default privileges in schema public revoke all on tables from anon;
--
-- Não se faz aqui porque muda o que acontece a tabelas que ainda não existem, e
-- isso merece ser uma decisão e não um efeito secundário.
