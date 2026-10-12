// A configuração de atendimento de uma empresa — o seu contexto operacional.
// Vive na tabela `punho_atendimento_config`; nada de uma empresa específica fica no código.
// Uma empresa nova é uma linha nessa tabela.

export type Janela = { de: number; ate: number }; // horas decimais: 9, 13, 15, 18

export type Tipo = "servico" | "aluguer" | "venda";

export type ConfigAtendimento = {
  nomePublico: string;
  nomeAssistente: string;
  fuso: string;
  tipos: Tipo[];
  categorias: string[];
  horarioServico: Janela[] | null;
  horarioAluguer: Janela[] | null;
};

function janelas(bruto: unknown): Janela[] | null {
  if (!Array.isArray(bruto)) return null;
  const lista = bruto
    .map((j) => ({ de: Number((j as Janela)?.de), ate: Number((j as Janela)?.ate) }))
    .filter((j) => Number.isFinite(j.de) && Number.isFinite(j.ate) && j.de < j.ate);
  return lista.length > 0 ? lista : null;
}

/// Lê uma linha da tabela para o formato que o código usa.
export function lerConfig(linha: Record<string, unknown> | null | undefined): ConfigAtendimento | null {
  if (!linha) return null;
  return {
    nomePublico: String(linha.nome_publico ?? ""),
    nomeAssistente: String(linha.nome_assistente ?? "Assistente"),
    fuso: String(linha.fuso ?? "Europe/Lisbon"),
    tipos: ((linha.tipos as string[]) ?? []).filter((t): t is Tipo =>
      t === "servico" || t === "aluguer" || t === "venda"
    ),
    categorias: ((linha.categorias as string[]) ?? []).map(String),
    horarioServico: janelas(linha.horario_servico),
    horarioAluguer: janelas(linha.horario_aluguer),
  };
}

/// O que se mostra a quem pergunta (o assistente): nunca os horários, que o servidor valida.
export function configPublica(c: ConfigAtendimento) {
  return {
    nome_publico: c.nomePublico,
    nome_assistente: c.nomeAssistente,
    tipos: c.tipos,
    categorias: c.categorias,
  };
}
