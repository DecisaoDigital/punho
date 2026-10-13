import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/operations/kpis_da_cadeia.dart';

MesComparado _mes(int valor, {int? anterior, int? homologo}) => MesComparado(
  mes: DateTime(2026, 10),
  valorCents: valor,
  mesAnteriorCents: anterior,
  homologoCents: homologo,
);

void main() {
  test('percentagem só sobre base positiva e valor não negativo', () {
    expect(_mes(150, anterior: 100).variacaoMesAnterior, 50);
    expect(_mes(50, homologo: 100).variacaoHomologa, -50);
  });

  test('base negativa ou zero não dá percentagem, dá diferença absoluta', () {
    final m = _mes(-56200, anterior: -10000, homologo: 0);
    expect(m.variacaoMesAnterior, isNull);
    expect(m.variacaoHomologa, isNull);
    expect(m.diferencaMesAnteriorCents, -46200);
  });

  test('valor negativo sobre base positiva também não dá percentagem', () {
    final m = _mes(-5000, anterior: 10000);
    expect(m.variacaoMesAnterior, isNull);
    expect(m.diferencaMesAnteriorCents, -15000);
  });

  test('sem termo de comparação não há diferença', () {
    final m = _mes(100);
    expect(m.diferencaMesAnteriorCents, isNull);
    expect(m.diferencaHomologaCents, isNull);
  });
}
