import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';

const _empresa = OnboardingData(
  ownerName: 'Cesar Mendes',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  hasFleet: true,
  collaborators: 2,
  declaredVehicleCount: 3,
  totalMachinesDeclared: 5,
  insertMachinesNow: false,
  companyTaxId: '501234567',
  companyPhone: '912 000 000',
  revenueLastYearCents: 12500000,
  fixedMonthlyCostsCents: 320000,
);

({ProviderContainer container, OperationsController notifier}) _cenario({
  OnboardingData? empresa = _empresa,
}) {
  final repo = LocalDemoOperationRepository();
  if (empresa != null) repo.saveOnboarding(empresa);
  final container = ProviderContainer(
    overrides: [operationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    notifier: container.read(operationsProvider.notifier),
  );
}

void main() {
  group('updateCompanySettings', () {
    test('só altera o que recebe', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(companyName: 'Alugueres Norte II');

      final estado = c.container.read(operationsProvider);
      expect(estado.companyName, 'Alugueres Norte II');
      // Tudo o resto intacto.
      expect(estado.ownerName, 'Cesar Mendes');
      expect(estado.legalForm, 'Lda.');
      expect(estado.companyTaxId, '501234567');
      expect(estado.companyPhone, '912 000 000');
      expect(estado.declaredCollaboratorCount, 2);
      expect(estado.declaredVehicleCount, 3);
      expect(estado.totalMachinesDeclared, 5);
      expect(estado.revenueLastYearCents, 12500000);
      expect(estado.fixedMonthlyCostsCents, 320000);
    });

    test('um Campo com null apaga o valor', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(
        companyTaxId: const Campo(null),
        revenueLastYearCents: const Campo(null),
      );

      final estado = c.container.read(operationsProvider);
      expect(estado.companyTaxId, isNull);
      expect(estado.revenueLastYearCents, isNull);
      // Apagar um campo não arrasta os vizinhos.
      expect(estado.companyPhone, '912 000 000');
      expect(estado.fixedMonthlyCostsCents, 320000);
    });

    test('não passar o campo preserva, mesmo depois de outro ser apagado', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(companyTaxId: const Campo(null));
      c.notifier.updateCompanySettings(companyPhone: const Campo('913 111 111'));

      final estado = c.container.read(operationsProvider);
      expect(estado.companyTaxId, isNull, reason: 'não volta sozinho');
      expect(estado.companyPhone, '913 111 111');
    });

    test('hasFleet deriva dos veículos declarados', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(vehicles: 0);
      expect(c.container.read(operationsProvider).hasFleet, isFalse);
      expect(c.container.read(operationsProvider).declaredVehicleCount, 0);

      c.notifier.updateCompanySettings(vehicles: 1);
      expect(c.container.read(operationsProvider).hasFleet, isTrue);
      expect(c.container.read(operationsProvider).declaredVehicleCount, 1);
    });

    test('nome de empresa em branco não apaga o que estava', () {
      // O nome é obrigatório no modelo: em branco mantém-se o anterior em vez
      // de a empresa ficar sem nome.
      final c = _cenario();

      c.notifier.updateCompanySettings(companyName: '   ');

      expect(
        c.container.read(operationsProvider).companyName,
        'Alugueres Norte',
      );
    });

    test('grava no repositório, não só no state', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(companyLocality: const Campo('Braga'));

      final gravado = c.container.read(operationRepositoryProvider).onboarding;
      expect(gravado?.companyLocality, 'Braga');
      expect(gravado?.companyName, 'Alugueres Norte');
    });

    test('sem onboarding não faz nada', () {
      // Sem empresa configurada não há o que editar, e inventar uma aqui
      // saltava o arranque.
      final c = _cenario(empresa: null);

      c.notifier.updateCompanySettings(companyName: 'Empresa fantasma');

      expect(c.container.read(operationsProvider).onboarded, isFalse);
      expect(c.container.read(operationsProvider).companyName, '');
      expect(c.container.read(operationRepositoryProvider).onboarding, isNull);
    });

    test('editar não desmarca a app como configurada', () {
      final c = _cenario();

      c.notifier.updateCompanySettings(collaborators: 0);

      expect(c.container.read(operationsProvider).onboarded, isTrue);
      expect(c.container.read(operationsProvider).declaredCollaboratorCount, 0);
    });
  });

  group('Consequências na navegação', () {
    test('zero colaboradores e zero veículos tiram as áreas do menu', () {
      // Regra 4: guardar zeros não pode deixar a app a apontar para áreas que
      // já não fazem sentido.
      final c = _cenario();
      expect(
        visibleOperationalDestinations(c.container.read(operationsProvider)),
        containsAll([AppDestination.employees, AppDestination.vehicles]),
      );

      c.notifier.updateCompanySettings(collaborators: 0, vehicles: 0);

      final destinos = visibleOperationalDestinations(
        c.container.read(operationsProvider),
      );
      expect(destinos, isNot(contains(AppDestination.employees)));
      expect(destinos, isNot(contains(AppDestination.vehicles)));
      expect(destinos, contains(AppDestination.management));
    });

    test('voltar a pôr um veículo devolve a Frota ao menu', () {
      final c = _cenario();
      c.notifier.updateCompanySettings(vehicles: 0);

      c.notifier.updateCompanySettings(vehicles: 1);

      expect(
        visibleOperationalDestinations(c.container.read(operationsProvider)),
        contains(AppDestination.vehicles),
      );
    });
  });

  group('resetAll', () {
    test('apaga empresa, registos e volta ao arranque', () {
      final c = _cenario();
      c.notifier.addCustomer(
        const Customer(id: 'novo', name: 'Cliente', phone: '910 000 000'),
      );

      c.notifier.resetAll();

      final estado = c.container.read(operationsProvider);
      expect(estado.onboarded, isFalse);
      expect(estado.companyName, '');
      expect(estado.customers, isEmpty);
      // Também as máquinas de demonstração do repositório local.
      expect(estado.machines, isEmpty);
      expect(c.container.read(operationRepositoryProvider).onboarding, isNull);
    });
  });

  group('completeOnboarding', () {
    test('guarda o número de veículos declarado', () {
      final c = _cenario(empresa: null);

      c.notifier.completeOnboarding(
        companyName: 'Nova',
        legalForm: 'Lda.',
        hasFleet: true,
        collaborators: 1,
        declaredVehicleCount: 2,
        totalMachinesDeclared: 3,
        insertMachinesNow: false,
      );

      expect(c.container.read(operationsProvider).declaredVehicleCount, 2);
      expect(
        c.container
            .read(operationRepositoryProvider)
            .onboarding
            ?.declaredVehicleCount,
        2,
      );
    });
  });
}
