import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lead só é «convertida» quando o operador fecha: cria a reserva, que
/// nasce confirmada. Criar a ficha do cliente não converte nada.
void main() {
  ProviderContainer novo() {
    final c = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_Vazio())],
    );
    addTearDown(c.dispose);
    return c;
  }

  Lead lead({String phone = '913 000 001', String id = 'l1'}) => Lead(
    id: id,
    name: 'Obra do Porto',
    phone: phone,
    status: LeadStatus.qualified,
    createdAt: DateTime(2026, 10, 1),
    source: LeadSource.ownProspecting,
  );

  const maquina = Machine(
    id: 'm1',
    name: 'Mini',
    reference: 'M-1',
    category: 'Escavação',
    status: MachineStatus.available,
  );

  Booking reserva(
    String clienteId, {
    BookingStatus s = BookingStatus.confirmed,
  }) => Booking(
    id: 'b1',
    customerId: clienteId,
    machineIds: const ['m1'],
    startsAt: DateTime(2026, 11, 10, 8),
    endsAt: DateTime(2026, 11, 12, 18),
    status: s,
  );

  test('criar a ficha do cliente não converte a lead', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addLead(lead());
    final cliente = n.convertLead(lead());
    final l = c.read(operationsProvider).leads.single;
    expect(l.status, LeadStatus.qualified);
    expect(l.convertedCustomerId, cliente.id);
    expect(l.bookingId, isNull);
  });

  test('a reserva confirmada fecha e converte a lead', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addLead(lead());
    final cliente = n.convertLead(lead());
    n.saveMachine(maquina);
    n.addBooking(reserva(cliente.id));
    final l = c.read(operationsProvider).leads.single;
    expect(l.status, LeadStatus.converted);
    expect(l.bookingId, 'b1');
  });

  test('reserva só pedida liga mas só converte quando confirmar', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addLead(lead());
    final cliente = n.convertLead(lead());
    n.saveMachine(maquina);
    n.addBooking(reserva(cliente.id, s: BookingStatus.request));
    var l = c.read(operationsProvider).leads.single;
    expect(l.status, LeadStatus.qualified);
    expect(l.bookingId, 'b1');
    n.updateBookingStatus('b1', BookingStatus.confirmed);
    l = c.read(operationsProvider).leads.single;
    expect(l.status, LeadStatus.converted);
  });

  test('quem já é cliente não entra como lead', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(
      const Customer(id: 'c9', name: 'Ana Silva', phone: '+351 913 000 001'),
    );
    expect(
      () => n.addLead(lead(phone: '913000001')),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Ana Silva'),
        ),
      ),
    );
    expect(c.read(operationsProvider).leads, isEmpty);
  });

  test('um cliente arquivado já não bloqueia a lead', () {
    final c = novo();
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(
      const Customer(id: 'c9', name: 'Ana', phone: '913000001', archived: true),
    );
    n.addLead(lead(phone: '913000001'));
    expect(c.read(operationsProvider).leads, hasLength(1));
  });
}

class _Vazio extends LocalDemoOperationRepository {
  _Vazio() {
    resetAll();
  }
}
