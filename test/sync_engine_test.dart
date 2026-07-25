import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/sync_engine.dart';

void main() {
  test('empresa A não lê dados da empresa B', () {
    final s = CompanyScope('a', [
      const ScopedRecord('a', 'cliente A'),
      const ScopedRecord('b', 'cliente B'),
    ]);
    expect(s.visibleTo('a'), ['cliente A']);
  });
  test('operação offline entra na outbox e é idempotente', () {
    final o = LocalOutbox();
    const e = OutboxEvent(
      id: '1',
      empresaId: 'a',
      kind: 'cliente',
      payload: {},
    );
    o.enqueue(e);
    o.enqueue(e);
    expect(o.forCompany('a'), hasLength(1));
  });
  test('sincronização duas vezes não duplica', () async {
    final o = LocalOutbox();
    o.enqueue(
      const OutboxEvent(id: '1', empresaId: 'a', kind: 'reserva', payload: {}),
    );
    final s = SyncEngine(o);
    var sends = 0;
    await s.synchronize('a', (e) async {
      sends++;
      return true;
    });
    await s.synchronize('a', (e) async {
      sends++;
      return true;
    });
    expect(sends, 1);
  });
}
