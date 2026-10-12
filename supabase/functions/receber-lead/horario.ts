// Validação de um pedido de marcação contra o horário DA EMPRESA (ver config.ts).
//
// Vive à parte de `index.ts` para se poder testar sem o runtime do Deno.
//   serviço: horário de atendimento (pode ter hora de almoço);
//   aluguer: horário de entrega;
//   venda:   não tem horário.
// Empresa sem horário configurado: só se exige que o dia seja futuro.
import type { ConfigAtendimento, Janela, Tipo } from "./config.ts";

export type Resultado =
  | { ok: true; instante: string | null }
  | { ok: false; motivo: "invalido" | "passado" | "fora_de_horas" };

/// Hora e minuto na parede do fuso da empresa — o que a pessoa disse ao dizer
/// «às 10h» —, independentemente de o servidor correr em UTC.
function paredeNoFuso(d: Date, fuso: string): number {
  const partes = new Intl.DateTimeFormat("en-GB", {
    timeZone: fuso,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(d);
  const h = Number(partes.find((p) => p.type === "hour")!.value);
  const m = Number(partes.find((p) => p.type === "minute")!.value);
  return h + m / 60;
}

/// Uma marcação cabe numa janela quando começa nela. O fim de uma janela já é
/// fora de horas: a hora marcada é de início, não de fim.
export function validarHorarioPedido(
  bruto: unknown,
  config: ConfigAtendimento | null,
  tipo: Tipo | null,
  agora: Date = new Date(),
): Resultado {
  if (tipo === "venda") return { ok: true, instante: null };
  if (bruto === undefined || bruto === null || String(bruto).trim() === "") {
    return { ok: true, instante: null };
  }
  const d = new Date(String(bruto));
  if (Number.isNaN(d.getTime())) return { ok: false, motivo: "invalido" };
  if (d.getTime() <= agora.getTime()) return { ok: false, motivo: "passado" };
  const janelas: Janela[] | null = config
    ? (tipo === "aluguer" ? config.horarioAluguer : config.horarioServico)
    : null;
  if (janelas) {
    const h = paredeNoFuso(d, config!.fuso);
    if (!janelas.some((j) => h >= j.de && h < j.ate)) return { ok: false, motivo: "fora_de_horas" };
  }
  return { ok: true, instante: d.toISOString() };
}
