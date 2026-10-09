// Fist — licenca-fist
//
// A licença do Fist é da EMPRESA (quem paga); o funcionário é um lugar em
// `punho_membros`; cada funcionário tem no máximo 2 aparelhos e uma só sessão
// ativa. Desenho e motivos: docs/LICENCA_POR_FUNCIONARIO.md.
//
// É uma função NOVA, de propósito: `registar-terminal` e `validar-licenca`
// continuam como estão para as apps já instaladas (que ainda falam por
// `machine_id`). Esta exige sessão — a identidade vem do token, nunca do corpo.
//
// Um pedido faz, por esta ordem:
//   1. quem é (JWT de utilizador; a chave publicável não serve);
//   2. de que empresa é membro ativo (o lugar já foi concedido: o excedente do
//      limite fica `ativo = false` e não chega aqui);
//   3. a licença da empresa — se não existir, adopta a linha antiga do Fist com
//      o mesmo NIF ou cria o trial de 40 dias (da empresa, não do funcionário);
//   4. o aparelho: no máximo 2 por funcionário;
//   5. a sessão única: quem abre reclama, o outro perde.
//
// A graça offline (28 h) é do telemóvel: conta desde a última resposta com
// sucesso desta função.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const DIAS_TRIAL = 40;
const MAX_DISPOSITIVOS = 2;

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

const NIF_VALIDO = /^\d{9}$/;

/// Quem está a chamar. `null` se o Authorization não for um utilizador a sério
/// (ex.: só a chave publicável). O token TEM de ir como argumento do getUser.
async function utilizadorDoPedido(
  req: Request,
): Promise<{ id: string; email: string | null } | null> {
  const auth = req.headers.get('Authorization') ?? '';
  const jwt = auth.replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt === ANON_KEY) return null;
  const c = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false },
  });
  const { data, error } = await c.auth.getUser(jwt);
  if (error || !data?.user) return null;
  return { id: data.user.id, email: data.user.email ?? null };
}

/// Dias entre hoje e a validade, em UTC e por dia inteiro (a coluna é DATE: a
/// licença vale o dia todo). Negativo = já expirou.
function diasRestantes(validade: string, agora: Date): number {
  const hoje = new Date(`${agora.toISOString().slice(0, 10)}T00:00:00Z`);
  const v = new Date(`${String(validade).slice(0, 10)}T00:00:00Z`);
  return Math.round((v.getTime() - hoje.getTime()) / 86_400_000);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json(405, { erro: 'method not allowed' });

  const utilizador = await utilizadorDoPedido(req);
  if (!utilizador) {
    return json(401, {
      erro: 'sessão necessária',
      detalhe: 'A licença do Fist é da conta: inicia sessão.',
    });
  }

  let body: {
    machine_id?: string;
    nome_dispositivo?: string;
    reclamar_sessao?: boolean;
    sessao_id?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json(400, { erro: 'body inválido' });
  }
  const machineId = body.machine_id;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { erro: 'machine_id obrigatório' });
  }
  const nomeDispositivo =
    typeof body.nome_dispositivo === 'string'
      ? body.nome_dispositivo.slice(0, 80)
      : null;

  const db = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });
  const agora = new Date();

  // ── 2. a empresa deste funcionário ───────────────────────────────────────
  const { data: membros, error: erroMembros } = await db
    .from('punho_membros')
    .select('empresa_id, perfil, punho_empresas(id, nome, dados)')
    .eq('user_id', utilizador.id)
    .eq('ativo', true)
    .order('created_at', { ascending: true })
    .limit(1);
  if (erroMembros) {
    console.error('erro punho_membros', erroMembros);
    return json(500, { erro: erroMembros.message });
  }
  if (!membros || membros.length === 0) {
    // Sem lugar ativo: ou ainda não foi aprovado, ou ficou acima do limite.
    return json(200, { estado: 'sem_lugar', servidor_em: agora.toISOString() });
  }
  const membro = membros[0] as Record<string, unknown>;
  const empresa = membro.punho_empresas as
    | { id: string; nome: string; dados?: Record<string, unknown> }
    | null;
  if (!empresa) return json(500, { erro: 'empresa em falta' });
  const nifEmpresa = typeof empresa.dados?.nif === 'string'
    ? (empresa.dados.nif as string).trim()
    : null;

  // ── 3. a licença da empresa ──────────────────────────────────────────────
  let { data: licenca, error: erroLic } = await db
    .from('licencas')
    .select('*')
    .eq('empresa_id', empresa.id)
    .eq('app', 'punho')
    .maybeSingle();
  if (erroLic) {
    console.error('erro licencas', erroLic);
    return json(500, { erro: erroLic.message });
  }

  if (!licenca && nifEmpresa && NIF_VALIDO.test(nifEmpresa)) {
    // Adopta a linha antiga (por aparelho) que já leva o NIF desta empresa e
    // ainda não pertence a nenhuma: assim o trial em curso não recomeça.
    const { data: antigas } = await db
      .from('licencas')
      .select('id')
      .eq('app', 'punho')
      .eq('nif', nifEmpresa)
      .is('empresa_id', null)
      .order('validade', { ascending: false })
      .limit(1);
    if (antigas && antigas.length > 0) {
      const { data: adoptada, error: erroAdopt } = await db
        .from('licencas')
        .update({ empresa_id: empresa.id })
        .eq('id', antigas[0].id)
        .select('*')
        .single();
      if (erroAdopt) {
        console.error('erro a adoptar licença', erroAdopt);
        return json(500, { erro: erroAdopt.message });
      }
      licenca = adoptada;
    }
  }

  if (!licenca) {
    const validade = new Date(agora.getTime() + DIAS_TRIAL * 86_400_000)
      .toISOString().slice(0, 10);
    const { data: criada, error: erroCria } = await db
      .from('licencas')
      .insert({
        machine_id: `empresa:${empresa.id}`,
        app: 'punho',
        empresa_id: empresa.id,
        nif: nifEmpresa && NIF_VALIDO.test(nifEmpresa) ? nifEmpresa : '000000000',
        nome: empresa.nome,
        plano: 'trial',
        validade,
        activa: true,
        oferta: true,
        pendente_revisao: true,
        tier: 'base',
        preferencias_features: {},
      })
      .select('*')
      .single();
    if (erroCria) {
      console.error('erro a criar trial da empresa', erroCria);
      return json(500, { erro: erroCria.message });
    }
    licenca = criada;
  }

  // O Control mostra a licença pelo `nome`. A linha adoptada vem do tempo em que
  // a licença era do aparelho e pode não ter nenhum: passa a ter o da empresa.
  if (!licenca.nome || String(licenca.nome).trim() === '') {
    const { data: comNome } = await db
      .from('licencas')
      .update({ nome: empresa.nome })
      .eq('id', licenca.id)
      .select('*')
      .single();
    if (comNome) licenca = comNome;
  }

  const dias = diasRestantes(String(licenca.validade), agora);
  let estado: 'activa' | 'expirada' | 'inactiva' = 'activa';
  if (licenca.activa === false) estado = 'inactiva';
  else if (dias < 0) estado = 'expirada';

  // ── 4. o aparelho (máximo 2 por funcionário) ─────────────────────────────
  const { data: aparelhos, error: erroAp } = await db
    .from('fist_dispositivos')
    .select('machine_id')
    .eq('user_id', utilizador.id);
  if (erroAp) {
    console.error('erro fist_dispositivos', erroAp);
    return json(500, { erro: erroAp.message });
  }
  const conhecidos = (aparelhos ?? []).map((a) => a.machine_id as string);
  const jaConhecido = conhecidos.includes(machineId);
  if (!jaConhecido && conhecidos.length >= MAX_DISPOSITIVOS) {
    return json(200, {
      estado: 'dispositivos_excedidos',
      dispositivos: { usados: conhecidos.length, maximo: MAX_DISPOSITIVOS },
      servidor_em: agora.toISOString(),
    });
  }
  const { error: erroUpAp } = await db.from('fist_dispositivos').upsert(
    {
      user_id: utilizador.id,
      machine_id: machineId,
      nome: nomeDispositivo,
      visto_em: agora.toISOString(),
    },
    { onConflict: 'user_id,machine_id' },
  );
  if (erroUpAp) {
    console.error('erro a guardar aparelho', erroUpAp);
    return json(500, { erro: erroUpAp.message });
  }

  // ── 5. a sessão única ────────────────────────────────────────────────────
  let sessaoId: string | null = null;
  let sessaoAtiva = true;
  if (body.reclamar_sessao === true) {
    const { data: nova, error: erroSes } = await db
      .from('fist_sessoes')
      .upsert(
        {
          user_id: utilizador.id,
          machine_id: machineId,
          sessao_id: crypto.randomUUID(),
          aberta_em: agora.toISOString(),
          visto_em: agora.toISOString(),
        },
        { onConflict: 'user_id' },
      )
      .select('sessao_id')
      .single();
    if (erroSes) {
      console.error('erro a reclamar sessão', erroSes);
      return json(500, { erro: erroSes.message });
    }
    sessaoId = nova.sessao_id as string;
  } else {
    const { data: atual } = await db
      .from('fist_sessoes')
      .select('sessao_id, machine_id')
      .eq('user_id', utilizador.id)
      .maybeSingle();
    sessaoId = (atual?.sessao_id as string | undefined) ?? null;
    // Perde a sessão quem apresenta um id que já não é o da sessão ativa.
    sessaoAtiva = !!atual && !!body.sessao_id && body.sessao_id === atual.sessao_id;
    if (sessaoAtiva) {
      await db.from('fist_sessoes').update({ visto_em: agora.toISOString() })
        .eq('user_id', utilizador.id);
    }
  }

  return json(200, {
    estado,
    plano: licenca.plano,
    validade: String(licenca.validade).slice(0, 10),
    dias_restantes: dias,
    empresa: { id: empresa.id, nome: empresa.nome },
    perfil: membro.perfil,
    email: utilizador.email,
    dispositivos: {
      usados: jaConhecido ? conhecidos.length : conhecidos.length + 1,
      maximo: MAX_DISPOSITIVOS,
    },
    sessao: { id: sessaoId, ativa: sessaoAtiva },
    servidor_em: agora.toISOString(),
  });
});
