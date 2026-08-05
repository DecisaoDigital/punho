import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// **A ordem das primeiras perguntas do gestor, e o tecto dos funcionários.**
///
/// «depois do Bem-vindo pedes o contribuinte, o número de funcionários e se
/// existem veículos da empresa e quantos. Com o número de funcionários, se
/// passar de 3, uma nota de rodapé: limite temporário de máx. 3 funcionários,
/// fale com a Decisão Digital para desbloquear mais» — Cesar, 5/8/2026.
///
/// Duas coisas a fixar. A primeira é a ordem: NIF, funcionários, veículos — e
/// só depois a morada, que serve documentos e não números. A segunda é que a
/// nota **avisa e deixa passar**: nada nesta app recusa um funcionário por
/// causa do plano desde 2/8/2026; quem trava o acesso de quem excede é a
/// aprovação no Control.
void main() {
  ProviderContainer containerVazio() {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerVazio(),
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

  /// Nome, empresa, cargo e NIF — e pára no passo dos funcionários.
  Future<void> irAteAosFuncionarios(WidgetTester tester) async {
    await abrir(tester);
    await continuar(tester, vezes: 3);
    await tester.enterText(find.byType(TextField).last, '509442129');
    await continuar(tester);
    expect(find.text('Quantos funcionários tem a empresa?'), findsOneWidget);
  }

  /// Toca no `+` do contador de funcionários.
  Future<void> maisUm(WidgetTester tester, {int vezes = 1}) async {
    for (var i = 0; i < vezes; i++) {
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
    }
  }

  final nota = find.textContaining('Limite temporário');

  testWidgets('o contribuinte vem primeiro, e a morada não se mete à frente', (
    tester,
  ) async {
    await abrir(tester);
    await continuar(tester, vezes: 3);

    expect(find.text('Forma jurídica e NIF da empresa'), findsOneWidget);
    expect(find.text('Morada'), findsNothing);
  });

  testWidgets(
    'depois do NIF: funcionários, veículos, contacto, e só então a morada',
    (tester) async {
      await irAteAosFuncionarios(tester);
      await continuar(tester);

      expect(find.text('A empresa tem veículos? Quantos?'), findsOneWidget);
      await continuar(tester);

      // «quero que perguntes o contacto no primeiro log in» — Cesar, 5/8/2026.
      // Estava lá, mas como quarto campo do ecrã da morada.
      expect(find.text('Contacto:'), findsOneWidget);
      await continuar(tester);

      expect(find.text('Morada da empresa'), findsOneWidget);
    },
  );

  testWidgets('até três funcionários não há nota nenhuma', (tester) async {
    await irAteAosFuncionarios(tester);

    expect(nota, findsNothing);
    await maisUm(tester, vezes: 3);

    // Três é o limite, não é excedê-lo. Avisar em cima do número autorizado
    // seria dizer a quem está dentro do plano que está fora dele.
    expect(find.text('3'), findsOneWidget);
    expect(nota, findsNothing);
  });

  testWidgets('ao quarto funcionário aparece a nota de rodapé', (tester) async {
    await irAteAosFuncionarios(tester);
    await maisUm(tester, vezes: 4);

    expect(nota, findsOneWidget);
    expect(find.textContaining('Decisão Digital'), findsOneWidget);
  });

  testWidgets('a nota avisa, não tranca: continua a avançar', (tester) async {
    // O bloqueio foi tirado a 2/8/2026 e não volta por uma nota de rodapé.
    await irAteAosFuncionarios(tester);
    await maisUm(tester, vezes: 7);
    await continuar(tester);

    expect(find.text('A empresa tem veículos? Quantos?'), findsOneWidget);
  });

  testWidgets('descer abaixo de quatro tira a nota', (tester) async {
    await irAteAosFuncionarios(tester);
    await maisUm(tester, vezes: 4);
    expect(nota, findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();

    expect(nota, findsNothing);
  });

  testWidgets('o número declarado chega ao estado como foi escrito', (
    tester,
  ) async {
    // Sete declarados gravam sete. A nota não corta para três — o número é a
    // realidade da empresa, o limite é outra conversa.
    final container = containerVazio();
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

    await continuar(tester, vezes: 3);
    await tester.enterText(find.byType(TextField).last, '509442129');
    await continuar(tester);
    await maisUm(tester, vezes: 7);
    // Veículos, contacto, morada, switch — e desliga-o para entrar sem os
    // financeiros.
    await continuar(tester, vezes: 4);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await continuar(tester);
    await tester.tap(find.text('Entrar na Punho →'));
    await tester.pumpAndSettle();

    expect(container.read(operationsProvider).declaredCollaboratorCount, 7);
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
