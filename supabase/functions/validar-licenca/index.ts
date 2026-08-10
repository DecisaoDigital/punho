// WashInvoice + Punho — validar_licenca (multi-app)
// Chamada pelo POS/Punho ao arranque para validar a sua licença. Corre com
// service_role (contorna RLS).
//
// Multi-app: `body.app` é OBRIGATÓRIO (rompe compat com clientes que não o
// enviam). Aceita 'pos' ou 'punho'. Filtra `licencas` por (machine_id, app).
//
// ─── A chave_mestre saiu daqui, 10/08/2026 ──────────────────────────────────
//
// Esta função responde a quem tiver a chave publicável `anon` — que vai dentro
// de cada APK e é pública por desenho. `verify_jwt: true` não muda isso: a
// chave anon é um JWT válido do projecto e passa o portão da plataforma.
//
// Continua assim, e tem de continuar: o POS não tem uma única conta em
// `auth.users` e o Punho valida a licença no arranque, antes do login. Sem esta
// porta aberta as duas apps não sabem se podem arrancar.
//
// O que saiu foi a `chave_mestre`. É a metade "empresa" do par que identifica
// uma instalação — um segredo — e ia na resposta a qualquer um que soubesse um
// `machine_id`. Agora só sai contra prova de pertença: sessão de utilizador a
// sério, e essa pessoa membro activo da empresa dona da licença. Para toda a
// gente vai `null`, que é exactamente o que já ia em todas as licenças de hoje
// — nenhuma tem `chave_mestre` preenchida —, por isso nada regride.
//
// O resto da resposta fica: estado, plano, validade, nome e nif são o que o
// terminal precisa de saber sobre si próprio para decidir se arranca.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

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

/// Quem está mesmo a chamar. `null` quando o Authorization traz só a chave
/// publicável do projecto — o caso normal do arranque, e não é erro nenhum.
/// Mesmo padrão da `sincronizar-empresa-punho:37`: a identidade vem do token.
async function utilizadorDoPedido(req: Request): Promise<string | null> {
  const auth = req.headers.get('Authorization') ?? '';
  const jwt = auth.replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt === ANON_KEY) return null;

  const comoUtilizador = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false },
  });
  // O token TEM de ir como argumento. `getUser()` sem argumentos lê a sessão
  // guardada no cliente — que aqui nunca existe — e devolve sempre nulo, por
  // muito válido que seja o cabeçalho. A lição já estava em `gerir-licenca:130`
  // e voltou a morder: a primeira versão disto respondia 401 a tokens bons.
  const { data, error } = await comoUtilizador.auth.getUser(jwt);
  if (error || !data?.user) return null;
  return data.user.id;
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
  // aqui). Devolvê-la é o que dá ao Punho — que não tem `licenca.json` assinado
  // — maneira de saber a que empresa pertence. Mas é um segredo, e por isso só
  // sai contra prova de pertença: quem chama tem de ter sessão de utilizador a
  // sério e ser membro activo da empresa cujo NIF é o desta licença. Sem isso
  // vai `null`, que é o que já ia antes do modelo do par existir — o campo
  // continua sempre presente e nunca muda de nome.
  let chaveMestre: string | null = null;
  if (l.chave_mestre) {
    const uid = await utilizadorDoPedido(req);
    if (uid) {
      const { data: membros } = await supabase
        .from('punho_membros')
        .select('punho_empresas(dados)')
        .eq('user_id', uid)
        .eq('ativo', true);

      const eDaEmpresa = (membros ?? []).some((m: Record<string, unknown>) => {
        const empresa = m.punho_empresas as { dados?: Record<string, unknown> } | null;
        const nif = empresa?.dados?.nif;
        return typeof nif === 'string' && nif.trim() === String(l.nif).trim();
      });

      if (eDaEmpresa) {
        chaveMestre = l.chave_mestre;
      } else {
        console.warn(
          `validar-licenca: ${uid} pediu chave_mestre de machine_id=${machineId}, ` +
            'que não é da empresa dele'
        );
      }
    }
  }

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
    chave_mestre: chaveMestre,
    tier: l.tier ?? 'base',
    preferencias_features: l.preferencias_features ?? {},
  });
});
