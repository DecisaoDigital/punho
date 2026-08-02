import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// O onboarding com o teclado aberto.
///
/// O passo da morada tem cinco campos e não cabe no que sobra do ecrã quando o
/// teclado sobe: no telemóvel do Cesar rebentava 59 dp por baixo, com a barra
/// amarela por cima do campo do email. O ecrã passou a rolar — e este teste
/// existe para que volte a rebentar aqui antes de rebentar no telemóvel dele.
void main() {
  ProviderContainer containerVazio() {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Redmi Note 10 Pro em pé, com o teclado a ocupar quase metade do ecrã.
  Future<void> abrirComTeclado(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerVazio(),
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> avancar(WidgetTester tester, int passos) async {
    for (var i = 0; i < passos; i++) {
      // Passo do NIF (obrigatório desde 2026-08-02): sem preencher, o botão
      // fica no mesmo passo e este loop nunca chega à morada.
      final nif = find.widgetWithText(TextField, 'NIF da empresa');
      if (nif.evaluate().isNotEmpty) {
        await tester.enterText(nif, '509442129');
        await tester.pumpAndSettle();
      }
      // Com o teclado aberto o botão fica abaixo do que se vê. Está na árvore
      // — o que é preciso é rolar até ele, tal como faz quem usa a app.
      await tester.ensureVisible(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('o passo da morada não rebenta com o teclado aberto', (
    tester,
  ) async {
    await abrirComTeclado(tester);
    // Nome, dono, NIF, telefone — e chega-se à morada, o passo com mais campos.
    await avancar(tester, 4);

    expect(find.text('Morada'), findsOneWidget);
    // Um overflow é lançado como excepção do framework durante o layout: se
    // houvesse, `pumpAndSettle` já a teria deixado aqui.
    expect(tester.takeException(), isNull);
  });

  testWidgets('com o teclado aberto chega-se ao botão a rolar', (tester) async {
    await abrirComTeclado(tester);
    await avancar(tester, 4);

    // O botão pode ficar abaixo do teclado — o que não pode é ser inalcançável.
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem teclado o conteúdo continua centrado, e não colado ao topo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerVazio(),
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    // O `minHeight` do scroll é o que mantém o `Center` a centrar. Sem ele o
    // conteúdo encostava ao topo em todos os passos.
    final topo = tester.getTopLeft(find.text('1 de 12')).dy;
    expect(topo, greaterThan(100));
  });
}

class _RepoVazio implements OperationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
