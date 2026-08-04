import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';
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

  testWidgets('há sempre saída, e ela pergunta antes de deitar fora', (
    tester,
  ) async {
    final h = await abrir(tester);

    await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem guardar?'), findsOneWidget);
    await tester.tap(find.text('Sair sem guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(EcraDeFormulario), findsNothing);
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
    expect(find.byType(EcraDeFormulario), findsOneWidget);
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
    expect(find.byType(EcraDeFormulario), findsNothing);
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

  testWidgets(
    'exceder as vagas contratadas grava na mesma e avisa sem fechar',
    (tester) async {
      // Decisão de 2026-08-02: exceder o autorizado já não recusa a
      // gravação — só avisa, e o diálogo fica aberto para o gestor ler o
      // aviso em vez de o perder atrás de um `SnackBar`.
      final container = containerCom(
        estadoComMovimento().copyWith(activeCollaboratorLimit: 0),
      );
      await montarLandscape(tester, container, const CollaboratorsPage());
      await tester.tap(find.text('Adicionar colaborador').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(EcraDeFormulario), findsOneWidget);
      expect(
        container.read(operationsProvider).collaborators.map((c) => c.name),
        contains('Manuel Silva'),
      );
      expect(find.textContaining('só acede depois de'), findsOneWidget);
    },
  );

  // Regressão do achado "valor gravado como zero, sem aviso"
  // (docs/AUDITORIA_EMPRESARIO_EXEMPLAR.md, achado 1): o custo do colaborador
  // usava a mesma leitura de euros que só trocava vírgula por ponto, sem
  // tratar o separador de milhar português.
  group('custo estimado (€) — separador de milhar', () {
    Future<ProviderContainer> preencherNomeECusto(
      WidgetTester tester,
      String custo,
    ) async {
      final h = await abrir(tester);
      await tester.enterText(find.byType(TextField).first, 'Manuel Silva');
      final campoCusto = find.ancestor(
        of: find.text('Custo estimado para a empresa (€)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(campoCusto, custo);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('"1.500,00" grava 1500 € de custo, não zero', (tester) async {
      final h = await preencherNomeECusto(tester, '1.500,00');

      expect(find.byType(EcraDeFormulario), findsNothing);
      final colaborador = h
          .read(operationsProvider)
          .collaborators
          .firstWhere((c) => c.name == 'Manuel Silva');
      expect(colaborador.costCents, 150000);
    });

    testWidgets('campo de custo vazio fica "por apurar", não grava zero', (
      tester,
    ) async {
      final h = await preencherNomeECusto(tester, '');

      expect(find.byType(EcraDeFormulario), findsNothing);
      final colaborador = h
          .read(operationsProvider)
          .collaborators
          .firstWhere((c) => c.name == 'Manuel Silva');
      expect(colaborador.costCents, isNull);
    });

    testWidgets(
      'texto ilegível ("1.500.00") recusa a gravação com aviso visível',
      (tester) async {
        final h = await preencherNomeECusto(tester, '1.500.00');

        expect(find.byType(EcraDeFormulario), findsOneWidget);
        expect(
          find.textContaining('Não consigo ler o custo estimado'),
          findsOneWidget,
        );
        expect(
          h.read(operationsProvider).collaborators.map((c) => c.name),
          isNot(contains('Manuel Silva')),
        );
      },
    );
  });
}
