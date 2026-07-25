import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';

void main() {
  ProviderContainer container() => ProviderContainer();

  test('updates a booking status without duplicating it', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    expect(
      controller.addBooking(
        Booking(
          id: 'pedido',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime(2026, 10, 10),
          endsAt: DateTime(2026, 10, 12),
          status: BookingStatus.request,
        ),
      ),
      isNull,
    );
    expect(
      controller.updateBookingStatus('pedido', BookingStatus.confirmed),
      isNull,
    );
    final bookings = c.read(operationsProvider).bookings;
    expect(bookings, hasLength(1));
    expect(bookings.single.status, BookingStatus.confirmed);
  });

  test('deteta conflito entre reservas confirmadas para a mesma máquina', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    final start = DateTime(2026, 8, 10, 9);
    final end = DateTime(2026, 8, 12, 9);
    expect(
      controller.addBooking(
        Booking(
          id: 'first',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: start,
          endsAt: end,
          status: BookingStatus.confirmed,
        ),
      ),
      isNull,
    );
    final conflict = controller.addBooking(
      Booking(
        id: 'second',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 8, 11),
        endsAt: DateTime(2026, 8, 13),
        status: BookingStatus.confirmed,
      ),
    );
    expect(conflict, isNotNull);
    expect(conflict!.machine.id, 'm1');
  });

  test('converte lead em cliente sem duplicar os dados do lead', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    final lead = Lead(
      id: 'lead-1',
      name: 'Ana Costa',
      phone: '913000000',
      status: LeadStatus.newLead,
      createdAt: DateTime.now(),
      summary: 'Precisa de plataforma',
    );
    controller.addLead(lead);
    final customer = controller.convertLead(lead);
    final state = c.read(operationsProvider);
    expect(customer.name, 'Ana Costa');
    expect(state.customers.where((x) => x.phone == lead.phone), hasLength(1));
    expect(state.leads.single.status, LeadStatus.converted);
  });

  test('calcula máquinas disponíveis e paradas', () {
    final c = container();
    addTearDown(c.dispose);
    final state = c.read(operationsProvider);
    expect(availableMachines(state, DateTime.now()), 1);
    expect(stoppedMachines(state), 1);
  });

  test('15 declaradas e 0 registadas não produz 15 disponíveis', () {
    const state = OperationsState(totalMachinesDeclared: 15);
    expect(state.registeredMachinesCount, 0);
    expect(state.hasUnidentifiedDeclaredMachines, isTrue);
    expect(availableMachines(state, DateTime.now()), 0);
  });

  test('só máquinas identificadas disponíveis contam como disponíveis', () {
    final state = OperationsState(
      totalMachinesDeclared: 15,
      machines: const [
        Machine(
          id: 'available',
          name: 'A',
          reference: '1',
          category: 'X',
          status: MachineStatus.available,
        ),
        Machine(
          id: 'stopped',
          name: 'B',
          reference: '2',
          category: 'X',
          status: MachineStatus.stopped,
        ),
      ],
    );
    expect(availableMachines(state, DateTime.now()), 1);
  });

  test('reservas exigem máquina identificada', () {
    final c = container();
    addTearDown(c.dispose);
    expect(
      () => c
          .read(operationsProvider.notifier)
          .addBooking(
            Booking(
              id: 'invalid',
              customerId: 'c1',
              machineIds: const ['declarada-sem-id'],
              startsAt: DateTime(2026, 10, 1),
              endsAt: DateTime(2026, 10, 2),
              status: BookingStatus.confirmed,
            ),
          ),
      throwsArgumentError,
    );
  });

  test('cliente duplicado por telemóvel é rejeitado na empresa', () {
    final c = container();
    addTearDown(c.dispose);
    expect(
      () => c
          .read(operationsProvider.notifier)
          .addCustomer(
            const Customer(id: 'new', name: 'Outro', phone: '912 000 000'),
          ),
      throwsStateError,
    );
  });

  test('cliente guarda morada, codigo postal e localidade', () {
    const customer = Customer(
      id: 'customer-address',
      name: 'Obras Costa',
      phone: '913 000 000',
      address: 'Rua do Campo, 10',
      postalCode: '1000-100',
      locality: 'Lisboa',
    );

    expect(customer.address, 'Rua do Campo, 10');
    expect(customer.postalCode, '1000-100');
    expect(customer.locality, 'Lisboa');
  });

  test('dados iniciais em falta ficam como tarefas abertas', () {
    const incomplete = OperationsState(onboarded: true);
    const complete = OperationsState(
      onboarded: true,
      companyTaxId: '123456789',
      ownerName: 'Ana Costa',
      companyPhone: '912000000',
      companyAddress: 'Rua do Campo, 10',
      companyPostalCode: '1000-100',
      companyLocality: 'Lisboa',
      revenueLastYearCents: 10000000,
      revenueThisYearCents: 6000000,
      maintenanceLastYearCents: 250000,
      fixedMonthlyCostsCents: 80000,
    );

    expect(incomplete.initialDataTasks, hasLength(8));
    expect(complete.initialDataTasks, isEmpty);
  });
}
