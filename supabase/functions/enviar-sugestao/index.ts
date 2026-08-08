import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Recebe sugestões do utilizador (Punho, WashInvoice, ...) e grava com
// service_role — os clientes móveis não têm (nem devem ter) permissão de
// INSERT directo em `sugestoes` para utilizadores autenticados; só o papel
// anon tinha essa política. Em vez de alargar RLS numa tabela partilhada com
// o WashInvoice, esta função faz a escrita do lado do servidor, com o pedido
// já autenticado a validar que quem chama tem sessão válida (verify_jwt).
//
// `nif` NUNCA vem do corpo do pedido: quem identifica a empresa é sempre o
// `machine_id`, cruzado com `licencas` por um trigger BEFORE INSERT na
// tabela (`identificar_por_terminal`). Um pedido sem `machine_id`, ou com um
// que nunca passou por `registar-terminal`, é recusado — não há identidade
// para aceitar. Isto fecha o buraco de um cliente poder simplesmente dizer
// a que empresa pertence.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ erro: "método não suportado" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let corpo: { texto?: string; app?: string; machine_id?: string };
  try {
    corpo = await req.json();
  } catch {
    return new Response(JSON.stringify({ erro: "json inválido" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const texto = (corpo.texto ?? "").trim();
  const app = (corpo.app ?? "").trim();
  const machineId = (corpo.machine_id ?? "").trim();
  if (texto === "" || app === "" || machineId === "") {
    return new Response(
      JSON.stringify({ erro: "texto, app e machine_id são obrigatórios" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error } = await supabase.from("sugestoes").insert({
    texto,
    app,
    machine_id: machineId,
  });

  if (error) {
    return new Response(JSON.stringify({ erro: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
