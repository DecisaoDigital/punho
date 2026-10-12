// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/kpis/series_para_graficos.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/finance.dart';
import 'package:fist/domain/models/operations.dart';

void main() {
  final now = DateTime(2026, 10, 11);
  final s = OperationsState(
    onboarded: true,
    companyName: 'X',
    customers: [
      Customer(
        id: 'c1',
        name: 'Ana',
        phone: '1',
        createdAt: DateTime(2026, 10, 2),
      ),
      Customer(
        id: 'c2',
        name: 'Rui',
        phone: '2',
        createdAt: DateTime(2026, 9, 2),
      ),
    ],
    receipts: [
      Receipt(
        id: 'r1',
        customerId: 'c1',
        method: PaymentMethod.cash,
        amountCents: 30000,
        date: DateTime(2026, 10, 3),
      ),
      Receipt(
        id: 'r2',
        customerId: 'c2',
        method: PaymentMethod.cash,
        amountCents: 10000,
        date: DateTime(2026, 9, 3),
      ),
    ],
    expenses: [
      Expense(
        id: 'e1',
        date: DateTime(2026, 10, 4),
        amountCents: 5000,
        category: ExpenseCategory.rent,
        status: ExpensePaymentStatus.paid,
      ),
    ],
  );

  test('entrou vs saiu usa o que foi pago', () {
    final o = entrouVsSaiu(s, now).last;
    expect(o.entrou, 30000);
    expect(o.saiu, 5000);
  });

  test('receita por cliente ordena por valor', () {
    final r = receitaPorCliente(s, now);
    expect(r.first.nome, 'Ana');
    expect(r.first.texto, '300 €');
  });

  test('clientes novos por mês conta pela data de registo', () {
    final r = clientesNovosPorMes(s, now);
    expect(r.last.valor, 1);
    expect(r[r.length - 2].valor, 1);
  });

  test('despesas por categoria só do mês e pagas', () {
    expect(despesasPorCategoria(s, now).single.texto, '50 €');
  });
}
