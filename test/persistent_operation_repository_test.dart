import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'keeps onboarding and operational records after repository recreation',
    () async {
      final first = await PersistentOperationRepository.create();
      first.saveOnboarding(
        const OnboardingData(
          companyName: 'Alugueres Norte',
          legalForm: 'Lda.',
          hasFleet: true,
          collaborators: 2,
          totalMachinesDeclared: 4,
          insertMachinesNow: true,
        ),
      );
      first.saveMachine(
        const Machine(
          id: 'persisted-machine',
          name: 'Gerador',
          reference: 'G-01',
          category: 'Energia',
          status: MachineStatus.available,
          photoPaths: ['/dados/punho/maquina-gerador.jpg'],
        ),
      );
      first.saveHistoricalMonth(
        const HistoricalMonth(
          year: 2025,
          month: 5,
          revenueReceivedCents: 450000,
          leadsReceived: 80,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      final restored = await PersistentOperationRepository.create();

      expect(restored.onboarding?.companyName, 'Alugueres Norte');
      expect(
        restored.machines.any((machine) => machine.id == 'persisted-machine'),
        isTrue,
      );
      expect(
        restored.machines
            .firstWhere((machine) => machine.id == 'persisted-machine')
            .photoPaths,
        ['/dados/punho/maquina-gerador.jpg'],
      );
      expect(restored.historicalMonths, hasLength(1));
      expect(restored.historicalMonths.single.revenueReceivedCents, 450000);
    },
  );

  test('um dispositivo sem dados guardados arranca vazio', () async {
    // Os "números fantasma" do painel: o repositório persistente herdava as
    // duas máquinas e o cliente de demonstração do repositório local, e o
    // utilizador via "máquinas identificadas 2" e um cliente que nunca criou.
    final repositorio = await PersistentOperationRepository.create();

    expect(repositorio.machines, isEmpty);
    expect(repositorio.customers, isEmpty);
    expect(repositorio.bookings, isEmpty);
    expect(repositorio.historicalMonths, isEmpty);
    expect(repositorio.onboarding, isNull);
  });

  test('cache inválida arranca vazia em vez de meio estado', () async {
    SharedPreferences.setMockInitialValues({
      'punho.operations.v1': '{isto não é json',
    });

    final repositorio = await PersistentOperationRepository.create();

    expect(repositorio.machines, isEmpty);
    expect(repositorio.customers, isEmpty);
    expect(repositorio.onboarding, isNull);
  });

  test(
    'archiveCustomer e archiveVehicle sobrevivem a recriar o repositório',
    () async {
      final primeiro = await PersistentOperationRepository.create();
      primeiro.saveCustomer(
        const Customer(
          id: 'c-arq',
          name: 'Cliente antigo',
          phone: '911 000 000',
        ),
      );
      primeiro.saveVehicle(
        const Vehicle(
          id: 'v-arq',
          plate: 'AA-11-BB',
          type: 'Carrinha',
          status: VehicleStatus.active,
        ),
      );
      primeiro.archiveCustomer('c-arq');
      primeiro.archiveVehicle('v-arq');
      await Future<void>.delayed(Duration.zero);

      final restaurado = await PersistentOperationRepository.create();

      expect(
        restaurado.customers.firstWhere((c) => c.id == 'c-arq').archived,
        isTrue,
      );
      expect(
        restaurado.vehicles.firstWhere((v) => v.id == 'v-arq').archived,
        isTrue,
      );
    },
  );

  test('cliente antigo sem "archived" no JSON lê-se como false', () async {
    SharedPreferences.setMockInitialValues({
      'punho.operations.v1': jsonEncode({
        'customers': [
          {'id': 'c-antigo', 'name': 'Cliente pré-histórico', 'phone': ''},
        ],
      }),
    });

    final repositorio = await PersistentOperationRepository.create();

    expect(repositorio.customers.single.archived, isFalse);
  });

  test(
    'purchasePriceCents e acquiredOn sobrevivem a recriar o repositório',
    () async {
      final primeiro = await PersistentOperationRepository.create();
      primeiro.saveMachine(
        Machine(
          id: 'm-compra',
          name: 'Mini escavadora',
          reference: 'ME-09',
          category: 'Escavação',
          status: MachineStatus.available,
          acquiredOn: DateTime(2023, 4, 12),
          purchasePriceCents: 1850000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final restaurado = await PersistentOperationRepository.create();

      final maquina = restaurado.machines.firstWhere((m) => m.id == 'm-compra');
      expect(maquina.acquiredOn, DateTime(2023, 4, 12));
      expect(maquina.purchasePriceCents, 1850000);
    },
  );

  test('máquina antiga sem "purchasePriceCents" no JSON lê-se como null, não '
      'zero', () async {
    SharedPreferences.setMockInitialValues({
      'punho.operations.v1': jsonEncode({
        'machines': [
          {
            'id': 'm-antiga',
            'name': 'Máquina pré-histórica',
            'reference': '',
            'category': '',
            'status': 'available',
          },
        ],
      }),
    });

    final repositorio = await PersistentOperationRepository.create();

    final maquina = repositorio.machines.single;
    expect(maquina.purchasePriceCents, isNull);
    expect(maquina.acquiredOn, isNull);
  });

  test('resetAll apaga o que estava guardado', () async {
    final primeiro = await PersistentOperationRepository.create();
    primeiro.saveCustomer(
      const Customer(id: 'c-real', name: 'Cliente real', phone: '910 000 000'),
    );
    await Future<void>.delayed(Duration.zero);

    primeiro.resetAll();
    await Future<void>.delayed(Duration.zero);

    expect(primeiro.customers, isEmpty);
    // E não volta na recriação: o armazenamento também ficou limpo.
    final recriado = await PersistentOperationRepository.create();
    expect(recriado.customers, isEmpty);
    expect(recriado.onboarding, isNull);
  });
}
