-- Punho v0.0.6 · Passo 7.8 do sprint 2 v0.0.6
-- Catalogar a nova versão na tabela `versoes_apps` do Control
-- (mesmo projecto Supabase: oefqbkhioncakojipqyx).
--
-- Executar APÓS o APK estar no GitHub Release (Passo 7.6) e o URL final
-- conhecido. Enquanto a linha não estiver aqui, a Edge Function
-- `versao-mais-recente` responde `actualizacao_disponivel: false` a toda a
-- gente na v0.0.5 e o banner nunca aparece.
--
-- Não é preciso desactivar linhas anteriores: a EF faz
-- `order by build_number desc limit 1 where activa=true`.
--
-- SUBSTITUIR antes de executar:
--   <URL_APK>   → URL directo do asset do release (padrão histórico:
--                 https://github.com/DecisaoDigital/punho/releases/download/v0.0.6/punho-android-v0.0.6.apk)
--   <NOTAS>     → 1 parágrafo curto (release notes visíveis no banner)

insert into public.versoes_apps
  (app, versao, build_number, plataforma, url_download, obrigatoria, activa, notas_lancamento)
values
  ('punho', '0.0.6', 6, 'android',
   '<URL_APK>',
   false, true,
   '<NOTAS>');

-- Verificação imediata (a mesma query que a Edge Function faz):
select versao, build_number, plataforma, url_download, activa
  from public.versoes_apps
 where app = 'punho' and activa = true
   and plataforma in ('android', 'all')
 order by build_number desc
 limit 1;
-- Esperado: versao='0.0.6', build_number=6.

-- Smoke real (opcional, do lado do cliente): abrir a v0.0.5 no tablet.
-- Depois do próximo check (arranque ou 24h), banner "Nova versão 0.0.6"
-- deve aparecer sobre qualquer ecrã — login incluído.
