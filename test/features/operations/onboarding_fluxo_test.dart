import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/boas_vindas_screen.dart';
import 'package:punho/features/operations/presentation/mais_dados_screen.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// O percurso do onboarding com os dois ecrãs de contexto pelo meio.
///
/// O que interessa fixar: **nada é gravado até "Entrar na Punho"**. Antes desta
/// sprint o `completeOnboarding` era chamado pelo botão do último campo, e o
/// gestor caía no painel sem transição nenhuma.
void main() {
  ProviderContainer containerVazio() {
    final container = ProviderContainer(
      overrides: [
        operationRepositoryProvider.overrideWithValue(_RepoVazio()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continuar(WidgetTester tester, {int vezes = 1}) async {
    for (var i = 0; i < vezes; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
  }

  /// Avança até ao passo do switch (índice 6), que é o 7º de dados.
  Future<void> irAteAoSwitch(WidgetTester tester) async {
    await continuar(tester, vezes: 6);
    expect(find.text('Continuar com os dados operacionais?'), findsOneWidget);
  }

  testWidgets('caminho longo: o switch leva ao MaisDados, não ao passo 7', (
    tester,
  ) async {
    // O switch está ON por omissão.
    await abrir(tester, containerVazio());
    await irAteAoSwitch(tester);
    await continuar(tester);

    expect(find.byType(MaisDadosScreen), findsOneWidget);
    expect(find.text('Quantas máquinas tem aproximadamente?'), findsNothing);
  });

  testWidgets('depois do MaisDados vem o passo 7, e no fim o BoasVindas', (
    tester,
  ) async {
    await abrir(tester, containerVazio());
    await irAteAoSwitch(tester);
    await continuar(tester);
    await tester.tap(find.text('Continuar →'));
    await tester.pumpAndSettle();

    expect(find.text('Quantas máquinas tem aproximadamente?'), findsOneWidget);
    expect(find.text('8 de 12'), findsOneWidget);

    // Os cinco passos que faltam: máquinas, 2× facturação, manutenção, custos.
    await continuar(tester, vezes: 5);

    expect(find.byType(BoasVindasScreen), findsOneWidget);
  });

  testWidgets('campos financeiros recebem foco em cada avanço', (tester) async {
    await abrir(tester, containerVazio());
    await irAteAoSwitch(tester);
    await continuar(tester);
    await tester.tap(find.text('Continuar →'));
    await tester.pumpAndSettle();

    // Máquinas → volume de negócios do ano passado.
    await continuar(tester);
    expect(
      find.text('Qual foi o volume de negócios no ano passado?'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    tester.testTextInput.enterText('100000');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '100000',
    );

    // O utilizador só toca em Continuar. O campo seguinte deve aceitar texto
    // imediatamente, sem um toque adicional dentro do campo.
    await continuar(tester);
    expect(
      find.text(
        'Qual é o volume de negócios acumulado desde o início do ano até hoje?',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    tester.testTextInput.enterText('65000');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '65000',
    );

    await continuar(tester);
    expect(
      find.text('Quanto gastou em manutenção no ano passado?'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    tester.testTextInput.enterText('5000');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '5000',
    );

    await continuar(tester);
    expect(find.text('Quais são os custos fixos mensais?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    tester.testTextInput.enterText('2500');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '2500',
    );
  });

  testWidgets('caminho curto: o switch leva directo ao BoasVindas', (
    tester,
  ) async {
    await abrir(tester, containerVazio());
    await irAteAoSwitch(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await continuar(tester);

    expect(find.byType(BoasVindasScreen), findsOneWidget);
    expect(find.byType(MaisDadosScreen), findsNothing);
    expect(find.text('Quantas máquinas tem aproximadamente?'), findsNothing);
  });

  testWidgets('nada é gravado antes de "Entrar na Punho"', (tester) async {
    final container = containerVazio();
    await abrir(tester, container);
    await tester.enterText(find.byType(TextField).first, 'César');
    await irAteAoSwitch(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await continuar(tester);

    expect(find.byType(BoasVindasScreen), findsOneWidget);
    expect(
      container.read(operationsProvider).onboarded,
      isFalse,
      reason: 'o onboarding não pode estar concluído antes do último botão',
    );

    await tester.tap(find.text('Entrar na Punho →'));
    await tester.pumpAndSettle();

    expect(container.read(operationsProvider).onboarded, isTrue);
    expect(container.read(operationsProvider).ownerName, 'César');
  });

  testWidgets('voltar do BoasVindas devolve ao switch e não grava', (
    tester,
  ) async {
    final container = containerVazio();
    await abrir(tester, container);
    await irAteAoSwitch(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await continuar(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar com os dados operacionais?'), findsOneWidget);
    expect(container.read(operationsProvider).onboarded, isFalse);
  });

  testWidgets('voltar do MaisDados devolve ao switch', (tester) async {
    await abrir(tester, containerVazio());
    await irAteAoSwitch(tester);
    await continuar(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar com os dados operacionais?'), findsOneWidget);
  });

  testWidgets('o colaborador não passa pelo ecrã de boas-vindas', (
    tester,
  ) async {
    // O ecrã promete um painel que o shell do colaborador não tem, e pede uma
    // rotação que ele não faz — fica em retrato por decisão da v0.0.5.
    final container = containerVazio();
    await abrir(tester, container);
    await continuar(tester, vezes: 2);

    expect(find.text('Qual é o teu cargo?'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colaborador').last);
    await tester.pumpAndSettle();
    await continuar(tester);

    expect(find.text('4 de 4'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Começar'));
    await tester.pumpAndSettle();

    expect(find.byType(BoasVindasScreen), findsNothing);
    expect(container.read(operationsProvider).onboarded, isTrue);
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
