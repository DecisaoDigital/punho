import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/features/tarefas/data/tarefas_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime(2026, 10, 20, 9);
  ProviderContainer novo() {
    final c = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_Vazio())],
    );
    addTearDown(c.dispose);
    return c;
  }

  Lead lead(String id, {String? resp, LeadStatus s = LeadStatus.newLead}) =>
      Lead(
        id: id,
        name: 'Lead $id',
        phone: '91$id',
        status: s,
        createdAt: DateTime(2026, 10, 1),
        collaboratorResponsibleId: resp,
      );

  test('leads abertas sem operador geram a tarefa, atribuir desfaz', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addLead(lead('1000001'));
    n.addLead(lead('1000002', resp: 'ficha-1'));
    n.addLead(lead('1000003', s: LeadStatus.lost));

    var t = tarefasPendentes(c.read(operationsProvider), agora)
        .where((x) => x.id == 'leads-por-atribuir');
    expect(t.single.titulo, '1 lead por atribuir a um operador');

    n.atribuirLead('1000001', 'ficha-2');
    expect(
      c.read(operationsProvider).leads.firstWhere((l) => l.id == '1000001')
          .collaboratorResponsibleId,
      'ficha-2',
    );
    t = tarefasPendentes(c.read(operationsProvider), agora)
        .where((x) => x.id == 'leads-por-atribuir');
    expect(t, isEmpty);
  });

  test('devolver à caixa: atribuir null limpa o operador', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addLead(lead('1000001', resp: 'ficha-1'));
    n.atribuirLead('1000001', null);
    expect(
      c.read(operationsProvider).leads.single.collaboratorResponsibleId,
      isNull,
    );
  });
}

class _Vazio extends LocalDemoOperationRepository {
  _Vazio() {
    resetAll();
  }
}
