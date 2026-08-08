// WashInvoice + Punho — registar-terminal (multi-app)
// Auto-onboarding: dado um machine_id que ainda NÃO existe em `licencas` para
// a app pedida, cria uma linha inicial com período de graça (trial), activa=true,
// oferta=true e pendente_revisao=true (o Cesar revê no Control). Idempotente:
// se já existir para o mesmo (machine_id, app), não sobrescreve — excepto o
// `nif`, que é actualizado se vier um valor válido diferente do guardado (ver
// bloco abaixo: cobre o caso da instalação nascer antes do NIF ser conhecido).
//
// Multi-app: `body.app` é OBRIGATÓRIO. Aceita 'pos' ou 'punho'. Trial de 5 dias
// para POS (mantido do legado), 40 dias para Punho. Corre com service_role.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const APPS = ['pos', 'punho'] as const;
type AppName = typeof APPS[number];

const DIAS_GRACA: Record<AppName, number> = {
  pos: 5,
  punho: 40,
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// NIF válido = 9 dígitos. O placeholder '000000000' nunca conta como válido
// para efeitos de actualização — senão nunca sairíamos dele.
function nifValido(nif: unknown): nif is string {
  return typeof nif === 'string' && /^\d{9}$/.test(nif) && nif !== '000000000';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { erro: 'method not allowed' });
  }

  let body: { machine_id?: string; app?: string; info_host?: unknown; nif?: unknown };
  try {
    body = await req.json();
  } catch {
    return json(400, { erro: 'body inválido' });
  }

  const machineId = body.machine_id;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { erro: 'machine_id obrigatório' });
  }

  const app = body.app;
  if (!app || typeof app !== 'string' || !APPS.includes(app as AppName)) {
    return json(400, {
      erro: `app obrigatório (${APPS.join(' | ')})`,
    });
  }
  const appTyped = app as AppName;

  const infoHost =
    body.info_host && typeof body.info_host === 'object' ? body.info_host : null;

  const nifRecebido = nifValido(body.nif) ? body.nif : null;

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  // Idempotente por (machine_id, app): o mesmo PC pode ter POS e Punho
  // instalados lado a lado.
  const { data: existentes, error: erroLeitura } = await supabase
    .from('licencas')
    .select('id, nif')
    .eq('machine_id', machineId)
    .eq('app', appTyped)
    .limit(1);

  if (erroLeitura) {
    console.error('erro leitura licencas', erroLeitura);
    return json(500, { erro: erroLeitura.message });
  }

  if (existentes && existentes.length > 0) {
    const linha = existentes[0];
    // A instalação já existe. O único campo que esta chamada pode corrigir é o
    // `nif`: nasce '000000000' porque a instalação regista-se antes de a app
    // saber a que empresa pertence, e nada mais no sistema o actualiza depois
    // — o trigger `punho_sync_licenca_from_empresa` só actualiza linhas que já
    // têm o nif certo, nunca as que ainda têm o placeholder.
    if (nifRecebido && nifRecebido !== linha.nif) {
      const { error: erroUpdate } = await supabase
        .from('licencas')
        .update({ nif: nifRecebido })
        .eq('id', linha.id);
      if (erroUpdate) {
        console.error('erro update nif licencas', erroUpdate);
        return json(500, { erro: erroUpdate.message });
      }
      return json(200, { criado: false, estado: 'nif_actualizado', app: appTyped });
    }
    return json(200, { criado: false, estado: 'existente', app: appTyped });
  }

  const dias = DIAS_GRACA[appTyped];
  const validade = new Date(Date.now() + dias * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);

  const { error: erroInsert } = await supabase.from('licencas').insert({
    machine_id: machineId,
    app: appTyped,
    nif: nifRecebido ?? '000000000',
    plano: 'trial',
    validade,
    activa: true,
    oferta: true,
    pendente_revisao: true,
    info_host: infoHost,
    tier: 'base',
    preferencias_features: {},
  });

  if (erroInsert) {
    console.error('erro insert licencas', erroInsert);
    return json(500, { erro: erroInsert.message });
  }

  return json(200, {
    criado: true,
    app: appTyped,
    validade,
    dias_graca: dias,
    mensagem: `Terminal registado com ${dias} dias de graça. Contactar Cesar para activar plano definitivo.`,
  });
});
