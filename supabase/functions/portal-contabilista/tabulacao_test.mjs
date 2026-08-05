// npm i jsdom && node supabase/functions/portal-contabilista/tabulacao_test.mjs
//
// O Tab desce a coluna em vez de atravessar a linha. Quem transcreve de uma
// folha tem doze meses da mesma rubrica em coluna e lê-os de cima a baixo; a
// ordem natural do DOM numa tabela obrigava-o a procurar o número certo a cada
// tecla.
//
// O JS testado é extraído tal e qual do `index.ts` — não é uma cópia à mão,
// senão provava-se a cópia e não o que vai para o servidor. Fica em Node e não
// em Deno (como o `euros_test.ts`) porque precisa de um DOM, e o `jsdom` é a
// forma mais curta de o ter sem browser.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { JSDOM } from 'jsdom';

const aqui = dirname(fileURLToPath(import.meta.url));

const fonte = readFileSync(join(aqui, 'index.ts'), 'utf8');
const inicio = fonte.indexOf('function navegarPorColuna');
const fim = fonte.indexOf('});', fonte.indexOf("document.addEventListener('keydown'")) + 3;
if (inicio < 0 || fim < 3) throw new Error('não encontrei o bloco no index.ts');
const script = fonte.slice(inicio, fim);

const RUBRICAS = [
  ['facturacao', true],
  ['compras', true],
  ['pessoal', true],
  ['iva_liquidado', false], // não aceita total anual: tfoot sem input
  ['resultado', true],
];
const MESES = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
  'Agosto','Setembro','Outubro','Novembro','Dezembro'];

const anoHtml = (ano, aberto) => `
<details class="ano" ${aberto ? 'open' : ''}>
  <summary><span class="ano-titulo">${ano}</span></summary>
  <div class="tabela-envolvente"><table>
    <thead><tr><th scope="col">Mês</th>${RUBRICAS.map(([r]) => `<th scope="col">${r}</th>`).join('')}</tr></thead>
    <tbody>${MESES.map((nome, i) => {
      const iso = `${ano}-${String(i + 1).padStart(2, '0')}-01`;
      return `<tr><th scope="row">${nome}</th>${RUBRICAS.map(([r]) =>
        `<td><input type="text" class="euros" data-rubrica="${r}" data-mes="${iso}" aria-label="${r} ${iso}"></td>`
      ).join('')}</tr>`;
    }).join('')}</tbody>
    <tfoot><tr class="total-ano"><th scope="row">Não sei os meses</th>${
      RUBRICAS.map(([r, anual]) => anual
        ? `<td><input type="text" class="euros" data-rubrica="${r}" data-ano="${ano}" aria-label="${r} ${ano}"></td>`
        : `<td class="vazia">—</td>`).join('')
    }</tr></tfoot>
  </table></div>
</details>`;

const dom = new JSDOM(
  `<!doctype html><body><main>${anoHtml(2026, true)}${anoHtml(2025, false)}</main>
   <script>${script}<\/script></body>`,
  { runScripts: 'dangerously' },
);
const { document, KeyboardEvent } = dom.window;

const rotulo = () => document.activeElement?.getAttribute('aria-label') ?? '(nenhum)';
function tab({ shift = false, tecla = 'Tab' } = {}) {
  document.activeElement.dispatchEvent(
    new KeyboardEvent('keydown', { key: tecla, shiftKey: shift, bubbles: true, cancelable: true }),
  );
}

let falhas = 0;
function verificar(oQue, obtido, esperado) {
  const ok = obtido === esperado;
  if (!ok) falhas++;
  console.log(`${ok ? 'OK  ' : 'FALHA'}  ${oQue}\n        obtido=${obtido}  esperado=${esperado}`);
}

// 1. Do primeiro campo, Tab desce a coluna.
document.querySelector('input').focus();
verificar('arranca em Janeiro/facturação', rotulo(), 'facturacao 2026-01-01');
tab();
verificar('Tab desce para Fevereiro, mesma rubrica', rotulo(), 'facturacao 2026-02-01');
tab(); tab();
verificar('e continua a descer', rotulo(), 'facturacao 2026-04-01');

// 2. Enter faz o mesmo — é a tecla de quem vem do Excel.
tab({ tecla: 'Enter' });
verificar('Enter também desce', rotulo(), 'facturacao 2026-05-01');

// 3. Shift+Tab sobe.
tab({ shift: true });
verificar('Shift+Tab sobe', rotulo(), 'facturacao 2026-04-01');

// 4. Ao fim da coluna passa pelo total do ano e depois ao topo da coluna seguinte.
for (let i = 0; i < 8; i++) tab();
verificar('chega a Dezembro', rotulo(), 'facturacao 2026-12-01');
tab();
verificar('a seguir a Dezembro vem o total do ano', rotulo(), 'facturacao 2026');
tab();
verificar('e daí ao topo da coluna seguinte', rotulo(), 'compras 2026-01-01');

// 5. Uma rubrica sem total anual não pára numa célula vazia.
document.querySelector('input[data-rubrica="iva_liquidado"][data-mes="2026-12-01"]').focus();
tab();
verificar('sem total anual, salta directo para a coluna seguinte',
  rotulo(), 'resultado 2026-01-01');

// 6. Ao fim do último ano visível, abre o ano seguinte.
const ultimo = [...document.querySelectorAll('details.ano')][0]
  .querySelectorAll('table input');
ultimo[ultimo.length - 1].focus();
verificar('último campo de 2026', rotulo(), 'resultado 2026');
tab();
verificar('salta para 2025', rotulo(), 'facturacao 2025-01-01');
verificar('e abriu o ano que estava fechado',
  String([...document.querySelectorAll('details.ano')][1].open), 'true');

// 7. No fim de tudo, o Tab volta a ser o do browser — não fica preso.
const todos = [...document.querySelectorAll('details.ano')][1].querySelectorAll('table input');
todos[todos.length - 1].focus();
const evento = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
document.activeElement.dispatchEvent(evento);
verificar('no último campo de todos o Tab não é intercetado',
  String(evento.defaultPrevented), 'false');

console.log(falhas === 0 ? '\nTUDO VERDE' : `\n${falhas} FALHAS`);
process.exit(falhas === 0 ? 0 : 1);
