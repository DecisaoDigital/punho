import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/finance.dart';

void main() {
  final day = DateTime(2026, 7, 24);
  test('calcula saldo pendente de reserva', () {
    final receipts = [
      Receipt(
        id: 'r',
        date: day,
        amountCents: 3000,
        customerId: 'c',
        bookingId: 'b',
        method: PaymentMethod.transfer,
      ),
    ];
    expect(bookingPendingCents(10000, 'b', receipts), 7000);
  });
  test('despesas por pagar não entram em despesas pagas', () {
    final items = [
      Expense(
        id: 'e',
        date: day,
        amountCents: 5000,
        category: ExpenseCategory.meals,
        status: ExpensePaymentStatus.unpaid,
      ),
    ];
    expect(paidExpenseTotal(items, day, day), 0);
    expect(unpaidExpenseTotal(items), 5000);
  });
  test(
    'resultado operacional simples',
    () => expect(simpleOperatingResult(12000, 4500), 7500),
  );
  test(
    'refeição é apenas uma categoria',
    () => expect(ExpenseCategory.meals.name, 'meals'),
  );
  test('filtro mensal de movimentos', () {
    final receipts = [
      Receipt(
        id: 'in',
        date: DateTime(2026, 7, 2),
        amountCents: 100,
        customerId: 'c',
        method: PaymentMethod.cash,
      ),
      Receipt(
        id: 'out',
        date: DateTime(2026, 8, 2),
        amountCents: 200,
        customerId: 'c',
        method: PaymentMethod.cash,
      ),
    ];
    expect(
      receiptTotal(receipts, DateTime(2026, 7, 1), DateTime(2026, 7, 31)),
      100,
    );
  });
}
