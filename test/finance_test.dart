// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/domain/models/finance.dart';

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
