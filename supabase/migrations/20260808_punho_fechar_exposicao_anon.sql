-- =============================================================================
-- Fecha três exposições confirmadas por auditoria (2026-08-07).
-- =============================================================================
--
-- APLICADA EM PRODUÇÃO A 2026-08-08 00:09 UTC, com o nome
-- `punho_fechar_exposicao_anon_2026_08_07`. Este ficheiro traz para o repo o
-- que já lá estava: sem ele, quem clonar o projecto e correr as migrations de
-- raiz levanta uma base com os três buracos abertos.
--
-- Os `drop policy if exists` que envolvem a política nova não estavam na versão
-- aplicada; foram acrescentados para o ficheiro poder ser reaplicado numa base
-- limpa sem rebentar em "policy already exists". Não mudam o resultado.
--
-- 1) FUNÇÕES INTERNAS DE PROJECÇÃO
--    São SECURITY DEFINER e não verificam `auth.uid()` — porque nunca foram
--    feitas para ser chamadas de fora. Quem as chama são os triggers
--    `punho_operacoes_projectar` e `punho_estado_operacional_projectar`, também
--    SECURITY DEFINER, que correm como o dono e NÃO dependem destes GRANT.
--    Com EXECUTE aberto ao anon, qualquer pessoa com a chave pública escrevia
--    nas tabelas de leitura de qualquer empresa, sem passar pelo registo de
--    operações. Revogar não parte a projecção — está provado a correr uma
--    operação real depois da revogação.
--
-- 2) BUCKET `releases`
--    Tinha políticas de INSERT e UPDATE para o anon: qualquer pessoa substituía
--    o APK que os telemóveis descarregam na actualização automática. Fica só a
--    leitura pública, que é o que a app precisa.
--
-- 3) `punho_subscricoes`
--    A política era FOR ALL, portanto o gestor escrevia o seu próprio
--    `limite_colaboradores_ativos` — o limite que só tu autorizas no Control.
--    As linhas são criadas e alteradas por `punho_criar_empresa_inicial`,
--    `punho_decidir_pedido` e `punho_definir_limite`, todas SECURITY DEFINER,
--    que ignoram RLS. Ao cliente basta ler.
-- =============================================================================

revoke all on function public.punho_projectar_entidade(uuid, text, text, jsonb, timestamp with time zone, uuid) from public, anon, authenticated;
revoke all on function public.punho_projectar_ficha(uuid, jsonb, timestamp with time zone) from public, anon, authenticated;
revoke all on function public.punho_reprojectar_empresa(uuid) from public, anon, authenticated;

drop policy if exists "public upload releases" on storage.objects;
drop policy if exists "public update releases" on storage.objects;

drop policy if exists "empresa_gestor" on public.punho_subscricoes;
drop policy if exists "gestor subscricao" on public.punho_subscricoes;
drop policy if exists "gestor le subscricao" on public.punho_subscricoes;

create policy "gestor le subscricao" on public.punho_subscricoes
  for select
  using (empresa_id = punho_empresa_atual() and punho_e_gestor());
