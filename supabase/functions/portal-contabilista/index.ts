// O portal do contabilista.
//
// Uma página, um link, um token. Quem a abre não tem conta no Punho, não vê o
// painel e não fala com a base de dados: fala com esta função, que valida o
// token e escreve com `service_role`.
//
// Três invariantes que não se negoceiam:
//
//  1. **A empresa sai do token.** Nunca do corpo do pedido. É a função
//     `punho_guardar_resposta_contabilista` que a deriva do convite — aqui só
//     se passa o `convite_id`. Um portal que aceitasse `empresa_id` de fora
//     era um portal em que qualquer token escrevia na empresa de qualquer
//     outro.
//  2. **O token nunca aparece em log nem em resposta de erro.** Ele vive no
//     histórico do browser e em emails reencaminhados; o que se guarda na base
//     é o sha256.
//  3. **Campo vazio apaga.** Voltar a "não sei" tem de ser tão fácil como
//     escrever — é assim que se desfaz um número posto por engano.
//
// Deploy: `verify_jwt = false`. O contabilista não tem JWT nenhum, o token é a
// autenticação toda. É por isso que ele tem 256 bits de entropia e que uma
// resposta a token inválido não diz se ele não existe, se expirou ou se foi
// revogado.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { formatarEuros, paraCentavos } from "./euros.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

/** `2024-03-01` -> `Março de 2024`. */
function porExtenso(iso: string): string {
  return `${MESES[Number(iso.slice(5, 7)) - 1]} de ${iso.slice(0, 4)}`;
}

const MESES = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

// ---------------------------------------------------------------------------
// Utilitários
// ---------------------------------------------------------------------------

async function hashDoToken(token: string): Promise<string> {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function escapar(s: unknown): string {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function json(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function paginaDeErro(mensagem: string, status: number): Response {
  return new Response(
    `<!doctype html><html lang="pt"><head><meta charset="utf-8">
     <meta name="viewport" content="width=device-width,initial-scale=1">
     <title>Punho</title>
     <style>
       body{font:16px/1.6 system-ui,sans-serif;margin:0;display:grid;
            place-items:center;min-height:100vh;background:#f6f7f9;color:#1a1c1e}
       div{max-width:34rem;padding:2rem;text-align:center}
       h1{font-size:1.25rem;margin:0 0 .5rem}
       p{margin:0;color:#5a6068}
       @media(prefers-color-scheme:dark){
         body{background:#16181c;color:#e8eaed} p{color:#9aa0a6}
       }
     </style></head><body><div>
     <h1>${escapar(mensagem)}</h1>
     <p>Se acha que é engano, peça um link novo a quem lho enviou.</p>
     </div></body></html>`,
    { status, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );
}

// ---------------------------------------------------------------------------
// Convite
// ---------------------------------------------------------------------------

type Convite = {
  id: string;
  empresa_id: string;
  nome: string | null;
  /** O que o gestor pediu. */
  mes_inicial: string;
  /**
   * O que o contabilista disse que faz sentido pedir — a empresa pode não
   * existir desde o início do período. Encolhe a grelha e as lacunas; nunca
   * alarga. `null` enquanto ele não disser nada.
   */
  mes_inicial_efectivo: string | null;
  mes_final: string;
  submetido_em: string | null;
};

/**
 * Resolve o token para um convite, ou devolve null.
 *
 * Não distingue "não existe" de "expirou" de "foi revogado", e é de propósito:
 * a diferença só serve a quem está a tentar tokens à sorte.
 */
async function convitePorToken(token: string): Promise<Convite | null> {
  if (!token || token.length < 20) return null;

  const { data } = await supabase
    .from("punho_convites_contabilista")
    .select("id, empresa_id, nome, mes_inicial, mes_inicial_efectivo, mes_final, submetido_em, expira_em, revogado_em")
    .eq("token_hash", await hashDoToken(token))
    .maybeSingle();

  if (!data) return null;
  if (data.revogado_em) return null;
  if (new Date(data.expira_em) <= new Date()) return null;
  return data as Convite;
}

// ---------------------------------------------------------------------------
// A página
// ---------------------------------------------------------------------------

type Rubrica = {
  chave: string;
  rotulo: string;
  ajuda: string | null;
  periodicidade: "mensal" | "unica";
  tipo: "euros" | "texto" | "opcao";
  opcoes: string[];
  aceita_anual: boolean;
};

type Resposta = {
  rubrica: string;
  mes: string | null;
  ano: number | null;
  valor_centavos: number | null;
  valor_texto: string | null;
};

async function desenharPagina(convite: Convite, token: string): Promise<Response> {
  const [rubricasRes, respostasRes, empresaRes] = await Promise.all([
    supabase.from("punho_rubricas_contabilista")
      .select("chave, rotulo, ajuda, periodicidade, tipo, opcoes, aceita_anual")
      .eq("activa", true).order("ordem"),
    supabase.from("punho_respostas_contabilista")
      .select("rubrica, mes, ano, valor_centavos, valor_texto")
      .eq("empresa_id", convite.empresa_id),
    supabase.from("punho_empresas")
      .select("nome, dados").eq("id", convite.empresa_id).maybeSingle(),
  ]);

  const rubricas = (rubricasRes.data ?? []) as Rubrica[];
  const respostas = (respostasRes.data ?? []) as Resposta[];

  // Quem pede os dados tem de se identificar antes de os pedir.
  //
  // Um contabilista tem dezenas de clientes e recebe links por email. "Dados
  // históricos de a empresa" não lhe diz de quem são — e um contabilista que
  // não tem a certeza de que cliente está a preencher ou não preenche, ou
  // preenche o do lado. O NIF é o que desfaz qualquer dúvida: dois clientes
  // podem chamar-se parecido, o número é um só.
  const dados = (empresaRes.data?.dados ?? {}) as Record<string, unknown>;
  const empresa = (dados.nome_comercial as string) ||
    (empresaRes.data?.nome as string) || "a empresa";
  const nomeLegal = (empresaRes.data?.nome as string) || "";
  const nif = (dados.nif as string) || "";
  const morada = [dados.morada, dados.codigo_postal, dados.localidade]
    .filter((p) => typeof p === "string" && p.trim() !== "").join(", ");

  // Indexa as respostas para lookup directo enquanto se desenha a grelha.
  const porMes = new Map<string, Resposta>();
  const porAno = new Map<string, Resposta>();
  const estruturais = new Map<string, Resposta>();
  for (const r of respostas) {
    if (r.mes) porMes.set(`${r.rubrica}|${r.mes}`, r);
    else if (r.ano) porAno.set(`${r.rubrica}|${r.ano}`, r);
    else estruturais.set(r.rubrica, r);
  }

  const mensais = rubricas.filter((r) => r.periodicidade === "mensal");
  const unicas = rubricas.filter((r) => r.periodicidade === "unica");

  // A janela do convite, mês a mês, agrupada por ano.
  //
  // Começa no que o contabilista disse, se disse. O período pedido continua a
  // ser o do convite — é dentro dele que a base aceita escritas — mas mostrar
  // trinta e seis meses anteriores à existência da empresa é fazer perder tempo
  // a quem está a fazer um favor.
  const inicioPedido = new Date(convite.mes_inicial + "T00:00:00Z");
  const inicio = new Date(
    (convite.mes_inicial_efectivo ?? convite.mes_inicial) + "T00:00:00Z",
  );
  const fim = new Date(convite.mes_final + "T00:00:00Z");

  // Todos os meses do período pedido, para o selector de início.
  const mesesPossiveis: string[] = [];
  for (
    let d = new Date(inicioPedido); d <= fim; d.setUTCMonth(d.getUTCMonth() + 1)
  ) {
    mesesPossiveis.push(
      `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-01`,
    );
  }
  const anos = new Map<number, string[]>();
  for (let d = new Date(inicio); d <= fim; d.setUTCMonth(d.getUTCMonth() + 1)) {
    const ano = d.getUTCFullYear();
    const iso = `${ano}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-01`;
    if (!anos.has(ano)) anos.set(ano, []);
    anos.get(ano)!.push(iso);
  }
  const anosDesc = [...anos.keys()].sort((a, b) => b - a);

  const campoEuros = (
    rubrica: string, valor: number | null, mes: string | null, ano: number | null,
  ) =>
    `<input type="text" inputmode="decimal" class="euros"
       data-rubrica="${escapar(rubrica)}"
       ${mes ? `data-mes="${escapar(mes)}"` : ""}
       ${ano ? `data-ano="${ano}"` : ""}
       value="${escapar(formatarEuros(valor))}"
       aria-label="${escapar(rubrica)} ${escapar(mes ?? ano ?? "")}">`;

  const seccoesAnuais = anosDesc.map((ano, i) => {
    const meses = anos.get(ano)!;
    const preenchidos = meses.reduce(
      (n, m) => n + mensais.filter((r) => porMes.has(`${r.chave}|${m}`)).length, 0,
    );
    const total = meses.length * mensais.length;

    const linhas = meses.map((iso) => {
      const nomeMes = MESES[Number(iso.slice(5, 7)) - 1];
      const celulas = mensais.map((r) =>
        `<td>${campoEuros(r.chave, porMes.get(`${r.chave}|${iso}`)?.valor_centavos ?? null, iso, null)}</td>`
      ).join("");
      return `<tr><th scope="row">${nomeMes}</th>${celulas}</tr>`;
    }).join("");

    const linhaAnual = mensais.map((r) =>
      r.aceita_anual
        ? `<td>${campoEuros(r.chave, porAno.get(`${r.chave}|${ano}`)?.valor_centavos ?? null, null, ano)}</td>`
        : `<td class="vazia" title="Esta rubrica não aceita total anual">—</td>`
    ).join("");

    return `
    <details class="ano" ${i === 0 ? "open" : ""}>
      <summary>
        <span class="ano-titulo">${ano}</span>
        <span class="progresso" data-ano="${ano}">${preenchidos} de ${total}</span>
      </summary>
      <div class="tabela-envolvente">
        <table>
          <thead><tr><th scope="col">Mês</th>${
            mensais.map((r) =>
              `<th scope="col">${escapar(r.rotulo.replace(" do mês", ""))}
                 ${r.ajuda ? `<span class="ajuda" title="${escapar(r.ajuda)}">?</span>` : ""}</th>`
            ).join("")
          }</tr></thead>
          <tbody>${linhas}</tbody>
          <tfoot>
            <tr class="total-ano">
              <th scope="row">Não sei os meses<br><small>Total de ${ano}</small></th>
              ${linhaAnual}
            </tr>
          </tfoot>
        </table>
      </div>
      <p class="nota">
        O total do ano só é usado nos meses que ficarem por preencher, e o Punho
        assinala esses meses como estimativa. Cada mês que escrever aqui em cima
        passa a valer por si — e corrige também a estimativa dos vizinhos.
      </p>
    </details>`;
  }).join("");

  const campoUnico = (r: Rubrica) => {
    const actual = estruturais.get(r.chave)?.valor_texto ?? "";
    if (r.tipo === "opcao") {
      const opcoes = r.opcoes.map((o) =>
        `<option value="${escapar(o)}"${o === actual ? " selected" : ""}>${escapar(o)}</option>`
      ).join("");
      return `<select class="texto" data-rubrica="${escapar(r.chave)}">
                <option value="">— não sei —</option>${opcoes}</select>`;
    }
    return `<input type="text" class="texto" data-rubrica="${escapar(r.chave)}"
              value="${escapar(actual)}">`;
  };

  const seccaoEmpresa = unicas.map((r) => `
    <div class="campo">
      <label>${escapar(r.rotulo)}</label>
      ${campoUnico(r)}
      ${r.ajuda ? `<small>${escapar(r.ajuda)}</small>` : ""}
    </div>`).join("");

  const html = `<!doctype html>
<html lang="pt"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Punho — dados de ${escapar(empresa)}</title>
<style>
  :root{
    --margem-pagina:2rem; --margem-seccao:1.5rem; --margem-campo:.75rem;
    --fundo:#f6f7f9; --papel:#fff; --tinta:#1a1c1e; --tinta-fraca:#5a6068;
    --linha:#dfe3e8; --acento:#1f6feb; --ok:#137333;
  }
  @media(prefers-color-scheme:dark){
    :root{--fundo:#16181c;--papel:#1e2126;--tinta:#e8eaed;--tinta-fraca:#9aa0a6;
          --linha:#31353b;--acento:#63a4ff;--ok:#5bb974}
  }
  *{box-sizing:border-box}
  body{font:16px/1.55 system-ui,-apple-system,Segoe UI,sans-serif;margin:0;
       background:var(--fundo);color:var(--tinta)}
  main{max-width:64rem;margin:0 auto;padding:var(--margem-pagina) 1rem 6rem}
  header{margin-bottom:var(--margem-seccao)}
  h1{font-size:1.4rem;margin:0 0 .25rem}
  header p{margin:.25rem 0 0;color:var(--tinta-fraca);max-width:44rem}
  /* Identificação da empresa: duas colunas, rótulo à esquerda. É a primeira
     coisa que o contabilista precisa de ler — de quem são estes dados. */
  dl.identificacao{display:grid;grid-template-columns:auto 1fr;gap:.15rem .75rem;
    margin:.75rem 0 0;font-size:.9rem;max-width:44rem}
  dl.identificacao dt{color:var(--tinta-fraca)}
  dl.identificacao dd{margin:0}
  dl.identificacao em{color:var(--tinta-fraca)}
  .porque p{margin:0 0 .75rem;max-width:44rem}
  .porque p:last-child{margin-bottom:0}
  .miudinho{color:var(--tinta-fraca);font-size:.9rem}
  label[for=inicio]{display:block;margin-bottom:.35rem;font-size:.9rem;
    color:var(--tinta-fraca)}
  section,details.ano{background:var(--papel);border:1px solid var(--linha);
    border-radius:.6rem;margin-bottom:var(--margem-seccao)}
  section{padding:var(--margem-seccao)}
  h2{font-size:1.05rem;margin:0 0 var(--margem-campo)}
  summary{cursor:pointer;padding:.9rem var(--margem-seccao);display:flex;
    justify-content:space-between;align-items:center;gap:1rem;font-weight:600}
  .progresso{font-weight:400;font-size:.85rem;color:var(--tinta-fraca)}
  .tabela-envolvente{overflow-x:auto;padding:0 var(--margem-seccao)}
  table{border-collapse:collapse;width:100%;min-width:38rem}
  th,td{padding:.35rem .4rem;text-align:left;border-bottom:1px solid var(--linha)}
  thead th{font-size:.8rem;color:var(--tinta-fraca);font-weight:600;
    position:sticky;top:0;background:var(--papel)}
  tbody th{font-weight:400;color:var(--tinta-fraca);white-space:nowrap}
  input,select{font:inherit;width:100%;padding:.35rem .5rem;border-radius:.35rem;
    border:1px solid var(--linha);background:transparent;color:inherit}
  input.euros{text-align:right;font-variant-numeric:tabular-nums}
  input:focus,select:focus{outline:2px solid var(--acento);outline-offset:-1px;
    border-color:transparent}
  input.guardado{border-color:var(--ok)}
  input.erro{border-color:#d93025}
  .total-ano th{font-weight:600;color:var(--tinta)}
  .total-ano small{font-weight:400;color:var(--tinta-fraca)}
  td.vazia{color:var(--tinta-fraca);text-align:center}
  .ajuda{display:inline-grid;place-items:center;width:1rem;height:1rem;
    border-radius:50%;background:var(--linha);font-size:.7rem;cursor:help}
  .nota{color:var(--tinta-fraca);font-size:.85rem;
    padding:var(--margem-campo) var(--margem-seccao) var(--margem-seccao)}
  .campo{margin-bottom:var(--margem-campo)}
  .campo label{display:block;font-size:.9rem;margin-bottom:.2rem}
  .campo small{display:block;color:var(--tinta-fraca);font-size:.8rem;margin-top:.2rem}
  textarea{font:inherit;width:100%;min-height:6rem;padding:.5rem;
    border:1px solid var(--linha);border-radius:.35rem;background:transparent;color:inherit}
  button{font:inherit;font-weight:600;padding:.6rem 1.2rem;border:0;
    border-radius:.4rem;background:var(--acento);color:#fff;cursor:pointer}
  button:disabled{opacity:.5;cursor:default}
  #estado{position:fixed;left:50%;transform:translateX(-50%);bottom:1rem;
    background:var(--tinta);color:var(--papel);padding:.5rem 1rem;
    border-radius:2rem;font-size:.85rem;opacity:0;transition:opacity .2s}
  #estado.visivel{opacity:1}
</style></head>
<body><main>
<header>
  <h1>Dados históricos de ${escapar(empresa)}</h1>
  <dl class="identificacao">
    ${nomeLegal && nomeLegal !== empresa
      ? `<dt>Denominação</dt><dd>${escapar(nomeLegal)}</dd>`
      : ""}
    <dt>NIF</dt><dd>${nif ? escapar(nif) : "<em>não indicado</em>"}</dd>
    ${morada ? `<dt>Sede</dt><dd>${escapar(morada)}</dd>` : ""}
    <dt>Período</dt>
    <dd id="periodo-actual">${
      escapar(porExtenso(convite.mes_inicial_efectivo ?? convite.mes_inicial))
    } a ${escapar(porExtenso(convite.mes_final))}${
      // Quando ele encolheu o período, o cabeçalho tem de mostrar o que está
      // mesmo na grelha — senão anuncia meses que a página não tem. O que foi
      // pedido fica dito a seguir, porque continua a ser informação: é a
      // diferença entre o que o gestor julgava e o que a empresa é.
      convite.mes_inicial_efectivo &&
        convite.mes_inicial_efectivo !== convite.mes_inicial
        ? `<br><small>Tinham sido pedidos desde ${
          escapar(porExtenso(convite.mes_inicial))
        }</small>`
        : ""
    }</dd>
  </dl>
</header>

<section class="porque">
  <h2>Porque é que lhe pedimos isto</h2>
  <p>
    ${escapar(empresa)} começou a usar o Punho, uma aplicação de gestão que
    mostra ao empresário como está o negócio mês a mês — quanto entrou, quanto
    custou, e se está melhor ou pior do que no ano passado.
  </p>
  <p>
    Essa última parte é a que não funciona sem si. A aplicação só conhece o que
    aconteceu depois de ter sido instalada, por isso a comparação com o ano
    anterior fica vazia durante doze meses. Os números do passado existem, mas
    estão consigo, não com ele.
  </p>
  <p>
    <strong>O que se espera:</strong> preencher a grelha abaixo com o que já tem
    fechado. Não é um trabalho novo — são valores que já saíram das contas que
    fez. Deixe em branco o que não souber: em branco não é zero, e ninguém
    espera que saiba tudo. Se de um ano só souber o total, escreva o total; a
    aplicação usa-o e marca-o como estimativa.
  </p>
  <p class="miudinho">
    Cada campo grava sozinho, e o valor volta escrito como ficou entendido —
    confira-o. Pode fechar e voltar a este link mais tarde, e pode corrigir o
    que já escreveu, mesmo depois de dizer que acabou. Não precisa de conta nem
    de instalar nada.
  </p>
</section>

<section>
  <h2>O período</h2>
  <p class="miudinho">
    Pedimos ${
      mesesPossiveis.length >= 12
        ? `${Math.round(mesesPossiveis.length / 12)} anos`
        : `${mesesPossiveis.length} meses`
    } por omissão. Se a empresa não existia assim há tanto tempo, diga daqui a
    partir de quando faz sentido — o resto desaparece da grelha e deixa de ser
    pedido a ninguém.
  </p>
  <label for="inicio">Começar em</label>
  <select id="inicio">
    ${
      mesesPossiveis.map((iso) =>
        `<option value="${iso}"${
          iso === (convite.mes_inicial_efectivo ?? convite.mes_inicial)
            ? " selected"
            : ""
        }>${escapar(porExtenso(iso))}</option>`
      ).join("")
    }
  </select>
</section>

<section>
  <h2>Sobre a empresa</h2>
  ${seccaoEmpresa}
</section>

${seccoesAnuais}

<section>
  <h2>Alguma coisa a dizer?</h2>
  <p style="margin:0 0 var(--margem-campo);color:var(--tinta-fraca);font-size:.9rem">
    Uma dúvida, um aviso, um pedido de ajuda. Vai direita a quem lhe pediu estes dados.
  </p>
  <textarea id="mensagem" placeholder="Escreva aqui…"></textarea>
  <div style="margin-top:var(--margem-campo);display:flex;gap:.75rem;align-items:center">
    <button id="enviar-mensagem" type="button">Enviar mensagem</button>
  </div>
</section>

<section>
  <h2>Terminou?</h2>
  <p style="margin:0 0 var(--margem-campo);color:var(--tinta-fraca);font-size:.9rem">
    Diga que acabou para o gestor saber que pode contar com estes números. O que
    ficar por preencher passa a aparecer na lista de tarefas dele. O link
    continua a funcionar se depois quiser corrigir alguma coisa.
  </p>
  <button id="submeter" type="button"${convite.submetido_em ? " disabled" : ""}>
    ${convite.submetido_em ? "Já submetido — pode continuar a corrigir" : "Terminei"}
  </button>
</section>
</main>
<div id="estado" role="status" aria-live="polite"></div>

<script>
const TOKEN = ${JSON.stringify(token)};
const estado = document.getElementById('estado');
let timerEstado;

function dizer(texto){
  estado.textContent = texto;
  estado.classList.add('visivel');
  clearTimeout(timerEstado);
  timerEstado = setTimeout(() => estado.classList.remove('visivel'), 2200);
}

async function pedir(corpo){
  const r = await fetch(location.pathname + '?t=' + encodeURIComponent(TOKEN), {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(corpo),
  });
  if (!r.ok) throw new Error('falhou');
  return r.json();
}

async function guardar(campo){
  const corpo = {
    accao: 'guardar',
    rubrica: campo.dataset.rubrica,
    mes: campo.dataset.mes || null,
    ano: campo.dataset.ano ? Number(campo.dataset.ano) : null,
    valor: campo.value,
  };
  campo.classList.remove('erro','guardado');
  try {
    const r = await pedir(corpo);
    // O servidor devolve o valor como o interpretou. Repô-lo no campo é o que
    // impede alguém de escrever 1.200 a pensar em mil e duzentos e ficar com
    // um euro e vinte sem dar por isso.
    if (r.formatado !== undefined) campo.value = r.formatado;
    campo.classList.add('guardado');
    setTimeout(() => campo.classList.remove('guardado'), 1200);
    actualizarProgresso();
  } catch {
    campo.classList.add('erro');
    dizer('Não consegui guardar. Verifique a ligação.');
  }
}

function actualizarProgresso(){
  document.querySelectorAll('details.ano').forEach(d => {
    const campos = d.querySelectorAll('tbody input.euros');
    const cheios = [...campos].filter(c => c.value.trim() !== '').length;
    const alvo = d.querySelector('.progresso');
    if (alvo) alvo.textContent = cheios + ' de ' + campos.length;
  });
}

document.querySelectorAll('input.euros, input.texto').forEach(c => {
  c.addEventListener('change', () => guardar(c));
});

// Encolher o período recarrega a página. Podia mexer-se no DOM e esconder os
// anos a mais, mas a grelha, o progresso de cada ano e a linha do total anual
// teriam de ser recalculados à mão em três sítios — e um deles ficaria por
// actualizar. O servidor já sabe desenhar isto certo; deixa-se desenhar.
const seletorInicio = document.getElementById('inicio');
if (seletorInicio) {
  seletorInicio.addEventListener('change', async () => {
    seletorInicio.disabled = true;
    try {
      await pedir({accao: 'periodo', mes: seletorInicio.value});
      location.reload();
    } catch {
      seletorInicio.disabled = false;
      dizer('Não consegui mudar o período. Verifique a ligação.');
    }
  });
}
document.querySelectorAll('select.texto').forEach(s => {
  s.addEventListener('change', () => guardar(s));
});

document.getElementById('enviar-mensagem').addEventListener('click', async (e) => {
  const caixa = document.getElementById('mensagem');
  if (!caixa.value.trim()) { dizer('A mensagem está vazia.'); return; }
  e.target.disabled = true;
  try {
    await pedir({accao: 'mensagem', texto: caixa.value});
    caixa.value = '';
    dizer('Mensagem enviada.');
  } catch {
    dizer('Não consegui enviar.');
  }
  e.target.disabled = false;
});

document.getElementById('submeter').addEventListener('click', async (e) => {
  e.target.disabled = true;
  try {
    await pedir({accao: 'submeter'});
    e.target.textContent = 'Já submetido — pode continuar a corrigir';
    dizer('Obrigado. O gestor já sabe que pode contar com estes números.');
  } catch {
    dizer('Não consegui registar.');
    e.target.disabled = false;
  }
});

actualizarProgresso();
</script>
</body></html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      // A página tem dados de uma empresa. Não é para ficar em cache de
      // proxies nem para ser indexada.
      "Cache-Control": "no-store, private",
      "Referrer-Policy": "no-referrer",
    },
  });
}

// ---------------------------------------------------------------------------
// Escrita
// ---------------------------------------------------------------------------

async function tratarPost(convite: Convite, req: Request): Promise<Response> {
  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return json({ erro: "corpo inválido" }, 400);
  }

  switch (corpo.accao) {
    case "guardar": {
      const rubrica = String(corpo.rubrica ?? "");
      if (!rubrica) return json({ erro: "rubrica em falta" }, 400);

      const { data: r } = await supabase
        .from("punho_rubricas_contabilista")
        .select("tipo").eq("chave", rubrica).maybeSingle();
      if (!r) return json({ erro: "rubrica desconhecida" }, 400);

      const bruto = String(corpo.valor ?? "");
      const emEuros = r.tipo === "euros";
      const centavos = emEuros ? paraCentavos(bruto) : null;

      if (emEuros && bruto.trim() !== "" && centavos === null) {
        return json({ erro: "Não percebi esse número." }, 400);
      }

      const { error } = await supabase.rpc(
        "punho_guardar_resposta_contabilista",
        {
          p_convite: convite.id,
          p_rubrica: rubrica,
          p_mes: corpo.mes ?? null,
          p_ano: corpo.ano ?? null,
          p_valor_centavos: centavos,
          p_valor_texto: emEuros ? null : bruto,
        },
      );
      if (error) return json({ erro: error.message }, 400);

      return json({ formatado: emEuros ? formatarEuros(centavos) : bruto.trim() });
    }

    // O contabilista corrige o período que lhe pediram.
    //
    // Só encolhe, e a validação está na base — a página oferece apenas meses
    // do período pedido, mas quem tem o token monta o `POST` à mão. Mesma
    // lição da janela de escrita: validar no browser é cortesia, não
    // segurança.
    case "periodo": {
      const mes = corpo.mes ? String(corpo.mes) : null;
      const { data, error } = await supabase.rpc(
        "punho_definir_periodo_contabilista",
        { p_convite: convite.id, p_mes_inicial: mes },
      );
      if (error) return json({ erro: error.message }, 400);
      return json({ inicio: data });
    }

    case "mensagem": {
      const texto = String(corpo.texto ?? "").trim();
      if (!texto) return json({ erro: "mensagem vazia" }, 400);
      await supabase.from("punho_mensagens_contabilista").insert({
        empresa_id: convite.empresa_id,
        convite_id: convite.id,
        texto: texto.slice(0, 4000),
      });
      return json({ ok: true });
    }

    case "submeter": {
      await supabase.from("punho_convites_contabilista")
        .update({ submetido_em: new Date().toISOString() })
        .eq("id", convite.id)
        .is("submetido_em", null);
      return json({ ok: true });
    }

    default:
      return json({ erro: "acção desconhecida" }, 400);
  }
}

// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("t") ?? "";
  const convite = await convitePorToken(token);

  if (!convite) {
    return req.method === "GET"
      ? paginaDeErro("Este link já não é válido.", 404)
      : json({ erro: "link inválido" }, 401);
  }

  if (req.method === "GET") {
    // Regista a primeira abertura, para o gestor saber que o link chegou lá.
    if (!convite.submetido_em) {
      await supabase.from("punho_convites_contabilista")
        .update({ aberto_em: new Date().toISOString() })
        .eq("id", convite.id)
        .is("aberto_em", null);
    }
    return desenharPagina(convite, token);
  }

  if (req.method === "POST") return tratarPost(convite, req);

  return json({ erro: "método não suportado" }, 405);
});
