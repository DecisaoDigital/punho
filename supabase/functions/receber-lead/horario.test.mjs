// node --experimental-strip-types --test supabase/functions/receber-lead/*.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { validarHorarioPedido } from "./horario.ts";
import { validarCategoria } from "./categorias.ts";
import { lerConfig, configPublica } from "./config.ts";

// Duas empresas com contextos diferentes: nada no código é de nenhuma delas.
const A = lerConfig({
  nome_publico: "Empresa A", nome_assistente: "Carlitos", fuso: "Europe/Lisbon",
  tipos: ["servico", "aluguer", "venda"],
  categorias: ["Depilação a laser", "Remoção de tatuagens", "Emagrecimento"],
  horario_servico: [{ de: 9, ate: 13 }, { de: 15, ate: 18 }],
  horario_aluguer: [{ de: 9, ate: 18 }],
});
const B = lerConfig({
  nome_publico: "Empresa B", nome_assistente: "Rita", fuso: "Europe/Lisbon",
  tipos: ["servico"], categorias: ["Massagem", "Pilates"],
  horario_servico: [{ de: 10, ate: 20 }], horario_aluguer: null,
});
const agora = new Date("2026-10-11T12:00:00Z");
// Outubro em Lisboa é WEST (UTC+1) até 25/10: 10:00 locais = 09:00Z.
const v = (iso, cfg = A, tipo = "servico") => validarHorarioPedido(iso, cfg, tipo, agora);

test("sem horário pedido não há nada a validar", () => {
  assert.deepEqual(v(undefined), { ok: true, instante: null });
  assert.deepEqual(v("  "), { ok: true, instante: null });
});
test("serviço: manhã e tarde passam, início exacto incluído", () => {
  assert.equal(v("2026-10-14T09:00:00Z").ok, true); // 10:00
  assert.equal(v("2026-10-14T08:00:00Z").ok, true); // 09:00
  assert.equal(v("2026-10-14T14:00:00Z").ok, true); // 15:00 depois do almoço
});
test("serviço: almoço e fora de horas são recusados; o fim da janela também", () => {
  assert.equal(v("2026-10-14T12:00:00Z").motivo, "fora_de_horas"); // 13:00
  assert.equal(v("2026-10-14T13:00:00Z").motivo, "fora_de_horas"); // 14:00
  assert.equal(v("2026-10-14T17:00:00Z").motivo, "fora_de_horas"); // 18:00
  assert.equal(v("2026-10-14T06:00:00Z").motivo, "fora_de_horas"); // 07:00
});
test("passado e lixo", () => {
  assert.equal(v("2026-10-10T09:00:00Z").motivo, "passado");
  assert.equal(v("amanhã de manhã").motivo, "invalido");
});
test("aluguer usa o horário de entrega da empresa (sem almoço)", () => {
  assert.equal(v("2026-10-14T12:30:00Z", A, "aluguer").ok, true); // 13:30
  assert.equal(v("2026-10-14T17:00:00Z", A, "aluguer").motivo, "fora_de_horas");
});
test("venda não tem horário", () => {
  assert.deepEqual(v("2026-10-14T12:30:00Z", A, "venda"), { ok: true, instante: null });
  assert.deepEqual(v("lixo", A, "venda"), { ok: true, instante: null });
});
test("cada empresa tem o seu horário: o que serve a A não serve a B", () => {
  assert.equal(v("2026-10-14T18:30:00Z", A).motivo, "fora_de_horas"); // 19:30 em A
  assert.equal(v("2026-10-14T18:30:00Z", B).ok, true); // 19:30 em B (10–20)
  assert.equal(v("2026-10-14T12:00:00Z", B).ok, true); // 13:00 em B, sem almoço
});
test("sem configuração ou sem horário: só exige futuro", () => {
  assert.equal(v("2026-10-14T03:00:00Z", null).ok, true);
  assert.equal(v("2026-10-14T03:00:00Z", B, "aluguer").ok, true); // B não tem horário de aluguer
});

test("categorias: sem olhar a maiúsculas nem acentos", () => {
  assert.deepEqual(validarCategoria("depilacao a LASER", A, true), { ok: true, categoria: "Depilação a laser" });
});
test("categorias: em falta devolve as opções DA empresa", () => {
  const r = validarCategoria(undefined, B, true);
  assert.equal(r.motivo, "em_falta");
  assert.deepEqual(r.opcoes, ["Massagem", "Pilates"]);
});
test("categorias: desconhecida para esta empresa", () => {
  assert.equal(validarCategoria("Massagem", A, true).motivo, "desconhecida");
  assert.equal(validarCategoria("Massagem", B, true).ok, true);
});
test("categorias: empresa sem lista aceita o que vier", () => {
  assert.equal(validarCategoria("Escavação", null, true).categoria, "Escavação");
  assert.equal(validarCategoria("", null, true).categoria, null);
});
test("a configuração pública não mostra horários", () => {
  const p = configPublica(A);
  assert.equal(p.nome_assistente, "Carlitos");
  assert.equal(JSON.stringify(p).includes("horario"), false);
});
