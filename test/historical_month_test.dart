import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/historical_month.dart';

void main() {
  test('um mês histórico só conta quando contém dados', () {
    const empty = HistoricalMonth(year: 2025, month: 5);
    const filled = HistoricalMonth(
      year: 2025,
      month: 5,
      revenueReceivedCents: 400000,
    );

    expect(empty.hasAnyData, isFalse);
    expect(filled.hasAnyData, isTrue);
  });

  test('histórico completo exige os 12 recebimentos mensais', () {
    final months = List.generate(
      12,
      (index) => HistoricalMonth(
        year: 2025,
        month: index + 1,
        revenueReceivedCents: 100000,
      ),
    );
    final complete = OperationsState(historicalMonths: months);
    final incomplete = OperationsState(
      historicalMonths: months.take(11).toList(),
    );

    expect(complete.hasFullRevenueHistoryFor(2025), isTrue);
    expect(incomplete.hasFullRevenueHistoryFor(2025), isFalse);
  });
}
