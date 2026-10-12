// A categoria do que a pessoa quer, validada contra a lista DA EMPRESA (ver config.ts).
// O texto é o da categoria das máquinas na app, para a lead e a máquina se encontrarem.
// Empresa sem lista: a categoria passa tal como veio.
import type { ConfigAtendimento } from "./config.ts";

export type ResultadoCategoria =
  | { ok: true; categoria: string | null }
  | { ok: false; motivo: "em_falta" | "desconhecida"; opcoes: string[] };

function chave(t: string): string {
  return t.normalize("NFD").replace(/[̀-ͯ]/g, "").trim().toLowerCase();
}

/// `obrigatoria`: pedido de serviço, aluguer ou venda precisa de categoria. Sem
/// ela a lead entra na mesma e a resposta devolve as opções, para o assistente
/// voltar a perguntar.
export function validarCategoria(
  bruto: unknown,
  config: ConfigAtendimento | null,
  obrigatoria: boolean,
): ResultadoCategoria {
  const texto = bruto === undefined || bruto === null ? "" : String(bruto).trim();
  const lista = config?.categorias ?? [];
  if (lista.length === 0) return { ok: true, categoria: texto ? texto.slice(0, 80) : null };
  if (texto === "") {
    return obrigatoria
      ? { ok: false, motivo: "em_falta", opcoes: lista }
      : { ok: true, categoria: null };
  }
  const k = chave(texto);
  const achada = lista.find((c) => chave(c) === k);
  return achada ? { ok: true, categoria: achada } : { ok: false, motivo: "desconhecida", opcoes: lista };
}
