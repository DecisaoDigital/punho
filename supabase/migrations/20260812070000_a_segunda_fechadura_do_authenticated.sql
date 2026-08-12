-- Continuação do varrimento do `anon` (20260812030000), agora do lado de dentro.
--
-- **Isto não está a tapar um buraco aberto.** Convém dizê-lo já, porque a
-- diferença entre "estava a arder" e "faltava a segunda fechadura" é o que
-- decide se se acorda alguém a meio da noite. O que se encontrou foi:
--
--   · o `authenticated` tinha `arwdDxtm` — a tabela inteira — em 38 tabelas,
--     incluindo DELETE e TRUNCATE;
--   · em 28 dessas o RLS não tem política de DELETE nenhuma, e o RLS nega por
--     omissão o que não tem política, portanto apagar já falhava;
--   · o TRUNCATE **ignora o RLS por completo**, mas não há por onde o emitir: o
--     PostgREST não gera TRUNCATE, o `authenticated` não tem CREATE no schema
--     (verificado) e não existe nenhuma função `security invoker` que apague
--     (verificado, zero).
--
-- Ou seja: peso morto. Mas peso morto que fica vivo no dia em que alguém
-- acrescentar uma política de DELETE a pensar noutra coisa — a permissão já lá
-- estava à espera. Foi exactamente assim que a tabela das leads se magoou: a
-- política de UPDATE existia por uma boa razão, a permissão cobria a tabela toda,
-- e o resultado era um gestor a poder forjar um registo de consentimento.
--
-- Por varrimento e não por lista, pela mesma razão da migração do `anon`: uma
-- lista escrita à mão esquece-se de uma tabela, e foi o que aconteceu da
-- primeira vez.
--
-- Verificado antes de escrever, nas três apps: os únicos `.delete()` contra a
-- base são `punho_documentos` (Punho) e `admin_dispositivos` (Control), e ambas
-- têm política de DELETE — ficam intocadas.

do $$
declare
  r record;
  tocadas int := 0;
begin
  for r in
    select c.oid, c.oid::regclass as rel,
           exists (
             select 1 from pg_policy pp
              where pp.polrelid = c.oid and pp.polcmd in ('d','*')
                and ('authenticated' = any(select rolname from pg_roles where oid = any(pp.polroles))
                     or pp.polroles = '{0}')
           ) as pode_apagar_por_politica
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r','p')
  loop
    -- O TRUNCATE sai sempre. Nenhuma app o emite, e é a única permissão desta
    -- lista que passa por cima do RLS sem pedir licença.
    execute format('revoke truncate on table %s from authenticated', r.rel);

    -- E também o que não serve a um cliente REST: referenciar a tabela numa
    -- chave estrangeira, criar-lhe gatilhos, correr-lhe manutenção. Inerte hoje
    -- por falta de CREATE no schema; não há razão para lá estar.
    execute format('revoke references, trigger, maintain on table %s from authenticated', r.rel);

    -- O DELETE só sai onde não há política que o autorize — ou seja, onde já
    -- falhava. Onde a app apaga a sério, fica.
    if not r.pode_apagar_por_politica then
      execute format('revoke delete on table %s from authenticated', r.rel);
      tocadas := tocadas + 1;
    end if;
  end loop;

  raise notice 'delete revogado em % tabelas sem politica', tocadas;
end $$;

-- E que as tabelas novas nasçam assim, em vez de dependerem de alguém se lembrar.
-- O `anon` já tinha ficado sem nada (20260812030000); o `authenticated` continua
-- a precisar de ler e escrever, portanto revoga-se só o que nunca deve herdar.
alter default privileges in schema public
  revoke truncate, references, trigger, maintain on tables from authenticated;
