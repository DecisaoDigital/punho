-- Uma função de gatilho não é um ponto final da API.
--
-- `punho_membro_ficha_existe()` nasceu na migração das vistas e ficou com
-- `execute` para `anon` e `authenticated` — é o que o Postgres faz por omissão,
-- e é por isso que já existe a 20260808_punho_revogar_funcoes_trigger_de_anon:
-- o PostgREST publica em `/rest/v1/rpc/` tudo o que seja executável.
--
-- Chamada fora de um gatilho rebenta sozinha (`NEW` não existe), por isso não é
-- uma porta aberta. É uma porta que não devia estar na parede. Apanhada pelo
-- linter de segurança logo a seguir a aplicar as vistas.
revoke all on function public.punho_membro_ficha_existe() from public, anon, authenticated;

-- Enquanto aqui estou: estas duas correm com o `search_path` de quem chama.
--
-- Nenhuma é `security definer`, logo não há escalada de privilégio possível — o
-- que muda é o resultado. `punho_validar_payload_operacao` é o gatilho que
-- valida tudo o que entra no registo: quem lhe torça o `search_path` torce a
-- validação, e as datas de uma reserva deixam de ser verificadas contra o que se
-- pensa que estão. Fixá-lo custa uma linha.
alter function public.punho_validar_payload_operacao() set search_path = public;
alter function public.punho_nif_valido(text)            set search_path = public;
