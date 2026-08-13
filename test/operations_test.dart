import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/workforce.dart';

void main() {
  /// O relógio fica preso a 1 de Agosto de 2026.
  ///
  /// Desde 13/8/2026 o controlador avança sozinho as marcações — entrega no dia
  /// de início, fecho no fim (`estadoPeloRelogio`). Com o relógio da máquina, as
  /// datas fixas destes testes iam ficando para trás e as marcações chegavam
  /// «Concluídas» a testes escritos para as apanhar por confirmar.
  ProviderContainer container() => ProviderContainer(
    overrides: [
      relogioProvider.overrideWithValue(() => DateTime(2026, 8, 1, 9)),
    ],
  );

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

  test('definirValorPrevisto grava o valor de uma reserva já criada', () {
    // O mecanismo que o ecrã do gestor passou a expor: corrigir o valor de uma
    // reserva depois de criada, sem a apagar e voltar a marcar.
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    controller.addBooking(
      Booking(
        id: 'pedido',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 10, 10),
        endsAt: DateTime(2026, 10, 12),
        status: BookingStatus.request,
      ),
    );

    controller.definirValorPrevisto('pedido', 45000);

    expect(
      c.read(operationsProvider).bookings.single.expectedValueCents,
      45000,
    );
  });

  test('definirValorPrevisto recusa valor não positivo', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    controller.addBooking(
      Booking(
        id: 'pedido',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 10, 10),
        endsAt: DateTime(2026, 10, 12),
        status: BookingStatus.request,
      ),
    );

    expect(
      () => controller.definirValorPrevisto('pedido', 0),
      throwsArgumentError,
    );
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

  test('calcula máquinas disponíveis e sem trabalhar', () {
    // As duas máquinas de demonstração estão ambas disponíveis desde a v0.0.5:
    // a segunda era `stopped`, estado que deixou de existir para o utilizador.
    final c = container();
    addTearDown(c.dispose);
    final state = c.read(operationsProvider);
    expect(availableMachines(state, DateTime.now()), 2);
    expect(
      stoppedMachines(state),
      2,
      reason: 'nenhuma está alugada, reservada ou em manutenção',
    );
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
          status: MachineStatus.maintenance,
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
    final complete = OperationsState(
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
      historicalMonths: List.generate(
        12,
        (index) => HistoricalMonth(
          year: DateTime.now().year - 1,
          month: index + 1,
          revenueReceivedCents: 100000,
        ),
      ),
    );

    expect(incomplete.initialDataTasks, hasLength(9));
    expect(complete.initialDataTasks, isEmpty);
  });

  test('estados de máquina são apresentados em português', () {
    // O estado Parada saiu da app na v0.0.5: dados antigos leem-se como
    // disponíveis em vez de mostrarem um estado que já não se explica.
    expect(machineStatusLabel(MachineStatus.stopped), 'Disponível');
    expect(machineStatusLabel(MachineStatus.available), 'Disponível');
    expect(machineStatusLabel(MachineStatus.maintenance), 'Em manutenção');
  });

  test('máquina numa reserva ativa não pode passar a disponível', () {
    final c = container();
    addTearDown(c.dispose);
    final now = DateTime.now();
    final controller = c.read(operationsProvider.notifier);
    controller.addBooking(
      Booking(
        id: 'active-rental',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: now.subtract(const Duration(hours: 6)),
        endsAt: now.add(const Duration(hours: 6)),
        status: BookingStatus.rented,
      ),
    );

    expect(
      controller.updateMachineStatus('m1', MachineStatus.available),
      isFalse,
    );
  });

  test('reserva confirmada, aluguer e conclusão atualizam a máquina', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    final now = DateTime.now();
    controller.addBooking(
      Booking(
        id: 'machine-cycle',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: now.subtract(const Duration(hours: 6)),
        endsAt: now.add(const Duration(hours: 6)),
        status: BookingStatus.confirmed,
      ),
    );
    expect(
      c.read(operationsProvider).machines.first.status,
      MachineStatus.reserved,
    );

    controller.updateBookingStatus('machine-cycle', BookingStatus.rented);
    expect(
      c.read(operationsProvider).machines.first.status,
      MachineStatus.rented,
    );

    controller.updateBookingStatus('machine-cycle', BookingStatus.completed);
    expect(
      c.read(operationsProvider).machines.first.status,
      MachineStatus.available,
    );
  });

  test('máquina parada não pode receber nova reserva', () {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    controller.updateMachineStatus('m1', MachineStatus.maintenance);

    expect(
      controller.machineAvailable(
        'm1',
        DateTime.now().add(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 2)),
      ),
      isFalse,
    );
  });

  test(
    'máquina alugada numa reserva pode ser reservada noutra semana livre',
    () {
      // Decisão de 02/08/2026: alugar bloqueia a data, não a máquina inteira.
      // Antes desta mudança, uma máquina que passasse a `rented` ficava sem
      // poder receber reservas em nenhuma semana futura — inviável para um
      // negócio de aluguer, onde a mesma máquina volta a ficar livre.
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      final now = DateTime.now();
      // Reserva confirmada e já em curso: o `_syncMachineCycle` marca a
      // máquina como alugada.
      expect(
        controller.addBooking(
          Booking(
            id: 'semana-1',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: now.subtract(const Duration(hours: 6)),
            endsAt: now.add(const Duration(hours: 6)),
            status: BookingStatus.rented,
          ),
        ),
        isNull,
      );
      expect(
        c.read(operationsProvider).machines.first.status,
        MachineStatus.rented,
      );

      // A mesma máquina, numa semana à frente sem qualquer sobreposição: tem
      // de continuar disponível.
      final proximaSemanaInicio = now.add(const Duration(days: 7));
      final proximaSemanaFim = now.add(const Duration(days: 8));
      expect(
        controller.machineAvailable(
          'm1',
          proximaSemanaInicio,
          proximaSemanaFim,
        ),
        isTrue,
      );
      expect(
        controller.addBooking(
          Booking(
            id: 'semana-2',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: proximaSemanaInicio,
            endsAt: proximaSemanaFim,
            status: BookingStatus.confirmed,
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'reservar por cima do mesmo período de uma máquina alugada é recusado',
    () {
      // A barreira certa é a sobreposição de datas, não o estado da máquina —
      // e essa continua a recusar quando há mesmo conflito.
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      final now = DateTime.now();
      controller.addBooking(
        Booking(
          id: 'em-curso',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: now.subtract(const Duration(hours: 6)),
          endsAt: now.add(const Duration(hours: 6)),
          status: BookingStatus.rented,
        ),
      );

      expect(
        controller.machineAvailable(
          'm1',
          now.subtract(const Duration(hours: 3)),
          now.add(const Duration(hours: 3)),
        ),
        isFalse,
      );
      final conflict = controller.addBooking(
        Booking(
          id: 'sobreposta',
          customerId: 'c1',
          machineIds: const ['m1'],
          // 12h (o mínimo de uma reserva) e a sobrepor-se às -6h..+6h já
          // alugadas.
          startsAt: now.subtract(const Duration(hours: 3)),
          endsAt: now.add(const Duration(hours: 9)),
          status: BookingStatus.confirmed,
        ),
      );
      expect(conflict, isNotNull);
      expect(conflict!.machine.id, 'm1');
    },
  );

  test('máquina em manutenção continua a recusar qualquer data', () {
    // A única excepção que se mantém: manutenção é uma decisão sobre a
    // máquina, não sobre um período, por isso bloqueia sempre.
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(operationsProvider.notifier);
    controller.updateMachineStatus('m1', MachineStatus.maintenance);

    expect(
      controller.machineAvailable(
        'm1',
        DateTime.now().add(const Duration(days: 30)),
        DateTime.now().add(const Duration(days: 31)),
      ),
      isFalse,
    );
    expect(
      () => controller.addBooking(
        Booking(
          id: 'manutencao',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime.now().add(const Duration(days: 30)),
          endsAt: DateTime.now().add(const Duration(days: 31)),
          status: BookingStatus.confirmed,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('reserva inferior a meio dia é rejeitada', () {
    final c = container();
    addTearDown(c.dispose);
    final start = DateTime.now().add(const Duration(days: 1));

    expect(
      () => c
          .read(operationsProvider.notifier)
          .addBooking(
            Booking(
              id: 'too-short',
              customerId: 'c1',
              machineIds: const ['m1'],
              startsAt: start,
              endsAt: start.add(const Duration(hours: 6)),
              status: BookingStatus.request,
            ),
          ),
      throwsArgumentError,
    );
    expect(minimumBookingDuration, const Duration(hours: 12));
  });

  // --- Arquivo de cliente (Tarefa 3 da auditoria: Customer não tinha
  // `archived` nem forma de sair da lista) ---------------------------------

  test('Customer.copyWith distingue não mexer de apagar', () {
    const original = Customer(
      id: 'c-copy',
      name: 'Original',
      phone: '910 000 000',
      taxId: '123456789',
    );
    final semAlteracao = original.copyWith();
    expect(semAlteracao.taxId, '123456789');
    final marcadoComoArquivado = original.copyWith(archived: true);
    expect(marcadoComoArquivado.archived, isTrue);
    expect(marcadoComoArquivado.name, 'Original');
    expect(original.archived, isFalse, reason: 'copyWith não muta o original');
  });

  test('archiveCustomer arquiva sem apagar — a reserva antiga continua a '
      'apontar para um registo que existe', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);

    n.archiveCustomer('c1');

    final estado = c.read(operationsProvider);
    final cliente = estado.customers.firstWhere((x) => x.id == 'c1');
    expect(cliente.archived, isTrue);
    // Continua no repositório — só a interface é que o deve deixar de listar
    // como activo.
    expect(estado.customers.map((x) => x.id), contains('c1'));
  });

  test('unarchiveCustomer é o "Anular" do arquivo', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);

    n.archiveCustomer('c1');
    n.unarchiveCustomer('c1');

    final cliente = c
        .read(operationsProvider)
        .customers
        .firstWhere((x) => x.id == 'c1');
    expect(cliente.archived, isFalse);
  });

  test('arquivar um cliente inexistente não rebenta', () {
    final c = container();
    addTearDown(c.dispose);
    c.read(operationsProvider.notifier).archiveCustomer('não-existe');
    // Não lança e não altera a lista.
    expect(c.read(operationsProvider).customers, isNotEmpty);
  });

  // --- Ciclo de vida do veículo (Tarefa 2: só se criava, nunca se editava
  // nem arquivava) ----------------------------------------------------------

  test('saveVehicle edita mantendo o id — não duplica a linha', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    const original = Vehicle(
      id: 'v-edit',
      plate: 'AA-11-BB',
      type: 'Carrinha',
      status: VehicleStatus.active,
    );
    n.saveVehicle(original);

    n.saveVehicle(original.copyWith(plate: 'ZZ-99-XX'));

    final veiculos = c.read(operationsProvider).vehicles;
    expect(veiculos.where((v) => v.id == 'v-edit'), hasLength(1));
    expect(veiculos.firstWhere((v) => v.id == 'v-edit').plate, 'ZZ-99-XX');
  });

  test('archiveVehicle / unarchiveVehicle — soft-delete com desfazer', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.saveVehicle(
      const Vehicle(
        id: 'v-archive',
        plate: 'AA-11-BB',
        type: 'Carrinha',
        status: VehicleStatus.active,
      ),
    );

    n.archiveVehicle('v-archive');
    var estado = c.read(operationsProvider);
    expect(
      estado.vehicles.firstWhere((v) => v.id == 'v-archive').archived,
      isTrue,
    );
    // Fora da contagem de identificados — mesma regra das máquinas.
    expect(estado.registeredVehiclesCount, 0);

    n.unarchiveVehicle('v-archive');
    estado = c.read(operationsProvider);
    expect(
      estado.vehicles.firstWhere((v) => v.id == 'v-archive').archived,
      isFalse,
    );
    expect(estado.registeredVehiclesCount, 1);
  });

  // --- Machine.purchasePriceCents / acquiredOn (achado mais grave da
  // auditoria: a célula "Utilização vs Rentabilidade" nunca saía de "Por
  // apurar" porque nenhum campo guardava o valor de compra, e o `acquiredOn`
  // que já existia no modelo era ignorado pelo `copyWith`) --------------------

  test('Machine.copyWith aplica acquiredOn e purchasePriceCents — antes eram '
      'ignorados na edição', () {
    const original = Machine(
      id: 'm-compra',
      name: 'Mini escavadora',
      reference: 'ME-09',
      category: 'Escavação',
      status: MachineStatus.available,
    );
    expect(original.acquiredOn, isNull);
    expect(original.purchasePriceCents, isNull);

    final editada = original.copyWith(
      acquiredOn: DateTime(2024, 3, 10),
      purchasePriceCents: 1250000,
    );
    expect(editada.acquiredOn, DateTime(2024, 3, 10));
    expect(editada.purchasePriceCents, 1250000);
    // O resto da máquina não se perde por causa da edição.
    expect(editada.name, 'Mini escavadora');
    expect(original.acquiredOn, isNull, reason: 'copyWith não muta o original');
  });

  test(
    'Machine.copyWith sem tocar em acquiredOn/purchasePriceCents preserva-os '
    '— era este o bug: editar qualquer outro campo apagava a data',
    () {
      final original = Machine(
        id: 'm-preserva',
        name: 'Plataforma',
        reference: 'PE-03',
        category: 'Elevação',
        status: MachineStatus.available,
        acquiredOn: DateTime(2023, 1, 15),
        purchasePriceCents: 800000,
      );

      final renomeada = original.copyWith(name: 'Plataforma elevatória');

      expect(renomeada.acquiredOn, DateTime(2023, 1, 15));
      expect(renomeada.purchasePriceCents, 800000);
    },
  );

  test('saveMachine grava e relê purchasePriceCents e acquiredOn através do '
      'controlador', () {
    final c = container();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    n.saveMachine(
      Machine(
        id: 'm-controlador',
        name: 'Martelo',
        reference: 'MD-09',
        category: 'Demolição',
        status: MachineStatus.available,
        acquiredOn: DateTime(2022, 6, 1),
        purchasePriceCents: 450000,
      ),
    );

    final maquina = c
        .read(operationsProvider)
        .machines
        .firstWhere((m) => m.id == 'm-controlador');
    expect(maquina.acquiredOn, DateTime(2022, 6, 1));
    expect(maquina.purchasePriceCents, 450000);
  });

  /// **Remarcar** — a terceira saída de um conflito de reserva, e a mais
  /// provável. Até 10 de Agosto de 2026 o ecrã de conflitos prometia
  /// «remarcar ou recusar» e não tinha botão nenhum, porque não havia gesto
  /// nenhum: só se criava e só se mudava de estado.
  group('remarcarPara', () {
    OperationsController controlador(ProviderContainer c) =>
        c.read(operationsProvider.notifier);

    Booking meioDia(String id, DateTime dia) => Booking(
      id: id,
      customerId: 'c1',
      machineIds: const ['m1'],
      startsAt: DateTime(dia.year, dia.month, dia.day),
      endsAt: DateTime(dia.year, dia.month, dia.day, 12),
      status: BookingStatus.confirmed,
    );

    test('muda o dia e não a duração', () {
      final c = container();
      addTearDown(c.dispose);
      final n = controlador(c);
      n.addBooking(meioDia('r', DateTime(2026, 10, 10)));

      expect(n.remarcarPara('r', DateTime(2026, 10, 17)), isNull);

      final depois = c
          .read(operationsProvider)
          .bookings
          .firstWhere((b) => b.id == 'r');
      expect(depois.startsAt, DateTime(2026, 10, 17));
      // Meia manhã continua meia manhã: remarcar por intervalo transformava-a
      // num dia inteiro sem ninguém pedir.
      expect(depois.endsAt, DateTime(2026, 10, 17, 12));
    });

    test('não é conflito consigo própria', () {
      final c = container();
      addTearDown(c.dispose);
      final n = controlador(c);
      n.addBooking(meioDia('r', DateTime(2026, 10, 10)));

      // Para o mesmo dia em que já está: a única sobreposição é ela mesma.
      expect(n.remarcarPara('r', DateTime(2026, 10, 10)), isNull);
    });

    test('recusa o dia que já está ocupado por outra, e não grava', () {
      final c = container();
      addTearDown(c.dispose);
      final n = controlador(c);
      n.addBooking(meioDia('r', DateTime(2026, 10, 10)));
      n.addBooking(meioDia('outra', DateTime(2026, 10, 20)));

      final choque = n.remarcarPara('r', DateTime(2026, 10, 20));

      expect(choque, isNotNull);
      expect(choque!.booking.id, 'outra');
      expect(
        c
            .read(operationsProvider)
            .bookings
            .firstWhere((b) => b.id == 'r')
            .startsAt,
        DateTime(2026, 10, 10),
        reason: 'nada muda quando o dia novo também está ocupado',
      );
    });

    test('marcação que já não existe não rebenta', () {
      final c = container();
      addTearDown(c.dispose);

      expect(
        controlador(c).remarcarPara('fantasma', DateTime(2026, 10, 17)),
        isNull,
      );
    });
  });
}
