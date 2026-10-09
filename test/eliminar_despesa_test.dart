import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/finance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eliminar despesa tira-a do estado e das contas; anular devolve-a', () async {
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
  });
}
