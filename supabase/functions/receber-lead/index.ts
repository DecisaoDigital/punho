import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { validarHorarioPedido } from "./horario.ts";
import { validarCategoria } from "./categorias.ts";
import { configPublica, lerConfig, type Tipo } from "./config.ts";

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
//
// Estes são dados de **terceiros**: gente que nunca instalou a app e nunca nos
// disse nada. Por isso cada linha guarda também o que autoriza guardá-la — ver
// `base_legal` e a migração 20260812060000. O contrato com quem submete é:
//
//   "consentimento": { "aceite": true, "texto": "<o que a pessoa aceitou>",
//                      "versao": "2026-08", "url": "https://..." }
//
// `texto` é o que faz a prova; `versao` e `url` só ajudam a reconstituir a
// página. Quem não manda nada e vem de um canal onde a pessoa nos procurou
// (telefone, WhatsApp, agenda) tem base legal própria e não precisa disto.

const VIAS = ["funil", "bot", "manual"];
const TIPOS = ["servico", "aluguer", "venda"] as const;

const ORIGENS = ["landing_page", "whatsapp", "telefone", "agenda", "manual", "outro"];

// Que base legal cada canal traz consigo, quando não vem prova nenhuma agarrada.
//
// Quem telefona, manda mensagem ou aparece na agenda **procurou o negócio**. Isso
// é diligência pré-contratual a pedido do titular (art. 6.º/1/b) e é uma base
// legal por direito próprio — pedir consentimento a quem acabou de ligar a pedir
// orçamento seria teatro.
//
// Um formulário público é outra coisa: a redacção é nossa, ninguém falou com
// ninguém, e o que autoriza guardar aquilo é o que a pessoa marcou. Sem prova
// disso, não há base — e o canal fica de fora deste mapa de propósito.
const BASE_LEGAL_DO_CANAL: Record<string, string> = {
  whatsapp: "diligencia_pre_contratual",
  telefone: "diligencia_pre_contratual",
  agenda: "diligencia_pre_contratual",
};

/// O que o formulário diz que a pessoa aceitou.
///
/// Duas coisas têm de vir: que aceitou, e **o quê**. Uma caixinha marcada sem o
/// texto ao lado não é demonstrável seis meses depois, que é precisamente o que
/// o art. 7.º/1 exige — poder demonstrar. Versão e endereço são bem-vindos e não
/// obrigatórios: ajudam a reconstituir a página, não fazem a prova.
function lerConsentimento(bruto: unknown) {
  if (!bruto || typeof bruto !== "object") return null;
  const c = bruto as Record<string, unknown>;
  if (c.aceite !== true) return null;
  const texto = c.texto ? String(c.texto).trim().slice(0, 2000) : "";
  if (texto.length === 0) return null;
  return {
    texto,
    versao: c.versao ? String(c.versao).trim().slice(0, 60) : null,
    url: c.url ? String(c.url).trim().slice(0, 500) : null,
  };
}

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
  // O assistente pergunta-nos como se chama a empresa, como se chama ele e o que ela
  // oferece. Nunca os horários: esses valida o servidor. O `empresa_id` não adivinha-se.
  if (req.method === "GET") {
    const id = (new URL(req.url).searchParams.get("empresa_id") ?? "").trim();
    if (!/^[0-9a-f-]{36}$/i.test(id)) {
      return new Response(JSON.stringify({ erro: "empresa_invalida" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    const c = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data } = await c.from("punho_atendimento_config").select("*").eq("empresa_id", id).maybeSingle();
    const cfg = lerConfig(data);
    return new Response(JSON.stringify(cfg ? configPublica(cfg) : { erro: "sem_configuracao" }), {
      status: cfg ? 200 : 404,
      headers: { "Content-Type": "application/json" },
    });
  }
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

  // A ficha do CRM. Tudo opcional: o que não vem fica em branco e a ficha
  // mostra «x/6». Quem capta (funil ou assistente) só entrega; quem valida é
  // sempre uma pessoa, do lado do Fist.
  const curto = (v: unknown, n: number) => {
    const t = v ? String(v).trim().slice(0, n) : "";
    return t.length > 0 ? t : null;
  };
  const negocio = curto(corpo.negocio, 200);
  const codigoPostal = curto(corpo.codigo_postal, 12);
  const localidade = curto(corpo.localidade, 120);
  const morada = curto(corpo.morada, 300);
  const interesse = curto(corpo.interesse, 300);
  const via = VIAS.includes(String(corpo.via)) ? String(corpo.via) : null;
  // O horário pedido valida-se contra o da empresa. Se não cabe, a lead entra na
  // mesma — sem o horário — e a resposta diz porquê, para o assistente voltar a
  // perguntar. Perder a lead por causa de uma hora mal dita seria pior.
  // A prova, quando vem, vale para qualquer canal — e quando não vem, o canal
  // responde por si. Um `outro` sem prova fica sem base legal, e é para ficar:
  // «não sei de onde veio isto» é uma resposta melhor do que inventar uma.
  const consentimento = lerConsentimento(corpo.consentimento);
  const baseLegal = consentimento
    ? "consentimento"
    : (BASE_LEGAL_DO_CANAL[origem] ?? "nao_registada");

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

  // O contexto da empresa: o que oferece, as suas categorias e os seus horários.
  // Nada disto vive no código; sem configuração só se exige o que é universal.
  const { data: linhaConfig } = await cliente
    .from("punho_atendimento_config")
    .select("*")
    .eq("empresa_id", empresaId)
    .maybeSingle();
  const config = lerConfig(linhaConfig);

  const tipoPedido = (TIPOS as readonly string[]).includes(String(corpo.tipo))
    ? (String(corpo.tipo) as Tipo)
    : null;
  // Um tipo que a empresa não oferece não se guarda: a lead entra na mesma e a
  // resposta diz o que a empresa oferece, para se voltar a perguntar.
  const tipoOferecido = tipoPedido === null || !config || config.tipos.length === 0 ||
    config.tipos.includes(tipoPedido);
  const tipo = tipoOferecido ? tipoPedido : null;
  const respostaTipo = tipoOferecido
    ? { ok: true }
    : { ok: false, motivo: "nao_oferecido", opcoes: config!.tipos };
  // Dias de aluguer pedidos. Se ficam fora da tabela de preços é a app que o
  // diz (a tabela vive nas máquinas): essa lead não entra na escala de entregas,
  // vai a um humano, de preferência o gerente.
  const dias = Number(corpo.periodo_dias);
  const periodoDias = tipo === "aluguer" && Number.isInteger(dias) && dias >= 1 && dias <= 3650
    ? dias
    : null;
  const horario = validarHorarioPedido(corpo.horario_pedido, config, tipo);
  // Quem pede serviço, aluguer ou venda tem de dizer a categoria; sem isso a
  // lead entra na mesma e a resposta devolve as opções para se voltar a perguntar.
  const categoria = validarCategoria(corpo.categoria, config, tipo !== null);
  const categoriaGuardada = categoria.ok ? categoria.categoria : null;
  const respostaCategoria = categoria.ok
    ? { ok: true }
    : { ok: false, motivo: categoria.motivo, opcoes: categoria.opcoes };


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

  // Deduplicação: o mesmo número já entrou nos últimos 30 dias. Não se cria uma
  // segunda — seria a mesma pessoa a contar duas vezes na conversão.
  //
  // Se a primeira ainda não foi puxada pela app, a repetição **completa-a**: é a
  // pessoa a acrescentar o que faltava (a zona, o dia pedido). Só preenche
  // buracos e actualiza o pedido; nunca apaga nem reescreve o que já lá estava.
  // Se já foi processada, não há nada a actualizar — fica retida para alguém ver.
  if (classificacao !== "descartada" && telefone) {
    const desde = new Date(Date.now() - 30 * 86400_000).toISOString();
    const { data: repetida } = await cliente
      .from("punho_leads_entrada")
      .select(
        "id, processada_em, nome, email, negocio, codigo_postal, localidade, morada",
      )
      .eq("empresa_id", empresaId)
      .eq("telefone_e164", telefone)
      .gte("recebida_em", desde)
      .order("recebida_em", { ascending: false })
      .limit(1);
    const anterior = repetida?.[0];
    if (anterior && !anterior.processada_em) {
      const preencher = (atual: string | null, novo: string | null) =>
        atual && atual.trim().length > 0 ? undefined : (novo ?? undefined);
      const campos: Record<string, unknown> = {
        nome: preencher(anterior.nome, nome),
        email: preencher(anterior.email, emailPlausivel(email) ? email : null),
        negocio: preencher(anterior.negocio, negocio),
        codigo_postal: preencher(anterior.codigo_postal, codigoPostal),
        localidade: preencher(anterior.localidade, localidade),
        morada: preencher(anterior.morada, morada),
        // O pedido mais recente é o que vale.
        interesse: interesse ?? undefined,
        tipo: tipo ?? undefined,
        categoria: categoriaGuardada ?? undefined,
        periodo_dias: periodoDias ?? undefined,
        horario_pedido: horario.ok ? (horario.instante ?? undefined) : undefined,
        mensagem: mensagem ?? undefined,
      };
      for (const k of Object.keys(campos)) {
        if (campos[k] === undefined) delete campos[k];
      }
      if (Object.keys(campos).length > 0) {
        await cliente.from("punho_leads_entrada").update(campos).eq("id", anterior.id);
      }
      return new Response(
        JSON.stringify({
          recebida: true,
          id: anterior.id,
          atualizada: true,
          horario: horario.ok ? { ok: true } : { ok: false, motivo: horario.motivo },
          categoria: respostaCategoria,
          tipo: respostaTipo,
        }),
        { headers: { "Content-Type": "application/json" } },
      );
    }
    if (anterior && classificacao === "aceite") {
      classificacao = "retida";
      motivo = "o mesmo número já tinha entrado nos últimos 30 dias";
    }
  }

  // Por último, e de propósito depois da deduplicação: sem base legal registada
  // a lead **não entra sozinha no pipeline**. Fica retida, que é o estado que
  // obriga alguém a olhar para ela antes de os dados serem copiados para o log
  // de operações — onde apagar já não é apagar, é redigir.
  //
  // Não se descarta nem se recusa a submissão. A pessoa do outro lado escreveu de
  // boa fé e não tem culpa de o formulário estar mal feito; e recusar deixava-nos
  // sem saber que o formulário está mal feito.
  if (baseLegal === "nao_registada" && classificacao !== "descartada") {
    classificacao = "retida";
    motivo = "sem base legal registada";
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
      negocio,
      codigo_postal: codigoPostal,
      localidade,
      morada,
      interesse,
      tipo,
      categoria: categoriaGuardada,
      periodo_dias: periodoDias,
      horario_pedido: horario.ok ? horario.instante : null,
      via,
      classificacao,
      motivo,
      payload_bruto: corpo,
      ip_origem: ip,
      base_legal: baseLegal,
      // O carimbo é nosso, não do formulário: o instante que o lado de lá diz
      // ter acontecido é forjável, e a diferença entre os dois são segundos.
      consentimento_texto: consentimento?.texto ?? null,
      consentimento_versao: consentimento?.versao ?? null,
      consentimento_url: consentimento?.url ?? null,
      consentimento_em: consentimento ? new Date().toISOString() : null,
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
    JSON.stringify({
      recebida: true,
      id: inserida.id,
      horario: horario.ok ? { ok: true } : { ok: false, motivo: horario.motivo },
      categoria: respostaCategoria,
      tipo: respostaTipo,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
