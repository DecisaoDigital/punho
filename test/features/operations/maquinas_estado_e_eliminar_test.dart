import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// Dois problemas de UX apanhados pelo Cesar no smoke da v0.0.5: três controlos
/// para mudar o estado de uma máquina, e um botão que eliminava sem perguntar.
void main() {
  Future<void> montarMaquinas(WidgetTester tester, container) =>
      montarLandscape(tester, container, const MachinesPage());

  group('Estado: um só controlo', () {
    testWidgets('o swap_horiz e o botão "Disponível" desapareceram', (
      tester,
    ) async {
      await montarMaquinas(tester, containerCom(estadoComMovimento()));

      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      expect(find.widgetWithText(TextButton, 'Disponível'), findsNothing);
    });

    testWidgets('o chip abre o menu com quatro opções e sem "Parada"', (
      tester,
    ) async {
      await montarMaquinas(tester, containerCom(estadoComMovimento()));

      await tester.tap(find.byType(Chip).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PopupMenuItem<MachineStatus>, 'Disponível'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<MachineStatus>, 'Reservada'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<MachineStatus>, 'Alugada'), findsOneWidget);
      expect(
        find.widgetWithText(PopupMenuItem<MachineStatus>, 'Em manutenção'),
        findsOneWidget,
      );
      expect(find.text('Parada'), findsNothing);
    });

    testWidgets('escolher "Em manutenção" muda o estado da máquina', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarMaquinas(tester, container);

      await tester.tap(find.byType(Chip).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Em manutenção').last);
      await tester.pumpAndSettle();

      final maquinas = container.read(operationsProvider).machines;
      expect(
        maquinas.any((m) => m.status == MachineStatus.maintenance),
        isTrue,
      );
    });

    testWidgets('uma máquina antiga gravada como "Parada" lê-se disponível', (
      tester,
    ) async {
      final antiga = estadoComMovimento().copyWith(
        machines: const [
          Machine(
            id: 'legado',
            name: 'Máquina de backup antigo',
            reference: 'L-01',
            category: 'X',
            status: MachineStatus.stopped,
          ),
        ],
      );
      await montarMaquinas(tester, containerCom(antiga));

      expect(find.text('Disponível'), findsOneWidget);
      expect(find.text('Parada'), findsNothing);
    });
  });

  group('Eliminar: confirmação, undo e só gestor', () {
    testWidgets('o ícone é um caixote com o rótulo certo', (tester) async {
      await montarMaquinas(tester, containerCom(estadoComMovimento()));

      // Era `archive_outlined`, que o Cesar leu como "mover de sítio".
      expect(find.byIcon(Icons.archive_outlined), findsNothing);
      expect(find.byTooltip('Eliminar máquina'), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('cancelar não elimina nada', (tester) async {
      final container = containerCom(estadoComMovimento());
      await montarMaquinas(tester, container);
      final antes = container.read(operationsProvider).machines.length;

      await tester.tap(find.byTooltip('Eliminar máquina').first);
      await tester.pumpAndSettle();
      expect(find.text('Eliminar máquina?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(
        container
            .read(operationsProvider)
            .machines
            .where((m) => !m.archived)
            .length,
        antes,
      );
    });

    testWidgets('confirmar elimina e oferece 6 segundos para anular', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarMaquinas(tester, container);

      await tester.tap(find.byTooltip('Eliminar máquina').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Máquina eliminada.'), findsOneWidget);
      expect(find.text('Anular'), findsOneWidget);
      final arquivadas = container
          .read(operationsProvider)
          .machines
          .where((m) => m.archived);
      expect(arquivadas, isNotEmpty);

      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      expect(find.text('Máquina restaurada.'), findsOneWidget);
      expect(
        container.read(operationsProvider).machines.where((m) => m.archived),
        isEmpty,
      );
    });

    testWidgets('o diálogo não fecha ao tocar fora', (tester) async {
      await montarMaquinas(tester, containerCom(estadoComMovimento()));

      await tester.tap(find.byTooltip('Eliminar máquina').first);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar máquina?'), findsOneWidget);
    });
  });

  group('Quem pode eliminar', () {
    test('com Supabase, só o gestor', () {
      expect(podeEliminar(comSupabase: true, eGestor: true), isTrue);
      expect(podeEliminar(comSupabase: true, eGestor: false), isFalse);
    });

    test('sem Supabase assume-se gestor', () {
      // No modo de demonstração não há perfis: se aqui devolvesse falso, o
      // único utilizador possível ficava sem acesso a nada.
      expect(podeEliminar(comSupabase: false, eGestor: false), isTrue);
    });
  });

  group('unarchiveMachine', () {
    test('é idempotente e devolve a máquina à lista', () {
      final container = containerCom(estadoComMovimento());
      final notifier = container.read(operationsProvider.notifier);
      final id = container.read(operationsProvider).machines.first.id;

      notifier.archiveMachine(id);
      expect(
        container.read(operationsProvider).machines.firstWhere((m) => m.id == id).archived,
        isTrue,
      );

      notifier.unarchiveMachine(id);
      notifier.unarchiveMachine(id);
      expect(
        container.read(operationsProvider).machines.firstWhere((m) => m.id == id).archived,
        isFalse,
      );
    });
  });
}
