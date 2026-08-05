import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Cada coisa tem um dono.**
///
/// A app sincroniza por dois canais, e durante um tempo os dois julgaram-se
/// donos das mesmas entidades:
///
/// * **operações** (`punho_operacoes`) — uma linha por alteração, ordem do
///   servidor a decidir quem ganha. É o canal do que duas pessoas mexem ao
///   mesmo tempo: máquinas, clientes, leads, reservas, despesas, recebimentos,
///   colaboradores, veículos;
/// * **instantâneo** (`punho_estado_operacional`) — o estado inteiro com uma
///   revisão. É o canal do que só o gestor edita: onboarding, custos fixos,
///   histórico mensal.
///
/// O que aconteceu a 4 de Agosto de 2026, num Redmi: fechar um trabalho em *A
/// minha semana* gravava, subia à fila de operações e chegava ao servidor —
/// está lá, com o id daquele telemóvel. Segundos depois o trabalho voltava a
/// "em curso". O instantâneo, parado na revisão 1, tinha escrito por cima com
/// o estado antigo. Sem erro, sem aviso: a app dizia uma coisa e o servidor
/// dizia outra, e quem trabalhava perdia o trabalho em silêncio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  Booking reserva(BookingStatus estado) => Booking(
    id: 'res-9',
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: DateTime(2026, 7, 30, 8),
    endsAt: DateTime(2026, 8, 3, 18),
    status: estado,
    expectedValueCents: 36000,
  );

  /// Um instantâneo do servidor parado no tempo: a reserva ainda alugada, e uma
  /// despesa que já foi apagada há muito.
  String instantaneoVelho() => jsonEncode({
    'onboarding': {
      'companyName': 'Terraforte',
      'legalForm': 'Lda.',
      'hasFleet': true,
      'collaborators': 4,
      'totalMachinesDeclared': 6,
    },
    'bookings': [
      {
        'id': 'res-9',
        'customerId': 'c1',
        'machineIds': ['m1'],
        'startsAt': '2026-07-30T08:00:00.000',
        'endsAt': '2026-08-03T18:00:00.000',
        'status': 'rented',
      },
    ],
    'machines': const [],
    'customers': const [],
    'expenses': const [],
    'receipts': const [],
    'historicalMonths': const [],
  });

  test('o instantâneo não desfaz o que a fila de operações fez', () async {
    final repo = await repositorio();
    // O gestor fechou o trabalho. Isto é o que ficou no telemóvel.
    repo.saveBooking(reserva(BookingStatus.completed));

    repo.importOperationalPayload(instantaneoVelho(), revision: 1);

    // Antes desta separação vinha `rented`, e o trabalho voltava a aparecer
    // como se nunca tivesse sido fechado.
    expect(repo.bookings.single.status, BookingStatus.completed);
  });

  test('nem apaga o que a fila criou entretanto', () async {
    final repo = await repositorio();
    repo.saveMachine(
      const Machine(
        id: 'm9',
        name: 'Giratória',
        reference: 'GIR-09',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );
    repo.saveExpense(
      Expense(
        id: 'd1',
        date: DateTime(2026, 8, 2),
        amountCents: 4500,
        category: ExpenseCategory.fuel,
        status: ExpensePaymentStatus.paid,
      ),
    );

    // O instantâneo traz listas vazias — nele estas coisas nunca existiram.
    repo.importOperationalPayload(instantaneoVelho(), revision: 1);

    expect(repo.machines.single.reference, 'GIR-09');
    expect(repo.expenses.single.id, 'd1');
  });

  test('mas continua a trazer o que é dele: a ficha da empresa', () async {
    final repo = await repositorio();

    expect(
      repo.importOperationalPayload(instantaneoVelho(), revision: 1),
      isTrue,
    );

    // Este é o lado que não pode partir com a separação — é para isto que o
    // canal do instantâneo existe.
    expect(repo.onboarding?.companyName, 'Terraforte');
    expect(repo.onboarding?.collaborators, 4);
    expect(repo.remoteRevision, 1);
  });

  test(
    'o que está gravado no telemóvel continua a ser lido por inteiro',
    () async {
      // A mesma função aplica as duas coisas. Se a separação apanhasse também a
      // leitura local, a app arrancava sem metade do que tem — muito pior do que
      // o problema que se foi corrigir.
      SharedPreferences.setMockInitialValues({});
      final antes = await PersistentOperationRepository.create();
      antes.saveBooking(reserva(BookingStatus.completed));
      antes.saveCustomer(
        const Customer(id: 'c1', name: 'Construções Silva', phone: '912000000'),
      );

      final depois = await PersistentOperationRepository.create();

      expect(depois.bookings.single.status, BookingStatus.completed);
      expect(depois.customers.single.name, 'Construções Silva');
    },
  );
}
