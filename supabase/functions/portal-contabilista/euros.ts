// Ler e escrever euros como gente os escreve.
//
// Está num módulo à parte por uma razão só: é a parte do portal que se testa
// sem base de dados nenhuma, e é onde um erro passa despercebido durante mais
// tempo. Um número mal lido não rebenta — grava-se em silêncio e só aparece
// meses depois, num painel que ninguém percebe porque está errado.

/**
 * Lê um valor em euros escrito por gente, não por máquinas.
 *
 * Um contabilista português escreve `1.234,56`; um que copiou de uma folha de
 * cálculo inglesa escreve `1234.56`; um apressado escreve `1234`. Os três têm
 * de dar no mesmo número.
 *
 * O caso difícil é `1.200` sem casas decimais: são mil e duzentos euros ou um
 * euro e vinte? Aqui vale a convenção portuguesa — pontos a separar grupos de
 * exactamente três dígitos são milhares. E, por cima da convenção, o portal
 * devolve sempre o valor já formatado ao campo, para quem escreveu ver como
 * ficou interpretado antes de fechar a página.
 *
 * Devolve `null` para vazio e para o que não se percebe. Os dois casos são
 * diferentes lá em cima: vazio apaga a resposta, ilegível dá erro ao
 * utilizador.
 */
export function paraCentavos(bruto: string): number | null {
  const limpo = bruto.replace(/[\s €]/g, "");
  if (!limpo) return null;

  let normalizado: string;
  if (limpo.includes(",")) {
    // Com vírgula, a vírgula é o decimal e os pontos são milhares.
    normalizado = limpo.replaceAll(".", "").replace(",", ".");
  } else if (/^-?\d{1,3}(\.\d{3})+$/.test(limpo)) {
    // Sem vírgula, pontos a separar grupos de três são milhares: `1.200` são
    // mil e duzentos euros, não um euro e vinte.
    normalizado = limpo.replaceAll(".", "");
  } else {
    normalizado = limpo;
  }

  const n = Number(normalizado);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 100);
}

/** O inverso: centavos para o que o contabilista espera ver no campo. */
export function formatarEuros(centavos: number | null | undefined): string {
  if (centavos === null || centavos === undefined) return "";
  return (centavos / 100).toLocaleString("pt-PT", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
