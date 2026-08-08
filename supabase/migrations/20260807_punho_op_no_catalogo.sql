-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260807223406). Estava em
-- produção sem ficheiro no repo.

-- O Punho OP é uma app à parte, com o seu próprio APK e o seu próprio ritmo de
-- lançamento. Sem entrar no catálogo, a Edge Function `versao-mais-recente`
-- recusava-lhe a pergunta e o operador nunca sabia que havia versão nova.
alter table versoes_apps drop constraint versoes_apps_app_check;
alter table versoes_apps add constraint versoes_apps_app_check
  check (app = any (array['pos'::text, 'control'::text, 'punho'::text, 'punho_op'::text]));
