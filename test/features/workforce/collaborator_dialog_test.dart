import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/dialogo_de_formulario.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// O diálogo dos colaboradores era o pior dos três: seis campos que não rolavam
/// com o teclado aberto e — por cima disso — nenhuma forma de sair sem gravar.
/// Não tinha Cancelar e não fechava ao tocar fora. Quem o abrisse por engano
/// tinha de criar um colaborador para se ver livre dele.
void main() {
  Future<ProviderContainer> abrir(
    WidgetTester tester, {
    Size tamanho = const Size(1280, 800),
  }) async {
    final container = containerCom(estadoComMovimento());
    await montarLandscape(
      tester,
      container,
      const CollaboratorsPage(),
      tamanho: tamanho,
    );
    await tester.tap(find.text('Adicionar colaborador').first);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('há sempre saída: Cancelar fecha sem gravar', (tester) async {
    final h = await abrir(tester);

    await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(DialogoDeFormulario), findsNothing);
    expect(
      h.read(operationsProvider).collaborators.map((c) => c.name),
      isNot(contains('Manuel Silva')),
    );
  });

  testWidgets('guardar sem nome avisa e não cria colaborador anónimo', (
    tester,
  ) async {
    final h = await abrir(tester);
    final antes = h.read(operationsProvider).collaborators.length;

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Indica o nome do colaborador.'), findsOneWidget);
    expect(find.byType(DialogoDeFormulario), findsOneWidget);
    expect(
      h.read(operationsProvider).collaborators.length,
      antes,
    );
  });

  testWidgets('com nome guarda e fecha', (tester) async {
    final h = await abrir(tester);

    await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      h.read(operationsProvider).collaborators.map((c) => c.name),
      contains('Manuel Silva'),
    );
    expect(find.byType(DialogoDeFormulario), findsNothing);
  });

  testWidgets('em retrato com o teclado aberto o Guardar continua visível', (
    tester,
  ) async {
    await abrir(tester, tamanho: const Size(420, 900));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 320 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Guardar')).bottom,
      lessThanOrEqualTo(900 - 320),
      reason: 'o Guardar está debaixo do teclado',
    );
    // E o último campo alcança-se a rolar.
    await tester.scrollUntilVisible(
      find.text('Horas semanais previstas'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Horas semanais previstas'), findsOneWidget);
  });

  testWidgets('exceder as vagas contratadas não fecha o diálogo', (
    tester,
  ) async {
    // O limite vem das vagas contratadas; o saveCollaborator lança StateError.
    // Antes a mensagem aparecia e o diálogo ficava aberto — comportamento certo
    // que se mantém agora que há Cancelar.
    final container = containerCom(
      estadoComMovimento().copyWith(activeCollaboratorLimit: 0),
    );
    await montarLandscape(tester, container, const CollaboratorsPage());
    await tester.tap(find.text('Adicionar colaborador').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(DialogoDeFormulario), findsOneWidget);
    expect(
      container.read(operationsProvider).collaborators.map((c) => c.name),
      isNot(contains('Manuel Silva')),
    );
  });
}
