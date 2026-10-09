import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Punho — avisos push (FCM) para o telemóvel de quem tem de reagir a uma lead.
//
// Quem chama: gatilhos da base de dados (pg_net), com o segredo do projecto em
// `Authorization: Bearer`. Ninguém mais. O corpo só diz *o quê* mudou
// (`{ tipo: "entrada" | "operacao", id }`); quem recebe, e o texto, decide-se
// aqui lendo a linha — o chamador não escolhe destinatários.
//
// Firebase próprio do Punho (projecto `punho-fist`), separado do Control e do
// WashInvoice: a conta de serviço vem de PUNHO_FCM_SERVICE_ACCOUNT_JSON.
//
// Regras de quem é avisado:
//   entrada   lead que chegou de fora (site, WhatsApp…), aceite ou retida
//             -> gestores da empresa
//   operacao  lead atribuída a alguém (1.ª operação ou mudança de operador)
//             -> esse operador
//   operacao  lead nova criada por um colaborador -> gestores
// O autor do gesto nunca é avisado do que acabou de fazer.

function json(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function b64url(input: Uint8Array | string): string {
  const raw = typeof input === "string" ? btoa(input) : btoa(String.fromCharCode(...input));
  return raw.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function accessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const h = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const p = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  }));
  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const chave = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", chave, new TextEncoder().encode(`${h}.${p}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${h}.${p}.${b64url(new Uint8Array(sig))}`,
    }),
  });
  if (!r.ok) throw new Error(`OAuth2 recusou: HTTP ${r.status}`);
  return (await r.json()).access_token as string;
}

type Aviso = { titulo: string; corpo: string; destinatarios: string[]; empresa: string; leadId?: string };

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ erro: "só POST" }, 405);
  const segredo = Deno.env.get("EDGE_INVOKE_SECRET");
  if (!segredo || req.headers.get("Authorization") !== `Bearer ${segredo}`) {
    return json({ erro: "não autorizado" }, 401);
  }

  let pedido: { tipo?: string; id?: string };
  try {
    pedido = await req.json();
  } catch {
    return json({ erro: "JSON inválido" }, 400);
  }
  if (!pedido.id || (pedido.tipo !== "entrada" && pedido.tipo !== "operacao")) {
    return json({ erro: "tipo/id em falta" }, 400);
  }

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const gestores = async (empresa: string, menos: string | null): Promise<string[]> => {
    const { data } = await db.from("punho_membros").select("user_id")
      .eq("empresa_id", empresa).eq("perfil", "gestor").eq("ativo", true);
    return (data ?? []).map((m) => m.user_id as string).filter((u) => u !== menos);
  };

  let aviso: Aviso | null = null;

  if (pedido.tipo === "entrada") {
    const { data: e } = await db.from("punho_leads_entrada")
      .select("empresa_id, nome, classificacao").eq("id", pedido.id).maybeSingle();
    if (!e || !["aceite", "retida"].includes(e.classificacao)) return json({ ok: true, enviados: 0, motivo: "sem aviso" });
    aviso = {
      empresa: e.empresa_id,
      titulo: e.classificacao === "aceite" ? "Lead nova" : "Lead para rever",
      corpo: (e.nome as string | null)?.trim() || "Sem nome",
      destinatarios: await gestores(e.empresa_id, null),
    };
  } else {
    const { data: op } = await db.from("punho_operacoes")
      .select("seq, empresa_id, entidade, entidade_id, payload, por_utilizador").eq("id", pedido.id).maybeSingle();
    if (!op || op.entidade !== "lead") return json({ ok: true, enviados: 0, motivo: "não é lead" });
    const { data: ant } = await db.from("punho_operacoes").select("payload")
      .eq("empresa_id", op.empresa_id).eq("entidade", "lead").eq("entidade_id", op.entidade_id)
      .lt("seq", op.seq).order("seq", { ascending: false }).limit(1);
    const antes = ant?.[0]?.payload as Record<string, unknown> | undefined;
    const p = op.payload as Record<string, unknown>;
    const nome = String(p.name ?? "").trim() || "Sem nome";
    const atribuida = p.collaboratorResponsibleId ? String(p.collaboratorResponsibleId) : null;
    const eraAtribuida = antes?.collaboratorResponsibleId ? String(antes.collaboratorResponsibleId) : null;

    if (atribuida && atribuida !== eraAtribuida) {
      const { data: ms } = await db.from("punho_membros").select("user_id, colaborador_id")
        .eq("empresa_id", op.empresa_id).eq("ativo", true);
      const dest = (ms ?? [])
        .filter((m) => String(m.colaborador_id) === atribuida || String(m.user_id) === atribuida)
        .map((m) => m.user_id as string)
        .filter((u) => u !== op.por_utilizador);
      aviso = { empresa: op.empresa_id, titulo: "Lead atribuída a ti", corpo: nome, destinatarios: dest, leadId: op.entidade_id };
    } else if (!antes && op.por_utilizador) {
      const { data: autor } = await db.from("punho_membros").select("perfil")
        .eq("empresa_id", op.empresa_id).eq("user_id", op.por_utilizador).maybeSingle();
      if (autor?.perfil === "colaborador") {
        aviso = {
          empresa: op.empresa_id, titulo: "Lead nova", corpo: nome,
          destinatarios: await gestores(op.empresa_id, op.por_utilizador), leadId: op.entidade_id,
        };
      }
    }
  }

  if (!aviso || aviso.destinatarios.length === 0) return json({ ok: true, enviados: 0, motivo: "ninguém a avisar" });

  const { data: toks } = await db.from("punho_push_tokens").select("token")
    .eq("empresa_id", aviso.empresa).in("user_id", aviso.destinatarios);
  const tokens = [...new Set((toks ?? []).map((t) => t.token as string))];
  if (tokens.length === 0) return json({ ok: true, enviados: 0, motivo: "sem aparelhos registados" });

  const bruto = Deno.env.get("PUNHO_FCM_SERVICE_ACCOUNT_JSON");
  if (!bruto) return json({ erro: "PUNHO_FCM_SERVICE_ACCOUNT_JSON em falta" }, 500);
  const sa = JSON.parse(bruto);
  const acesso = await accessToken(sa);

  let enviados = 0;
  const mortos: string[] = [];
  const falhas: unknown[] = [];
  for (const token of tokens) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${acesso}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: aviso.titulo, body: aviso.corpo },
          data: { tipo: "lead", ...(aviso.leadId ? { lead_id: aviso.leadId } : {}) },
          android: { priority: "HIGH", notification: { channel_id: "leads" } },
        },
      }),
    });
    if (r.ok) {
      enviados++;
    } else {
      const corpo = await r.json().catch(() => ({}));
      if (r.status === 404 || corpo?.error?.status === "NOT_FOUND") mortos.push(token);
      else falhas.push({ status: r.status, erro: corpo?.error?.status });
    }
  }
  if (mortos.length) await db.from("punho_push_tokens").delete().in("token", mortos);
  return json({ ok: true, enviados, removidos: mortos.length, falhas });
});
