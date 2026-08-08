// WashInvoice + Punho — validar_licenca (multi-app)
// Chamada pelo POS/Punho ao arranque para validar a sua licença. Corre com
// service_role (contorna RLS).
//
// Multi-app: `body.app` é OBRIGATÓRIO (rompe compat com clientes que não o
// enviam). Aceita 'pos' ou 'punho'. Filtra `licencas` por (machine_id, app).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const APPS = ['pos', 'punho'] as const;
type AppName = typeof APPS[number];

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { erro: 'method not allowed' });
  }

  let body: { machine_id?: string; app?: string };
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

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: licencas, error } = await supabase
    .from('licencas')
    .select('*')
    .eq('machine_id', machineId)
    .eq('app', appTyped)
    .order('validade', { ascending: false })
    .limit(1);

  if (error) {
    console.error('erro leitura licencas', error);
    return json(500, { erro: error.message });
  }

  if (!licencas || licencas.length === 0) {
    return json(200, {
      estado: 'inexistente',
      app: appTyped,
      machine_id: machineId,
    });
  }

  const l = licencas[0];

  // `validade` é uma coluna DATE: a licença vale o **dia inteiro**. Comparar um
  // dia com um instante — que era o que aqui estava — tinha duas consequências,
  // ambas contra o cliente:
  //
  //  * `new Date('2026-08-10')` é `2026-08-10T00:00:00Z`, e subtrair-lhe o
  //    instante actual perdia sempre a fracção no `Math.floor`. Uma licença
  //    válida até 10 de Agosto anunciava "1 dia" a 8 de Agosto, não 2. Era o
  //    número que o banner do Punho mostrava, e estava errado por um dia
  //    inteiro em todas as licenças, sempre.
  //  * pior: no próprio dia da validade, `validade < agora` passava a verdade
  //    à meia-noite UTC — 01:00 em Lisboa no Verão — e a licença dava-se por
  //    **expirada durante todo o dia em que ainda era válida**.
  //
  // Agora os dois lados são dias, e comparam-se como dias. A conta é feita em
  // UTC de propósito: em Portugal isso dá, quando muito, uma hora de tolerância
  // a mais na viragem do dia — e numa licença é esse o lado certo para errar.
  const agora = new Date();
  const hoje = new Date(`${agora.toISOString().slice(0, 10)}T00:00:00Z`);
  const validade = new Date(`${String(l.validade).slice(0, 10)}T00:00:00Z`);
  const diasRestantes = Math.round(
    (validade.getTime() - hoje.getTime()) / (1000 * 60 * 60 * 24)
  );

  let estado: 'activa' | 'expirada' | 'inactiva';
  if (!l.activa) estado = 'inactiva';
  else if (diasRestantes < 0) estado = 'expirada';
  else estado = 'activa';

  // `chave_mestre` é a metade "empresa" do par (a outra é o `machine_id`, já
  // aqui). Vai `null` nas instalações anteriores ao modelo do par. Devolvê-la
  // aqui é o que dá ao Punho — que não tem `licenca.json` assinado — maneira de
  // saber a que empresa pertence. Aditivo: nenhum campo sai nem muda de nome.
  return json(200, {
    estado,
    app: appTyped,
    plano: l.plano,
    validade: l.validade,
    nome: l.nome,
    nif: l.nif,
    dias_restantes: diasRestantes,
    oferta: l.oferta ?? false,
    machine_id: machineId,
    chave_mestre: l.chave_mestre ?? null,
    tier: l.tier ?? 'base',
    preferencias_features: l.preferencias_features ?? {},
  });
});
