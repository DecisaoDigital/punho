import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/kpis/break_even.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/finance.dart';
import 'package:fist/domain/models/historical_month.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/features/kpis/presentation/grafico_do_mes.dart';

void main() {
  Receipt recebido(String id, DateTime fim, int cents) => Receipt(
    id: 'r$id',
    date: fim,
    amountCents: cents,
    customerId: 'c1',
    method: PaymentMethod.cash,
  );

  Booking venda(String id, DateTime fim, int cents) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: fim.subtract(const Duration(hours: 9)),
    endsAt: fim,
    status: BookingStatus.completed,
    expectedValueCents: cents,
  );

  final hoje = DateTime(2026, 8, 13, 21);

  final estado = OperationsState(
    bookings: [
      venda('a', DateTime(2026, 8, 2, 18), 10000),
      venda('b', DateTime(2026, 8, 10, 18), 20000),
      venda('d', DateTime(2026, 7, 3, 18), 30000),
      venda('e', DateTime(2025, 3, 28, 18), 50000),
    ],
    receipts: [
      recebido('a', DateTime(2026, 8, 2, 18), 10000),
      recebido('b', DateTime(2026, 8, 10, 18), 20000),
      recebido('d', DateTime(2026, 7, 3, 18), 30000),
      recebido('e', DateTime(2025, 3, 28, 18), 50000),
    ],
    historicalMonths: const [
      HistoricalMonth(year: 2024, month: 5, revenueReceivedCents: 70000),
    ],
    expenses: [
      Expense(
        id: 'x',
        date: DateTime(2026, 8, 1),
        amountCents: 100000,
        category: ExpenseCategory.rent,
        status: ExpensePaymentStatus.paid,
      ),
    ],
  );

  test('uma coluna por mês, e o mês a decorrer é o acumulado até agora', () {
    final s = serieAnual(estado, hoje, 2026);
    expect(s.meses[6], 30000);
    expect(s.meses[7], 30000);
    expect(s.meses[8], isNull);
    expect(s.meses[0], isNull);
    expect(s.mesAtual, 8);
    expect(s.breakEven[7], 100000);
    expect(s.breakEven[6], isNull);
  });

  test('anos transatos: navegáveis desde o mais antigo com dados', () {
    final s = serieAnual(estado, hoje, 2025);
    expect(s.anos, [2024, 2025, 2026]);
    expect(s.meses[2], 50000);
    expect(s.mesAtual, isNull);
  });

  test('mês só com histórico do contabilista vem marcado como declarado', () {
    final s = serieAnual(estado, hoje, 2024);
    expect(s.meses[4], 70000);
    expect(s.declarado[4], isTrue);
    expect(s.declarado[6], isFalse);
  });

  test('o break even é o de cada mês, nunca a régua de outro', () {
    final com = OperationsState(
      expenses: [
        for (final (mes, v) in [(1, 180000), (2, 185000), (3, 190000)])
          Expense(
            id: 'e$mes',
            date: DateTime(2025, mes, 5),
            amountCents: v,
            category: ExpenseCategory.rent,
            status: ExpensePaymentStatus.paid,
          ),
      ],
      historicalMonths: const [
        HistoricalMonth(year: 2025, month: 4, paidExpensesCents: 200000),
      ],
    );
    final s = serieAnual(com, hoje, 2025);
    expect(s.breakEven.take(5).toList(), [
      180000,
      185000,
      190000,
      200000,
      null,
    ]);
    expect(s.mediaDoAno, 188750);
  });

  test('o topo é o mesmo em todos os anos', () {
    final topos = {
      for (final a in [2024, 2025, 2026])
        serieAnual(estado, hoje, a).maximoDeTodosOsAnos,
    };
    expect(topos, {100000});
  });

  test('sem vendas nenhuma não há dados para desenhar', () {
    final s = serieAnual(const OperationsState(), hoje, 2026);
    expect(s.temDados, isFalse);
    expect(s.anos, [2026]);
  });

  testWidgets('desenha deitado em 190 dp e navega para o ano anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 761,
            height: 260,
            child: SingleChildScrollView(
              child: GraficoDoMes(estado: estado, now: hoje),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Faturação mensal · 2026  (k = mil €)'), findsOneWidget);
    expect(find.textContaining('Break even'), findsOneWidget);
    await tester.tap(find.byTooltip('Ano anterior'));
    await tester.pump();
    expect(find.text('Faturação mensal · 2025  (k = mil €)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
