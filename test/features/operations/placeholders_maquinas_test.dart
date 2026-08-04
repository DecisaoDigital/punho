import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';

import '../dashboard/fixtura.dart';

/// Decisão de 2026-08-02: o onboarding não cria registos automaticamente.
/// "Um gestor com 200 máquinas não vai lá numerar e fotografar todas ao mesmo
/// tempo" continua verdade, mas a resposta deixou de ser inventar 200 linhas
/// — é a app ficar vazia e **lembrar** o que falta registar, contando contra
/// o total declarado.
ProviderContainer containerVazio() {
  final container = ProviderContainer(
    overrides: [
      operationRepositoryProvider.overrideWithValue(_RepoVazio()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}

void main() {
  group('Onboarding não cria máquinas', () {
    test('declarar 20 não cria linha nenhuma', () {
      final c = containerVazio();
      final notifier = c.read(operationsProvider.notifier);

      notifier.completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 20,
        insertMachinesNow: false,
      );

      expect(c.read(operationsProvider).machines, isEmpty);
      expect(c.read(operationsProvider).totalMachinesDeclared, 20);
    });

    test('declarar zero também não cria nada', () {
      final c = containerVazio();
      c.read(operationsProvider.notifier).completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 0,
        insertMachinesNow: false,
      );

      expect(c.read(operationsProvider).machines, isEmpty);
    });

    test('máquinas registadas à mão antes do onboarding não são tocadas', () {
      final c = containerVazio();
      final notifier = c.read(operationsProvider.notifier);
      notifier.saveMachine(
        const Machine(
          id: 'ja-existe',
          name: 'Mini escavadora',
          reference: 'ME-01',
          category: 'Escavação',
          status: MachineStatus.available,
        ),
      );

      notifier.completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 20,
        insertMachinesNow: false,
      );

      final maquinas = c.read(operationsProvider).machines;
      expect(maquinas, hasLength(1));
      expect(maquinas.single.name, 'Mini escavadora');
    });
  });

  group('Alterar o total nas Definições', () {
    ProviderContainer comOnboardingE(int declaradas) {
      final c = containerVazio();
      c.read(operationsProvider.notifier).completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: declaradas,
        insertMachinesNow: false,
      );
      return c;
    }

    test('subir de 20 para 25 não cria máquina nenhuma', () {
      final c = comOnboardingE(20);

      c.read(operationsProvider.notifier).updateCompanySettings(
        totalMachinesDeclared: 25,
      );

      expect(c.read(operationsProvider).machines, isEmpty);
      expect(c.read(operationsProvider).totalMachinesDeclared, 25);
    });

    test('descer de 20 para 15 não apaga máquina nenhuma', () {
      // Eliminar uma máquina é decisão explícita, pelo caixote da lista — nunca
      // efeito secundário de mexer num contador.
      final c = containerVazio();
      c.read(operationsProvider.notifier).completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 20,
        insertMachinesNow: false,
      );
      c.read(operationsProvider.notifier).saveMachine(
        const Machine(
          id: 'm1',
          name: 'Mini escavadora',
          reference: 'ME-01',
          category: 'Escavação',
          status: MachineStatus.available,
        ),
      );

      c.read(operationsProvider.notifier).updateCompanySettings(
        totalMachinesDeclared: 15,
      );

      expect(c.read(operationsProvider).machines, hasLength(1));
      expect(c.read(operationsProvider).totalMachinesDeclared, 15);
    });
  });

  group('Tarefas contam contra o declarado', () {
    test('declaradas sem nenhuma registada gera a tarefa com o total', () {
      final c = containerVazio();
      c.read(operationsProvider.notifier).completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 4,
        insertMachinesNow: false,
      );
      final estado = c.read(operationsProvider);

      expect(estado.machinesStillToIdentify, 4);

      final tarefa = tarefasPendentes(estado, agoraFixa).firstWhere(
        (t) => t.id == 'maquinas-por-identificar',
      );
      expect(tarefa.titulo, 'Identificar 4 máquinas');
      expect(tarefa.cta, 'Abrir Máquinas');
    });

    test('registar as máquinas descontas ao que falta e a tarefa desaparece', () {
      final c = containerVazio();
      final notifier = c.read(operationsProvider.notifier);
      notifier.completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 1,
        insertMachinesNow: false,
      );

      notifier.saveMachine(
        const Machine(
          id: 'martelo',
          name: 'Martelo',
          reference: 'MT-01',
          category: 'Demolição',
          status: MachineStatus.available,
        ),
      );

      final estado = c.read(operationsProvider);
      expect(estado.machinesStillToIdentify, 0);
      expect(
        tarefasPendentes(estado, agoraFixa).where(
          (t) => t.id == 'maquinas-por-identificar',
        ),
        isEmpty,
      );
    });

    test('registar mais do que o declarado não gera tarefa negativa', () {
      final c = containerVazio();
      final notifier = c.read(operationsProvider.notifier);
      notifier.completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 1,
        insertMachinesNow: false,
      );
      notifier.saveMachine(
        const Machine(
          id: 'm1',
          name: 'Martelo',
          reference: 'MT-01',
          category: 'Demolição',
          status: MachineStatus.available,
        ),
      );
      notifier.saveMachine(
        const Machine(
          id: 'm2',
          name: 'Compressor',
          reference: 'CP-01',
          category: 'Compressão',
          status: MachineStatus.available,
        ),
      );

      final estado = c.read(operationsProvider);
      expect(estado.machinesStillToIdentify, 0);
      expect(estado.inventoryIdentifiedAboveEstimate, isTrue);
      expect(
        tarefasPendentes(estado, agoraFixa).where(
          (t) => t.id == 'maquinas-por-identificar',
        ),
        isEmpty,
      );
    });
  });

  group('Lista de máquinas', () {
    testWidgets('mostra as máquinas registadas, sem linhas inventadas', (
      tester,
    ) async {
      final c = containerVazio();
      c.read(operationsProvider.notifier).completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 2,
        insertMachinesNow: false,
      );
      c.read(operationsProvider.notifier).saveMachine(
        const Machine(
          id: 'identificada',
          name: 'Mini escavadora 1.8T',
          reference: 'ME-018',
          category: 'Escavação',
          status: MachineStatus.available,
        ),
      );
      await montarLandscape(tester, c, const MachinesPage());

      expect(find.text('Mini escavadora 1.8T'), findsOneWidget);
      expect(find.text('Por identificar'), findsNothing);
      expect(find.text('Escavação · ME-018'), findsOneWidget);
    });

    testWidgets('máquina sem referência não fica com um ponto pendurado', (
      tester,
    ) async {
      // Uma máquina criada em lote traz nome e pouco mais. A sub-linha
      // interpolava categoria e referência às cegas e escrevia "Lavadora 8 kg
      // · " com o separador a apontar para o nada (visto no Redmi).
      final c = containerVazio();
      c.read(operationsProvider.notifier).saveMachine(
        const Machine(
          id: 'so-nome',
          name: 'Lavadora 8 kg',
          reference: '',
          category: '',
          status: MachineStatus.available,
        ),
      );

      await montarLandscape(tester, c, const MachinesPage());

      expect(find.text('Lavadora 8 kg'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('com categoria e sem referência mostra só a categoria', (
      tester,
    ) async {
      final c = containerVazio();
      c.read(operationsProvider.notifier).saveMachine(
        const Machine(
          id: 'so-categoria',
          name: 'Secador 20 kg',
          reference: '',
          category: 'Secagem',
          status: MachineStatus.available,
        ),
      );

      await montarLandscape(tester, c, const MachinesPage());

      expect(find.text('Secagem'), findsOneWidget);
      expect(find.textContaining('Secagem ·'), findsNothing);
    });
  });
}
