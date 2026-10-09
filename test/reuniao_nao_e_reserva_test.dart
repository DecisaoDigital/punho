import 'package:fist/core/ciclo/relogio_da_reserva.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/features/tarefas/data/tarefas_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma reunião partilha o calendário e o log com as reservas, mas nenhuma
/// conta de aluguer a pode ver.
void main() {
  final agora = DateTime(2026, 10, 20, 9);
  ProviderContainer container() => ProviderContainer(
    overrides: [relogioProvider.overrideWithValue(() => agora)],
  );

  Customer cliente() => Customer(
    id: 'c1',
    name: 'Ana',
    phone: '910000000',
    createdAt: DateTime(2026, 1, 1),
  );

  test('uma reunião sozinha: zero reservas, zero tarefas, zero passos', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(cliente());
    final antes = c.read(operationsProvider);
    final tarefasAntes = tarefasPendentes(antes, agora).length;

    final r = n.agendarReuniao(
      customerId: 'c1',
      inicio: DateTime(2026, 10, 21, 10),
      lembreteMinutos: 15,
      criadoPorUid: 'u1',
    );

    final s = c.read(operationsProvider);
    expect(s.bookings, isEmpty);
    expect(s.reunioes.map((x) => x.id), [r.id]);
    expect(s.reunioes.single.tipo, BookingTipo.reuniao);
    expect(s.reunioes.single.endsAt, DateTime(2026, 10, 21, 11));
    expect(tarefasPendentes(s, agora).length, tarefasAntes);
  });

  test('o relógio não põe uma reunião passada «em aluguer» nem «concluída»', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(cliente());
    n.agendarReuniao(customerId: 'c1', inicio: DateTime(2026, 10, 1, 10));
    expect(
      reservasAAvancar(c.read(operationsProvider).reunioes, DateTime(2026, 12, 1)),
      isEmpty,
    );
  });

  test('remarcar e cancelar uma reunião', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(cliente());
    final r = n.agendarReuniao(
      customerId: 'c1',
      inicio: DateTime(2026, 10, 21, 10),
      lembreteMinutos: 30,
      criadoPorUid: 'u1',
    );
    n.remarcarReuniao(r.id, DateTime(2026, 10, 22, 15));
    var x = c.read(operationsProvider).reunioes.single;
    expect(x.startsAt, DateTime(2026, 10, 22, 15));
    expect(x.endsAt, DateTime(2026, 10, 22, 16));
    expect(x.lembreteMinutos, 30);
    expect(x.criadoPorUid, 'u1');
    n.cancelarReuniao(r.id);
    x = c.read(operationsProvider).reunioes.single;
    expect(x.status, BookingStatus.cancelled);
  });

  test('uma reserva de máquina continua em bookings, não em reunioes', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.addCustomer(cliente());
    n.addBooking(
      Booking(
        id: 'r1',
        customerId: 'c1',
        machineIds: [c.read(operationsProvider).machines.first.id],
        startsAt: DateTime(2026, 10, 25),
        endsAt: DateTime(2026, 10, 26),
        status: BookingStatus.confirmed,
      ),
    );
    final s = c.read(operationsProvider);
    expect(s.bookings.map((b) => b.id), ['r1']);
    expect(s.reunioes, isEmpty);
  });
}
