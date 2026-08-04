// deno test supabase/functions/portal-contabilista/euros_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { formatarEuros, paraCentavos } from "./euros.ts";

const casos: Array<[string, number | null, string]> = [
  ["1234,56", 123456, "decimal português"],
  ["1.234,56", 123456, "milhares e decimal português"],
  ["1234.56", 123456, "decimal inglês, de quem copiou de uma folha de cálculo"],
  ["1234", 123400, "inteiro"],
  ["1.200", 120000, "o caso difícil: ponto de milhares sem decimais"],
  ["12.345.678", 1234567800, "milhares repetidos"],
  ["1 234,50 €", 123450, "com espaços e símbolo"],
  ["0", 0, "zero declarado — diferente de não saber"],
  ["", null, "vazio é 'não sei'"],
  ["   ", null, "só espaços"],
  ["abc", null, "ilegível"],
  ["-450,25", -45025, "negativo, para uma nota de crédito"],
  ["0,05", 5, "cêntimos"],
  ["1.2", 120, "ponto decimal com um dígito só"],
];

Deno.test("paraCentavos lê o que um contabilista escreve", () => {
  for (const [entrada, esperado, nota] of casos) {
    assertEquals(paraCentavos(entrada), esperado, `${nota}: ${JSON.stringify(entrada)}`);
  }
});

Deno.test("formatarEuros devolve o que ele espera ver", () => {
  assertEquals(formatarEuros(123456), "1234,56");
  assertEquals(formatarEuros(0), "0,00");
  assertEquals(formatarEuros(null), "");
  assertEquals(formatarEuros(undefined), "");
});

Deno.test("ida e volta não perde cêntimos", () => {
  for (const [entrada, esperado] of casos) {
    if (esperado === null) continue;
    assertEquals(paraCentavos(formatarEuros(esperado)), esperado);
  }
});
