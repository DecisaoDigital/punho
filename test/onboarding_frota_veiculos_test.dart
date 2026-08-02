import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';

/// Mesmo tratamento que as máquinas já tinham (achado 8): declarar N
/// veículos no onboarding passa a criar N linhas por identificar, em vez de
/// deixar a frota vazia. Um veículo sem matrícula não carrega risco fiscal
/// nenhum — ao contrário de uma ficha de colaborador — por isso aqui vale a
/// mesma solução.
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

  group('Criação a partir do onboarding', () {
    test('declarar 2 veículos cria 2 linhas por identificar', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);

      onboard(n, declaredVehicleCount: 2);

      final veiculos = c.read(operationsProvider).vehicles;
      expect(veiculos, hasLength(2));
      expect(veiculos.every((v) => v.placeholder), isTrue);
      expect(veiculos.every((v) => v.status == VehicleStatus.active), isTrue);
      expect(veiculos.every((v) => !v.archived), isTrue);
      expect(veiculos.every((v) => v.plate.isEmpty), isTrue);
      expect(veiculos.every((v) => v.type == 'Por identificar'), isTrue);
    });

    test('declarar zero não cria veículo nenhum', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);

      onboard(n, declaredVehicleCount: 0);

      expect(c.read(operationsProvider).vehicles, isEmpty);
    });

    test('re-onboarding com veículo já registado não duplica', () {
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

      expect(c.read(operationsProvider).vehicles, hasLength(1));
    });
  });

  group('Identificar', () {
    test('guardar um placeholder com matrícula desliga o flag', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 1);
      final placeholder = c.read(operationsProvider).vehicles.single;

      n.saveVehicle(
        placeholder.copyWith(plate: 'AA-11-BB', placeholder: false),
      );

      final guardado = c
          .read(operationsProvider)
          .vehicles
          .firstWhere((v) => v.id == placeholder.id);
      expect(guardado.plate, 'AA-11-BB');
      expect(guardado.placeholder, isFalse);
    });
  });

  group('Tarefas', () {
    test('contam placeholders e não a simples ausência de veículos', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 3);
      final estado = c.read(operationsProvider);

      expect(estado.placeholdersDeVeiculos, 3);
      final tarefa = tarefasPendentes(estado, DateTime(2026, 8, 2)).firstWhere(
        (t) => t.id == 'frota-sem-veiculos',
      );
      expect(tarefa.titulo, '3 veículos por identificar');
      expect(tarefa.cta, 'Abrir Frota');
    });

    test('identificar todos faz a tarefa desaparecer', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      onboard(n, declaredVehicleCount: 1);
      final unico = c.read(operationsProvider).vehicles.single;

      n.saveVehicle(unico.copyWith(plate: 'AA-11-BB', placeholder: false));

      expect(
        tarefasPendentes(
          c.read(operationsProvider),
          DateTime(2026, 8, 2),
        ).where((t) => t.id == 'frota-sem-veiculos'),
        isEmpty,
      );
    });
  });
}
