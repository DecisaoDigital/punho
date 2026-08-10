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
//
// ─── Autorização, 10/08/2026 ────────────────────────────────────────────────
//
// `verify_jwt: true` não é autenticação aqui, e é o erro que esta função tinha:
// a chave publicável `anon` É um JWT válido do projecto, e é pública por
// definição — vai dentro de cada APK. Quem a tiver passa o portão da
// plataforma. A função corria a seguir com service_role e não perguntava mais
// nada a ninguém.
//
// O que isso dava: um POST com a chave anon, um `machine_id` alheio e um `nif`
// à escolha trocava o NIF de uma licença que não era de quem chamava. O `nif` é
// o eixo que liga licença, empresa e emissão fiscal — trocá-lo não é estragar
// um campo, é reatribuir a instalação a outra empresa.
//
// A correcção NÃO pode ser exigir sessão em tudo, e é preciso dizer porquê:
// **o POS não tem uma única conta em `auth.users`** (verificado, zero) e o
// Punho corre isto no arranque, antes do login. Exigir `getUser()` à entrada
// fechava a porta de instalação das duas apps. Então divide-se em duas portas,
// pelo risco de cada uma:
//
//   CRIAR uma licença que não existe .... continua sem sessão, com rate-limit
//                                        por IP. Uma linha nova de trial não
//                                        tira nada a ninguém; o que se defende
//                                        aqui é o volume
//   MUDAR o `nif` de uma que existe .... exige sessão de utilizador a sério, e
//                                        que essa pessoa seja membro activo da
//                                        empresa dona da licença
//
// O padrão do `getUser()` é o da `sincronizar-empresa-punho:37`: a identidade
// vem do token, nunca do corpo do pedido.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const APPS = ['pos', 'punho'] as const;
type AppName = typeof APPS[number];

const DIAS_GRACA: Record<AppName, number> = {
  pos: 5,
  punho: 40,
};

// Quantos terminais NOVOS um mesmo IP pode criar por hora. Uma instalação
// legítima cria um e nunca mais volta a esta porta — os arranques seguintes
// caem no ramo "existente", que não conta. Dez deixa passar uma loja inteira a
// instalar na mesma manhã, atrás do mesmo NAT, e trava quem esteja a varrer.
const MAX_CRIACOES_POR_IP_HORA = 10;

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

/// Quem está mesmo a chamar. Devolve `null` quando o Authorization traz apenas
/// a chave publicável do projecto — que é o caso normal do arranque, e não é
/// um erro: é só ausência de identidade.
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

/// O IP de quem chama. Atrás do proxy da Supabase o verdadeiro é o primeiro da
/// lista do `x-forwarded-for`; os seguintes são os saltos até cá.
function ipDoPedido(req: Request): string {
  const encaminhado = req.headers.get('x-forwarded-for') ?? '';
  const primeiro = encaminhado.split(',')[0]?.trim();
  return primeiro || req.headers.get('x-real-ip') || 'desconhecido';
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

    // Nada a mudar: o arranque de sempre, a dizer olá. Sai por aqui sem tocar
    // em nada e sem gastar rate-limit.
    if (!nifRecebido || nifRecebido === linha.nif) {
      return json(200, { criado: false, estado: 'existente', app: appTyped });
    }

    // Daqui para baixo é uma ESCRITA num registo que já existe, e é o que
    // estava aberto ao mundo. A partir daqui exige-se identidade.
    const uid = await utilizadorDoPedido(req);
    if (!uid) {
      return json(401, {
        erro: 'sessão necessária',
        detalhe:
          'Mudar o NIF de uma licença já registada exige sessão iniciada. ' +
          'A chave publicável do projecto não serve — é pública.',
      });
    }

    // De que empresas é esta pessoa membro activo, e com que NIF.
    const { data: membros, error: erroMembros } = await supabase
      .from('punho_membros')
      .select('empresa_id, punho_empresas(dados)')
      .eq('user_id', uid)
      .eq('ativo', true);

    if (erroMembros) {
      console.error('erro leitura punho_membros', erroMembros);
      return json(500, { erro: erroMembros.message });
    }

    const nifsDoChamador = (membros ?? [])
      .map((m: Record<string, unknown>) => {
        const empresa = m.punho_empresas as { dados?: Record<string, unknown> } | null;
        const nif = empresa?.dados?.nif;
        return typeof nif === 'string' ? nif.trim() : null;
      })
      .filter((n): n is string => !!n);

    const placeholder = !nifValido(linha.nif);

    // Duas condições, e as duas têm de se verificar. Nenhuma delas é "estou
    // autenticado":
    //
    //  1. o NIF que se escreve é o da MINHA empresa. Sem isto, um gestor
    //     legítimo pegava no terminal dele e punha-lhe o NIF de outra empresa —
    //     que é impersonação fiscal, não é estragar um campo;
    //  2. a licença ou ainda não pertence a ninguém (`000000000`, o
    //     auto-onboarding a fechar o ciclo) ou já é da minha empresa.
    //
    // O `is_admin()` passa por cima das duas: é o Cesar a corrigir instalações
    // pelo Control, que é o caminho que sempre teve.
    // Lê-se `admins` directamente em vez de chamar `is_admin()`: a função lê
    // `auth.uid()`, e aqui o cliente é service_role — `auth.uid()` seria nulo e
    // respondia sempre que não. É a mesma tabela, é a mesma resposta.
    const { data: linhaAdmin } = await supabase
      .from('admins')
      .select('user_id')
      .eq('user_id', uid)
      .maybeSingle();
    const eAdmin = !!linhaAdmin;

    const nifEMeu = nifsDoChamador.includes(nifRecebido);
    const licencaEMinha = placeholder || nifsDoChamador.includes(String(linha.nif));

    if (!eAdmin && !(nifEMeu && licencaEMinha)) {
      console.warn(
        `registar-terminal: ${uid} tentou pôr nif=${nifRecebido} em ` +
          `machine_id=${machineId} (nif actual ${linha.nif})`
      );
      return json(403, {
        erro: 'sem permissão sobre esta licença',
        detalhe:
          'O NIF de uma licença só pode ser escrito por membro activo da ' +
          'empresa a que ela pertence.',
      });
    }

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

  // ─── criação ──────────────────────────────────────────────────────────────
  // Continua sem exigir sessão, porque é a porta de instalação do POS, que
  // conta nenhuma tem. Defende-se pelo volume, não pela identidade.
  const ip = ipDoPedido(req);
  const desdeUmaHora = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  const { count, error: erroContagem } = await supabase
    .from('registar_terminal_tentativas')
    .select('id', { count: 'exact', head: true })
    .eq('ip', ip)
    .gte('criado_em', desdeUmaHora);

  if (erroContagem) {
    // Um contador partido não pode calar a instalação de um cliente. Regista-se
    // e segue — o pior caso é ficarmos como estávamos antes desta alteração.
    console.error('erro rate-limit registar-terminal', erroContagem);
  } else if ((count ?? 0) >= MAX_CRIACOES_POR_IP_HORA) {
    console.warn(`registar-terminal: rate-limit atingido por ${ip} (${count})`);
    return json(429, {
      erro: 'demasiados registos',
      detalhe: `Máximo de ${MAX_CRIACOES_POR_IP_HORA} terminais novos por hora.`,
    });
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

  // Só depois de a linha existir. Contar tentativas que falharam dava a quem
  // varre a possibilidade de gastar o limite de um cliente legítimo com pedidos
  // inválidos.
  await supabase
    .from('registar_terminal_tentativas')
    .insert({ ip, app: appTyped, machine_id: machineId });

  // A tabela limpa-se sozinha. Um dia chega: a janela do limite é uma hora.
  await supabase
    .from('registar_terminal_tentativas')
    .delete()
    .lt('criado_em', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

  return json(200, {
    criado: true,
    app: appTyped,
    validade,
    dias_graca: dias,
    mensagem: `Terminal registado com ${dias} dias de graça. Contactar Cesar para activar plano definitivo.`,
  });
});
