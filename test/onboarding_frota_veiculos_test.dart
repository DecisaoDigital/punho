import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';

/// Decisão de 2026-08-02: o onboarding não cria registos automaticamente,
/// nem para as máquinas nem para a frota. Declarar "3 veículos" deixa a
/// frota vazia — a app só lembra, pela tarefa "N veículos por identificar",
/// que faltam registar contra o que foi declarado.
void main() {
  ProviderContainer container() => ProviderContainer();

  void onboard(OperationsController n, {required int declaredVehicleCount}) {
    n.completeOnboarding(
      companyName: 'Alugueres Norte',
      legalForm: 'Lda.',
      hasFleet: declaredVehicleCount > 0,
      collaborators: 0,
      declaredVehicleCount: declaredVehicleCount,
      totalMachinesDeclared: 0,
      insertMachinesNow: false,
    );
  }

  group('Onboarding não cria veículos', () {
    test('declarar 2 veículos não cria linha nenhuma', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);

      onboard(n, declaredVehicleCount: 2);

      expect(c.read(operationsProvider).vehicles, isEmpty);
      expect(c.read(operationsProvider).declaredVehicleCount, 2);
    });

    test('declarar zero também não cria nada', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);

      onboard(n, declaredVehicleCount: 0);

      expect(c.read(operationsProvider).vehicles, isEmpty);
    });

    test('veículo registado à mão antes do onboarding não é tocado', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      n.saveVehicle(
        const Vehicle(
          id: 'ja-existe',
          plate: 'AA-11-BB',
          type: 'Furgão',
          status: VehicleStatus.active,
        ),
      );

      onboard(n, declaredVehicleCount: 3);

      final veiculos = c.read(operationsProvider).vehicles;
      expect(veiculos, hasLength(1));
      expect(veiculos.single.plate, 'AA-11-BB');
    });
  });

  group('Tarefas contam contra o declarado', () {
    test('declarados sem nenhum registado gera a tarefa com o total', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 3);
      final estado = c.read(operationsProvider);

      expect(estado.vehiclesStillToIdentify, 3);
      final tarefa = tarefasPendentes(
        estado,
        DateTime(2026, 8, 2),
      ).firstWhere((t) => t.id == 'frota-sem-veiculos');
      expect(tarefa.titulo, 'Identificar 3 veículos');
      expect(tarefa.cta, 'Abrir Frota');
    });

    test('registar o veículo desconta ao que falta e a tarefa desaparece', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 1);

      n.saveVehicle(
        const Vehicle(
          id: 'v1',
          plate: 'AA-11-BB',
          type: 'Furgão',
          status: VehicleStatus.active,
        ),
      );

      final estado = c.read(operationsProvider);
      expect(estado.vehiclesStillToIdentify, 0);
      expect(
        tarefasPendentes(
          estado,
          DateTime(2026, 8, 2),
        ).where((t) => t.id == 'frota-sem-veiculos'),
        isEmpty,
      );
    });

    test('sem frota declarada não há tarefa nenhuma', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 0);

      final estado = c.read(operationsProvider);
      expect(
        tarefasPendentes(
          estado,
          DateTime(2026, 8, 2),
        ).where((t) => t.id == 'frota-sem-veiculos'),
        isEmpty,
      );
    });
  });
}
