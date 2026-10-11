import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/operations/kpis.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/finance.dart';

/// A previsão do mês pelo crescimento (César, 11 Out 2026): média ano a ano
/// com meses fechados, mais o que este mês costuma fazer, sobre o mesmo mês do
/// ano passado. Nunca olha para o mês a decorrer.
void main() {
  Receipt rec(int ano, int mes, int cents) => Receipt(
    id: 'r$ano-$mes',
    date: DateTime(ano, mes, 10),
    amountCents: cents,
    customerId: 'c1',
    method: PaymentMethod.cash,
  );

  // 2024: 800 € em Jan–Set, 1000 € em Out. 2025: 1000 € em Jan–Set, 1100 € em
  // Out. 2026: 1500 € em Jan–Set.
  final receipts = [
    for (var m = 1; m <= 9; m++) rec(2024, m, 80000),
    rec(2024, 10, 100000),
    for (var m = 1; m <= 9; m++) rec(2025, m, 100000),
    rec(2025, 10, 110000),
    for (var m = 1; m <= 9; m++) rec(2026, m, 150000),
  ];

  test('média ponderada + desvio do mês sobre o mesmo mês do ano passado', () {
    final p = previsaoPorCrescimento(
      OperationsState(receipts: receipts),
      DateTime(2026, 10, 9),
    )!;

    // 2026 vs 2025 (Jan–Set): +50%. 2025 vs 2024: 10100/8200 − 1 ≈ +23,2%.
    // Média com o par mais recente a dobrar: (0,5×2 + 0,232) / 3 ≈ 41,1%.
    // Outubro de 2025 cresceu 10%: 13,2 pontos abaixo da média desse ano.
    expect(p.pares, 2);
    expect(p.homologoCents, 110000);
    expect(p.crescimentoMedio, closeTo(0.4106, 0.001));
    expect(p.desvioDoMes, closeTo(-0.1317, 0.001));
    expect(p.previstoCents, closeTo(140670, 100));
  });

  test('não depende do que já entrou no mês a decorrer', () {
    final a = previsaoPorCrescimento(
      OperationsState(receipts: receipts),
      DateTime(2026, 10, 9),
    )!;
    final b = previsaoPorCrescimento(
      OperationsState(receipts: [...receipts, rec(2026, 10, 999999)]),
      DateTime(2026, 10, 9),
    )!;
    expect(b.previstoCents, a.previstoCents);
  });

  test('sem o mesmo mês do ano passado não há base nem previsão', () {
    expect(
      previsaoPorCrescimento(
        OperationsState(receipts: [rec(2026, 9, 100000)]),
        DateTime(2026, 10, 9),
      ),
      isNull,
    );
  });
}
