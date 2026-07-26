import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';

/// Regressões da sprint de estabilização v0.0.3. Cada teste falhava antes do
/// fix correspondente — ver docs/AUDITORIA_BUGS_v0.0.3.md.
void main() {
  ProviderContainer container() => ProviderContainer();

  Lead lead({String id = 'lead-1', String phone = '911 111 111'}) => Lead(
    id: id,
    name: 'Ana Silva',
    phone: phone,
    status: LeadStatus.newLead,
    createdAt: DateTime(2026, 7, 1),
  );

  group('P1-1 · converter lead respeita os duplicados', () {
    test('converter a mesma lead duas vezes não cria dois clientes', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      final antes = c.read(operationsProvider).customers.length;

      controller.addLead(lead());
      final primeiro = controller.convertLead(lead());
      final segundo = controller.convertLead(lead());

      expect(c.read(operationsProvider).customers, hasLength(antes + 1));
      expect(segundo.id, primeiro.id);
    });

    test('converter uma lead com telemóvel de cliente existente é recusado', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      controller.addCustomer(
        const Customer(id: 'cx', name: 'Já existe', phone: '922 222 222'),
      );
      final antes = c.read(operationsProvider).customers.length;

      controller.addLead(lead(phone: '922 222 222'));
      expect(
        () => controller.convertLead(lead(phone: '922 222 222')),
        throwsA(isA<StateError>()),
      );
      // Não cria cliente nenhum, e a lead não fica pendente para sempre.
      expect(c.read(operationsProvider).customers, hasLength(antes));
      expect(
        c.read(operationsProvider).leads
            .firstWhere((l) => l.id == 'lead-1')
            .status,
        LeadStatus.converted,
      );
    });

    test('lead sem telemóvel não colide com clientes sem telemóvel', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      controller.addCustomer(
        const Customer(id: 'cy', name: 'Sem contacto', phone: ''),
      );
      final antes = c.read(operationsProvider).customers.length;

      controller.addLead(lead(id: 'lead-2', phone: ''));
      controller.convertLead(lead(id: 'lead-2', phone: ''));

      expect(c.read(operationsProvider).customers, hasLength(antes + 1));
    });
  });

  group('P1-3 · mudança manual de estado da máquina persiste', () {
    test('pôr disponível uma máquina com reserva futura tem efeito', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      // Reserva confirmada no futuro: a máquina passa a "reservada".
      expect(
        controller.addBooking(
          Booking(
            id: 'futura',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime.now().add(const Duration(days: 30)),
            endsAt: DateTime.now().add(const Duration(days: 32)),
            status: BookingStatus.confirmed,
          ),
        ),
        isNull,
      );
      expect(
        c.read(operationsProvider).machines.firstWhere((m) => m.id == 'm1').status,
        MachineStatus.reserved,
      );

      // O ciclo automático anulava esta escolha na mesma chamada.
      expect(controller.updateMachineStatus('m1', MachineStatus.available), isTrue);
      expect(
        c.read(operationsProvider).machines.firstWhere((m) => m.id == 'm1').status,
        MachineStatus.available,
      );
    });

    test('continua a recusar disponível durante um aluguer a decorrer', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      expect(
        controller.addBooking(
          Booking(
            id: 'agora',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime.now().subtract(const Duration(hours: 2)),
            endsAt: DateTime.now().add(const Duration(days: 1)),
            status: BookingStatus.rented,
          ),
        ),
        isNull,
      );
      expect(controller.updateMachineStatus('m1', MachineStatus.available), isFalse);
    });
  });

  group('P1-6 · máquina parada ou em manutenção não se reserva', () {
    for (final estado in [MachineStatus.maintenance, MachineStatus.stopped]) {
      test('recusa reserva de máquina em ${machineStatusLabel(estado)}', () {
        final c = container();
        addTearDown(c.dispose);
        final controller = c.read(operationsProvider.notifier);
        expect(controller.updateMachineStatus('m1', estado), isTrue);

        expect(
          () => controller.addBooking(
            Booking(
              id: 'b-parada',
              customerId: 'c1',
              machineIds: const ['m1'],
              startsAt: DateTime(2026, 12, 1),
              endsAt: DateTime(2026, 12, 3),
              status: BookingStatus.confirmed,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          c.read(operationsProvider).bookings.any((b) => b.id == 'b-parada'),
          isFalse,
        );
      });
    }

    test('uma máquina disponível continua a poder ser reservada', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      expect(
        controller.addBooking(
          Booking(
            id: 'b-ok',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 12, 1),
            endsAt: DateTime(2026, 12, 3),
            status: BookingStatus.confirmed,
          ),
        ),
        isNull,
      );
    });
  });

  group('P0-3 · addBooking sinaliza erros de validação', () {
    test('duração abaixo do mínimo lança ArgumentError e não grava', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      expect(
        () => controller.addBooking(
          Booking(
            id: 'b-curta',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 12, 1, 9),
            endsAt: DateTime(2026, 12, 1, 10),
            status: BookingStatus.confirmed,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        c.read(operationsProvider).bookings.any((b) => b.id == 'b-curta'),
        isFalse,
      );
    });

    test('fim antes do início lança em vez de gravar lixo', () {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      expect(
        () => controller.addBooking(
          Booking(
            id: 'b-invertida',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 12, 5),
            endsAt: DateTime(2026, 12, 1),
            status: BookingStatus.confirmed,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
