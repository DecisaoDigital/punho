import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Recebe leads de fora da app: landing page, WhatsApp, agenda.
//
// A validação vive aqui e não na app, por duas razões: a app pode estar
// fechada ou sem rede, e um endereço público é uma porta para a base de dados
// — a filtragem tem de estar do lado que nós controlamos, antes de a linha
// existir.
//
// Nada é rejeitado no sentido de desaparecer. Rejeitar é classificar: o lixo
// fica gravado como `descartada`, porque sem ele não se distingue "a campanha
// não trouxe nada" de "a campanha trouxe lixo que apagámos" — e essa diferença
// decide se se volta a pagar pelo canal.

const ORIGENS = ["landing_page", "whatsapp", "telefone", "agenda", "manual", "outro"];

/// Normaliza para E.164. É a chave de deduplicação: sem ela o mesmo cliente
/// conta várias vezes e a conversão do painel divide-se pelo número de canais.
///
/// Portugal por omissão — é o mercado da app. Um número que não normaliza é o
/// sinal mais fiável de lixo que existe, melhor do que analisar o texto.
function normalizarTelefone(bruto: string | null | undefined): string | null {
  if (!bruto) return null;
  let d = String(bruto).replace(/[^\d+]/g, "");
  if (d.startsWith("00")) d = "+" + d.slice(2);
  if (d.startsWith("+")) {
    const digitos = d.slice(1);
    if (digitos.length < 8 || digitos.length > 15) return null;
    return "+" + digitos;
  }
  // Sem indicativo: só se parecer um número português com 9 dígitos.
  if (/^[92]\d{8}$/.test(d)) return "+351" + d;
  return null;
}

function emailPlausivel(email: string | null | undefined): boolean {
  if (!email) return false;
  return /^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$/.test(String(email));
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ erro: "metodo_nao_suportado" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return new Response(JSON.stringify({ erro: "json_invalido" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const empresaId = String(corpo.empresa_id ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(empresaId)) {
    return new Response(JSON.stringify({ erro: "empresa_invalida" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const origem = ORIGENS.includes(String(corpo.origem))
    ? String(corpo.origem)
    : "outro";
  const nome = corpo.nome ? String(corpo.nome).trim().slice(0, 200) : null;
  const telefoneOriginal = corpo.telefone ? String(corpo.telefone).trim() : null;
  const email = corpo.email ? String(corpo.email).trim().slice(0, 200) : null;
  const mensagem = corpo.mensagem ? String(corpo.mensagem).trim().slice(0, 2000) : null;
  const telefone = normalizarTelefone(telefoneOriginal);

  const cliente = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Empresa tem de existir. Sem isto, um `empresa_id` inventado enchia a tabela
  // de linhas órfãs que ninguém veria (a foreign key apanharia, mas com erro
  // 500 em vez de resposta limpa).
  const { data: empresa } = await cliente
    .from("punho_empresas")
    .select("id")
    .eq("id", empresaId)
    .maybeSingle();
  if (!empresa) {
    return new Response(JSON.stringify({ erro: "empresa_desconhecida" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;

  // --- Classificação: aceite / retida / descartada -------------------------
  //
  // A maioria tem de cair em "aceite". Uma caixa de entrada que exige aprovar
  // tudo é só outro sítio para acumular trabalho, e a razão de existir isto é
  // poupar trabalho.
  let classificacao = "aceite";
  let motivo: string | null = null;

  // Robô: campo escondido que só um autómato preenche, e formulários
  // submetidos depressa de mais para terem sido escritos por alguém.
  const honeypot = String(corpo.website ?? "").trim();
  const msPreenchimento = Number(corpo.ms_preenchimento ?? 0);
  if (honeypot.length > 0) {
    classificacao = "descartada";
    motivo = "honeypot preenchido";
  } else if (msPreenchimento > 0 && msPreenchimento < 2000) {
    classificacao = "descartada";
    motivo = "submetido em menos de 2 segundos";
  } else if (!telefone && !emailPlausivel(email)) {
    // Sem forma nenhuma de contactar não é uma lead, é ruído.
    classificacao = "descartada";
    motivo = "sem contacto utilizável";
  } else if (!telefone) {
    classificacao = "retida";
    motivo = telefoneOriginal
      ? "telefone não reconhecido"
      : "sem telefone, só email";
  } else if (!nome) {
    classificacao = "retida";
    motivo = "sem nome";
  }

  // Ritmo: cinco por hora do mesmo IP chega e sobra para uma pessoa a sério.
  if (classificacao !== "descartada" && ip) {
    const desde = new Date(Date.now() - 3600_000).toISOString();
    const { count } = await cliente
      .from("punho_leads_entrada")
      .select("id", { count: "exact", head: true })
      .eq("empresa_id", empresaId)
      .eq("ip_origem", ip)
      .gte("recebida_em", desde);
    if ((count ?? 0) >= 5) {
      classificacao = "retida";
      motivo = "rajada do mesmo IP na última hora";
    }
  }

  // Deduplicação: o mesmo número já entrou nos últimos 30 dias e ainda não foi
  // processado. Não se cria uma segunda — seria a mesma pessoa a contar duas
  // vezes na conversão.
  if (classificacao === "aceite" && telefone) {
    const desde = new Date(Date.now() - 30 * 86400_000).toISOString();
    const { data: repetida } = await cliente
      .from("punho_leads_entrada")
      .select("id")
      .eq("empresa_id", empresaId)
      .eq("telefone_e164", telefone)
      .gte("recebida_em", desde)
      .limit(1);
    if (repetida && repetida.length > 0) {
      classificacao = "retida";
      motivo = "o mesmo número já tinha entrado nos últimos 30 dias";
    }
  }

  const { data: inserida, error } = await cliente
    .from("punho_leads_entrada")
    .insert({
      empresa_id: empresaId,
      origem,
      nome,
      telefone_e164: telefone,
      telefone_original: telefoneOriginal,
      email: emailPlausivel(email) ? email : null,
      mensagem,
      classificacao,
      motivo,
      payload_bruto: corpo,
      ip_origem: ip,
    })
    .select("id")
    .single();

  if (error) {
    console.error("[receber-lead] insert falhou:", error.message);
    return new Response(JSON.stringify({ erro: "nao_foi_possivel_gravar" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // A resposta é sempre a mesma para quem submete, mesmo quando é descartada:
  // dizer a um robô que foi apanhado é ensiná-lo a passar à próxima.
  return new Response(
    JSON.stringify({ recebida: true, id: inserida.id }),
    { headers: { "Content-Type": "application/json" } },
  );
});
