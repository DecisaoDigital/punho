#!/usr/bin/env node
//
// Compara o código das edge functions no repositório com o que está **mesmo**
// publicado em produção — e diz, antes de um deploy, se algum ficheiro está
// velho.
//
// Porquê: o perigo das edge functions não é a que falta, é a que **está e está
// velha**. Uma função editada pela consola web ou pelo MCP fica com o
// `entrypoint_path` em `/tmp/user_fn_...`; o ficheiro do repositório não muda.
// Se mais tarde alguém correr `supabase functions deploy` a partir do repo, a
// versão velha do repo **reverte produção sem deixar rasto no `git log`**. Já
// aconteceu com o `versao-mais-recente` (perdia `'punho_op'` do `APPS`) e com o
// `enviar-push` (perdia o prefixo `[PUNHO]` do título). Correr isto antes de
// publicar apanha a divergência a tempo.
//
// **Não compara texto.** O deploy do Deno transpila o TypeScript: apaga tipos,
// interfaces, `type`-aliases, imports usados só como tipo, o `!`, parênteses
// redundantes e vírgulas finais, e reformata tudo. Comparar texto dava dezenas
// de «diferenças» cosméticas. Em vez disso transpila-se o TS do repo para JS
// (a mesma erosão de tipos) e comparam-se as duas **árvores sintácticas**,
// ignorando os parênteses. Sobra só a lógica. Igual = igual de verdade.
//
// Uso:
//   node scripts/verificar-functions-vs-producao.mjs
//   node scripts/verificar-functions-vs-producao.mjs --dir supabase/functions
//
// Precisa do token de gestão em `~/.supabase/access-token` (o mesmo que o CLI
// usa). Sai com código 1 se houver deriva ou ficheiro em falta — serve de
// porteiro num `release.sh` ou num hook de pre-deploy.
//
// As duas dependências (`@deno/eszip` para abrir o bundle, `typescript` para
// transpilar) instalam-se sozinhas na primeira corrida, numa cache à parte,
// para não sujar este repositório de Dart com um `node_modules`.

import { readFileSync, existsSync, readdirSync, mkdirSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

const PROJECT_REF = "oefqbkhioncakojipqyx";
const API = `https://api.supabase.com/v1/projects/${PROJECT_REF}/functions`;

function arg(nome, omissao) {
  const i = process.argv.indexOf(nome);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : omissao;
}

// --- Dependências, instaladas à parte na primeira corrida --------------------
const cache = join(homedir(), ".cache", "punho-verificar-functions");
function garantirDeps() {
  const marca = join(cache, "node_modules", "typescript", "package.json");
  if (existsSync(marca)) return;
  console.error("A instalar dependências (só desta vez)…");
  mkdirSync(cache, { recursive: true });
  execFileSync("npm", ["init", "-y"], { cwd: cache, stdio: "ignore" });
  execFileSync("npm", ["install", "@deno/eszip@0.106.0", "typescript@5"], { cwd: cache, stdio: "inherit" });
}
garantirDeps();
const requireCache = createRequire(join(cache, "x.js"));
const ts = requireCache("typescript");
const { Parser } = await import(pathToFileURL(join(cache, "node_modules", "@deno", "eszip", "esm", "mod.js")).href);

// --- Assinatura da árvore, à prova de cosmética ------------------------------
function assinatura(textoJs) {
  const sf = ts.createSourceFile("x.js", textoJs, ts.ScriptTarget.Latest, false);
  const out = [];
  const transparentes = new Set([
    ts.SyntaxKind.ParenthesizedExpression,
    ts.SyntaxKind.NonNullExpression,
    ts.SyntaxKind.AsExpression,
    ts.SyntaxKind.TypeAssertionExpression,
    ts.SyntaxKind.SatisfiesExpression,
  ]);
  (function visita(node) {
    if (ts.isTypeNode(node)) return;
    if (transparentes.has(node.kind)) { visita(node.expression); return; }
    out.push(node.kind);
    if (
      node.kind === ts.SyntaxKind.StringLiteral ||
      node.kind === ts.SyntaxKind.NumericLiteral ||
      node.kind === ts.SyntaxKind.NoSubstitutionTemplateLiteral ||
      ts.isIdentifier(node) ||
      ts.isPrivateIdentifier(node)
    ) {
      out.push("" + node.text);
    }
    ts.forEachChild(node, visita);
  })(sf);
  return out.join("|");
}

function transpilar(ts_source) {
  return ts.transpileModule(ts_source, {
    compilerOptions: { target: ts.ScriptTarget.ESNext, module: ts.ModuleKind.ESNext, isolatedModules: true },
  }).outputText;
}

// --- Produção ---------------------------------------------------------------
const TOKEN = readFileSync(join(homedir(), ".supabase", "access-token"), "utf8").trim();

async function bytesDaFuncao(slug) {
  const resp = await fetch(`${API}/${slug}/body`, { headers: { Authorization: `Bearer ${TOKEN}` } });
  if (!resp.ok) throw new Error(`HTTP ${resp.status} ao buscar ${slug}`);
  return new Uint8Array(await resp.arrayBuffer());
}

async function fonteDaFuncao(slug) {
  const parser = await Parser.createInstance();
  const specs = await parser.parseBytes(await bytesDaFuncao(slug));
  await parser.load();
  const alvo = specs.find((x) => x.endsWith("source/index.ts")) || specs.find((x) => x.endsWith("index.ts"));
  return parser.getModuleSource(alvo);
}

// --- Corrida ----------------------------------------------------------------
const dir = arg("--dir", "supabase/functions");
const slugs = readdirSync(dir, { withFileTypes: true })
  .filter((d) => d.isDirectory() && existsSync(join(dir, d.name, "index.ts")))
  .map((d) => d.name)
  .sort();

if (slugs.length === 0) {
  console.error(`Sem functions em ${dir}`);
  process.exit(1);
}

let deriva = 0;
for (const slug of slugs) {
  let veredicto, detalhe = "";
  try {
    const live = await fonteDaFuncao(slug);
    const repo = transpilar(readFileSync(join(dir, slug, "index.ts"), "utf8"));
    if (assinatura(repo) === assinatura(live)) veredicto = "IDENTICA";
    else { veredicto = "DERIVA  "; deriva++; detalhe = "  <- repo != produção"; }
  } catch (e) {
    veredicto = "ERRO    "; deriva++; detalhe = "  " + e.message;
  }
  console.log(`${veredicto}  ${slug}${detalhe}`);
}

console.log(`\n${slugs.length} functions, ${deriva} com problema.`);
process.exit(deriva ? 1 : 0);
