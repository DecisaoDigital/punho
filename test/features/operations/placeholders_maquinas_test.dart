import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';

import '../dashboard/fixtura.dart';

/// "Um gestor com 200 máquinas não vai lá numerar e fotografar todas ao mesmo
/// tempo": declarar N cria N linhas prontas a serem baptizadas aos poucos.
ProviderContainer containerVazio() {
  final container = ProviderContainer(
    overrides: [
      operationRepositoryProvider.overrideWithValue(
        // Sem os dados de demonstração, senão a guarda `machines.isEmpty` nunca
        // deixava criar placeholders.
        _RepoVazio(),
      ),
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
  group('Criação a partir do onboarding', () {
    test('declarar 20 cria 20 linhas por identificar', () {
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

      final maquinas = c.read(operationsProvider).machines;
      expect(maquinas, hasLength(20));
      expect(maquinas.every((m) => m.placeholder), isTrue);
      expect(maquinas.every((m) => m.status == MachineStatus.available), isTrue);
      expect(maquinas.every((m) => !m.archived), isTrue);
      expect(maquinas.map((m) => m.name), contains('Máquina 1'));
      expect(maquinas.map((m) => m.name), contains('Máquina 20'));
      expect(maquinas.every((m) => m.category == 'Por identificar'), isTrue);
    });

    test('re-onboarding com máquinas já criadas não duplica', () {
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

      expect(c.read(operationsProvider).machines, hasLength(1));
    });

    test('declarar zero não cria nada', () {
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

    test('subir de 20 para 25 cria as cinco que faltam', () {
      final c = comOnboardingE(20);

      c.read(operationsProvider.notifier).updateCompanySettings(
        totalMachinesDeclared: 25,
      );

      final maquinas = c.read(operationsProvider).machines;
      expect(maquinas, hasLength(25));
      expect(maquinas.map((m) => m.name), contains('Máquina 21'));
      expect(maquinas.map((m) => m.name), contains('Máquina 25'));
      expect(
        maquinas.where((m) => m.name == 'Máquina 21').single.placeholder,
        isTrue,
      );
    });

    test('descer de 20 para 15 não apaga máquina nenhuma', () {
      // Eliminar uma máquina é decisão explícita, pelo caixote da lista — nunca
      // efeito secundário de mexer num contador.
      final c = comOnboardingE(20);

      c.read(operationsProvider.notifier).updateCompanySettings(
        totalMachinesDeclared: 15,
      );

      expect(c.read(operationsProvider).machines, hasLength(20));
      expect(c.read(operationsProvider).totalMachinesDeclared, 15);
    });
  });

  group('Identificar', () {
    test('guardar uma placeholder com nome novo desliga o flag', () {
      final c = comPlaceholders(3);
      final notifier = c.read(operationsProvider.notifier);
      final placeholder = c.read(operationsProvider).machines.first;

      notifier.saveMachine(
        placeholder.copyWith(name: 'Mini escavadora 1.8T', placeholder: false),
      );

      final guardada = c
          .read(operationsProvider)
          .machines
          .firstWhere((m) => m.id == placeholder.id);
      expect(guardada.name, 'Mini escavadora 1.8T');
      expect(guardada.placeholder, isFalse);
    });
  });

  group('Tarefas', () {
    test('contam placeholders e não o delta do contador', () {
      final c = comPlaceholders(4);
      final estado = c.read(operationsProvider);

      // O delta declaradas − registadas é zero (4 declaradas, 4 linhas), mas há
      // quatro por baptizar.
      expect(estado.machinesStillToIdentify, 0);
      expect(estado.placeholdersDeMaquinas, 4);

      final tarefa = tarefasPendentes(estado, agoraFixa).firstWhere(
        (t) => t.id == 'maquinas-por-identificar',
      );
      expect(tarefa.titulo, '4 máquinas por identificar');
      expect(tarefa.cta, 'Abrir Máquinas');
    });

    test('identificar todas faz a tarefa desaparecer', () {
      final c = comPlaceholders(1);
      final notifier = c.read(operationsProvider.notifier);
      final unica = c.read(operationsProvider).machines.single;

      notifier.saveMachine(unica.copyWith(name: 'Martelo', placeholder: false));

      expect(
        tarefasPendentes(
          c.read(operationsProvider),
          agoraFixa,
        ).where((t) => t.id == 'maquinas-por-identificar'),
        isEmpty,
      );
    });
  });

  group('Lista de máquinas', () {
    testWidgets('identificadas em cima, placeholders no fim com o chip', (
      tester,
    ) async {
      final c = comPlaceholders(2);
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

      final nomes = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => t.startsWith('Máquina ') || t.contains('escavadora'))
          .toList();
      expect(
        nomes.first,
        'Mini escavadora 1.8T',
        reason: 'a identificada vem primeiro',
      );
      // Só as placeholders levam o chip.
      expect(find.text('Por identificar'), findsNWidgets(2));
    });
  });
}

/// Container com [quantidade] placeholders e nada mais.
ProviderContainer comPlaceholders(int quantidade) {
  final c = containerVazio();
  c.read(operationsProvider.notifier).completeOnboarding(
    companyName: 'Alugueres Norte',
    legalForm: 'Lda.',
    hasFleet: false,
    collaborators: 0,
    totalMachinesDeclared: quantidade,
    insertMachinesNow: false,
  );
  return c;
}
