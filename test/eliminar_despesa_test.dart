// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/finance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'eliminar despesa tira-a do estado e das contas; anular devolve-a',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();
      final c = ProviderContainer(
        overrides: [operationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      final agora = DateTime.now();
      n.saveExpense(
        Expense(
          id: 'e1',
          date: agora,
          amountCents: 1250,
          category: ExpenseCategory.other,
          status: ExpensePaymentStatus.paid,
        ),
      );
      expect(c.read(operationsProvider).expenses, hasLength(1));

      n.archiveExpense('e1');
      expect(c.read(operationsProvider).expenses, isEmpty);
      expect(repo.expenses.single.archived, isTrue);

      n.unarchiveExpense('e1');
      expect(c.read(operationsProvider).expenses.single.id, 'e1');
    },
  );
}
