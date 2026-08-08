// sincronizar-empresa-punho
// Recebe os dados detalhados da empresa (NIF, morada, contactos, facturação,
// custos) que o utilizador Punho preencheu no onboarding ou nas Definições, e
// grava-os em `punho_empresas.dados` (jsonb). O trigger DB
// `punho_empresas_sync_licenca` cria/actualiza automaticamente a linha em
// `licencas` (app='punho') para o Control ver a empresa.
//
// Auth: JWT do utilizador (verify_jwt=true).
// Autorização: quem chama tem de ser gestor activo em `punho_membros`.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const auth = req.headers.get('Authorization') ?? '';
  const jwt = auth.replace(/^Bearer\s+/i, '');
  if (!jwt) return json({ error: 'missing_token' }, 401);

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente autenticado como o user — para descobrir quem é
  const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userErr } = await anon.auth.getUser();
  if (userErr || !userData?.user) return json({ error: 'invalid_token' }, 401);
  const uid = userData.user.id;

  // Ler payload
  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  const dados = (payload?.dados ?? {}) as Record<string, unknown>;
  const nif = String(dados.nif ?? '').trim();
  if (nif.length < 9) return json({ error: 'nif_invalido', detalhe: 'NIF tem de ter pelo menos 9 caracteres.' }, 400);

  // Service role para bypass RLS e executar UPDATE + read licenca
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Descobrir empresa via punho_membros (gestor activo)
  const { data: membros, error: memErr } = await admin
    .from('punho_membros')
    .select('empresa_id, perfil, ativo')
    .eq('user_id', uid)
    .eq('perfil', 'gestor')
    .eq('ativo', true)
    .limit(1);

  if (memErr) return json({ error: 'db_error', detalhe: memErr.message }, 500);
  if (!membros || membros.length === 0) {
    return json({ error: 'sem_empresa', detalhe: 'Não está inscrito como gestor activo em nenhuma empresa Punho.' }, 403);
  }
  const empresaId = membros[0].empresa_id as string;

  // Merge com dados existentes (não sobrescreve chaves omitidas)
  const { data: empresaAtual, error: readErr } = await admin
    .from('punho_empresas')
    .select('dados')
    .eq('id', empresaId)
    .single();
  if (readErr) return json({ error: 'db_error', detalhe: readErr.message }, 500);

  const dadosAntigos = (empresaAtual?.dados ?? {}) as Record<string, unknown>;
  const dadosMerged = { ...dadosAntigos, ...dados, sincronizado_em: new Date().toISOString() };

  const { error: updErr } = await admin
    .from('punho_empresas')
    .update({ dados: dadosMerged, updated_at: new Date().toISOString() })
    .eq('id', empresaId);
  if (updErr) return json({ error: 'db_error', detalhe: updErr.message }, 500);

  // Ler a licença criada/actualizada pelo trigger
  const { data: lic } = await admin
    .from('licencas')
    .select('id, machine_id, nif, nome_comercial, validade, activa')
    .eq('app', 'punho')
    .eq('machine_id', `punho:${empresaId}`)
    .single();

  return json({ ok: true, empresa_id: empresaId, licenca: lic ?? null });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
