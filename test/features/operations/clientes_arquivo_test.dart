import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// `Customer.archived` e `archiveCustomer`/`unarchiveCustomer` já existiam no
/// modelo e no controlador (ver `operations_test.dart`), mas sem caminho na
/// app: a `ClientsPage` não tinha botão de eliminar, e um cliente arquivado
/// continuava a aparecer nos selectores de "Confirmar reserva" e "Nova
/// marcação". Um cliente duplicado por engano ficava na lista para sempre — e
/// mesmo arquivado, continuava a poder ser escolhido para reservas novas.
void main() {
  Future<void> montarClientes(WidgetTester tester, ProviderContainer c) =>
      montarLandscape(tester, c, const ClientsPage());

  group('ClientsPage — eliminar (arquivar) cliente', () {
    testWidgets('o ícone é um caixote com o rótulo certo, como nas máquinas', (
      tester,
    ) async {
      await montarClientes(tester, containerCom(estadoComMovimento()));

      expect(find.byTooltip('Eliminar cliente'), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('cancelar não elimina nada', (tester) async {
      final container = containerCom(estadoComMovimento());
      await montarClientes(tester, container);
      final antes = container.read(operationsProvider).customers.length;

      await tester.tap(find.byTooltip('Eliminar cliente').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Eliminar'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(
        container
            .read(operationsProvider)
            .customers
            .where((c) => !c.archived)
            .length,
        antes,
      );
    });

    testWidgets('confirmar elimina, some da lista e oferece 6s para anular', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarClientes(tester, container);
      expect(find.text('Construções Silva'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar cliente').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Construções Silva eliminado.'), findsOneWidget);
      expect(find.text('Anular'), findsOneWidget);
      // Some da lista — é esse o ponto de arquivar.
      expect(find.text('Construções Silva'), findsNothing);
      expect(
        container
            .read(operationsProvider)
            .customers
            .firstWhere((c) => c.id == 'c1')
            .archived,
        isTrue,
      );

      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      expect(find.text('Cliente restaurado.'), findsOneWidget);
      expect(find.text('Construções Silva'), findsOneWidget);
      expect(
        container
            .read(operationsProvider)
            .customers
            .firstWhere((c) => c.id == 'c1')
            .archived,
        isFalse,
      );
    });
  });

  group('Selectores de cliente excluem arquivados', () {
    // Um container real (não `ControllerFixo`): `archiveCustomer` grava no
    // repositório e depois relê o estado a partir dele (`state =
    // _fromRepo()`) — com `ControllerFixo`, essa releitura troca a fixtura
    // toda pelos dados de demonstração por baixo, e o teste deixa de ver o
    // que semeou. Mesmo padrão do `detalhe_de_cliente_test.dart`.
    ProviderContainer comClienteArquivado() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(operationsProvider.notifier);
      n.resetAll();
      n.addCustomer(
        const Customer(
          id: 'c-activo',
          name: 'Cliente Activo',
          phone: '911 000 001',
        ),
      );
      n.addCustomer(
        const Customer(
          id: 'c-arquivado',
          name: 'Cliente Arquivado',
          phone: '911 000 002',
        ),
      );
      n.saveMachine(
        const Machine(
          id: 'maq-1',
          name: 'Máquina Um',
          reference: 'MU-01',
          category: 'Categoria',
          status: MachineStatus.available,
        ),
      );
      n.archiveCustomer('c-arquivado');
      return container;
    }

    testWidgets('Confirmar reserva não lista o cliente arquivado', (
      tester,
    ) async {
      final container = comClienteArquivado();
      await montarLandscape(tester, container, const BookingsPage());

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('MU-01').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reservar (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar reserva'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Cliente Arquivado'), findsNothing);
      expect(find.textContaining('Cliente Activo'), findsWidgets);
    });

    testWidgets('Nova marcação não lista o cliente arquivado', (tester) async {
      final container = comClienteArquivado();
      await montarLandscape(
        tester,
        container,
        Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => showBookingForm(context, ref),
            child: const Text('abrir marcação'),
          ),
        ),
      );

      await tester.tap(find.text('abrir marcação'));
      await tester.pumpAndSettle();
      expect(find.text('Nova marcação / reserva'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Cliente'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cliente Arquivado'), findsNothing);
      // O cliente activo continua disponível — só o arquivado sai.
      expect(find.text('Cliente Activo'), findsWidgets);
    });
  });
}
