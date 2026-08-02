import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/finance/presentation/finance_pages.dart';

import '../dashboard/fixtura.dart';

/// Regressão do achado "Valor de reserva acima de 999 € é gravado como
/// zero, sem aviso" (`docs/AUDITORIA_EMPRESARIO_EXEMPLAR.md`, Eixo 3): a
/// mesma leitura de euros que só trocava vírgula por ponto — sem tratar o
/// separador de milhar português — vivia também em Despesa e Recebimento.
/// `(double.tryParse(...) ?? 0)` inventava um zero calado sempre que o texto
/// não dava para ler; agora usa `centsDeTexto`, que nunca inventa zero, e o
/// formulário recusa a gravação com aviso visível quando o texto é lixo.
///
/// As páginas de Despesa/Recebimento fazem `Navigator.pop(context)` ao
/// gravar — por isso montam-se aqui empurradas a partir de um ecrã inicial,
/// como acontece na app real (`financas_page.dart`), em vez de como corpo
/// único do `Scaffold`: sem uma rota anterior, o `pop` não teria para onde ir.
Future<ProviderContainer> _abrirEmpurrado(
  WidgetTester tester,
  Widget pagina, {
  OperationsState? estado,
}) async {
  final container = containerCom(estado ?? estadoComMovimento());
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: PunhoTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => pagina),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  Future<void> escreverEGuardar(WidgetTester tester, String valor) async {
    await tester.enterText(find.byType(TextField).first, valor);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
  }

  group('Despesa', () {
    testWidgets('"1.500,00" (separador de milhar PT) grava 1500 €, não zero', (
      tester,
    ) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      await escreverEGuardar(tester, '1.500,00');

      final despesas = container.read(operationsProvider).expenses;
      expect(despesas, hasLength(1));
      expect(despesas.single.amountCents, 150000);
    });

    testWidgets('"1 500,00" (milhar com espaço) grava 1500 €', (tester) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      await escreverEGuardar(tester, '1 500,00');

      expect(
        container.read(operationsProvider).expenses.single.amountCents,
        150000,
      );
    });

    testWidgets('"1500" sem separadores grava 1500 €', (tester) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      await escreverEGuardar(tester, '1500');

      expect(
        container.read(operationsProvider).expenses.single.amountCents,
        150000,
      );
    });

    testWidgets('"1500,5" grava 1500,50 €', (tester) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      await escreverEGuardar(tester, '1500,5');

      expect(
        container.read(operationsProvider).expenses.single.amountCents,
        150050,
      );
    });

    testWidgets('texto ilegível recusa com aviso — não grava zero calado', (
      tester,
    ) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      // A fixtura já traz despesas — o que importa é que a contagem não
      // mude, não que a lista esteja vazia.
      final antes = container.read(operationsProvider).expenses.length;
      await escreverEGuardar(tester, '1.500.00');

      expect(
        find.text(
          'Não consigo ler o valor "1.500.00" — escreve por exemplo 1.500,00.',
        ),
        findsOneWidget,
      );
      expect(container.read(operationsProvider).expenses.length, antes);
    });

    testWidgets('campo vazio pede para preencher — não grava zero calado', (
      tester,
    ) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterExpensePage(),
      );
      final antes = container.read(operationsProvider).expenses.length;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Indica um valor superior a zero.'), findsOneWidget);
      expect(container.read(operationsProvider).expenses.length, antes);
    });
  });

  group('aviso visível com o teclado aberto — não escondido atrás dele como o '
      'SnackBar ficava', () {
    // Simula o teclado aberto, tal como em dialogos_formulario_test.dart:
    // é isto que o sistema faz ao focar um campo.
    void abrirTeclado(WidgetTester tester, {double altura = 220}) {
      tester.view.viewInsets = FakeViewPadding(
        bottom: altura * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('Despesa: o aviso fica dentro da área visível', (tester) async {
      await _abrirEmpurrado(tester, const RegisterExpensePage());
      abrirTeclado(tester);
      await tester.pumpAndSettle();
      await escreverEGuardar(tester, '1.500.00');

      // A altura útil é o ecrã (800) menos o teclado (220): um SnackBar
      // nasce encostado aos 800 e fica invisível; o aviso, dentro do
      // Scaffold que encolhe com o teclado, tem de ficar acima de 580.
      final aviso = tester.getRect(
        find.text(
          'Não consigo ler o valor "1.500.00" — escreve por exemplo '
          '1.500,00.',
        ),
      );
      expect(aviso.bottom, lessThanOrEqualTo(800 - 220));
      // E não é um SnackBar: essa era a causa da mensagem ficar escondida.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Recebimento: o aviso fica dentro da área visível', (
      tester,
    ) async {
      await _abrirEmpurrado(tester, const RegisterReceiptPage());
      abrirTeclado(tester);
      await tester.pumpAndSettle();
      await escreverEGuardar(tester, 'abc');

      final aviso = tester.getRect(
        find.text(
          'Não consigo ler o valor "abc" — escreve por exemplo 1.500,00.',
        ),
      );
      expect(aviso.bottom, lessThanOrEqualTo(800 - 220));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Recebimento', () {
    testWidgets('"1.500,00" (separador de milhar PT) grava 1500 €, não zero', (
      tester,
    ) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterReceiptPage(),
      );
      await escreverEGuardar(tester, '1.500,00');

      final recebimentos = container.read(operationsProvider).receipts;
      expect(recebimentos, hasLength(1));
      expect(recebimentos.single.amountCents, 150000);
    });

    testWidgets('texto ilegível recusa com aviso — não grava zero calado', (
      tester,
    ) async {
      final container = await _abrirEmpurrado(
        tester,
        const RegisterReceiptPage(),
      );
      final antes = container.read(operationsProvider).receipts.length;
      await escreverEGuardar(tester, 'abc');

      expect(
        find.text(
          'Não consigo ler o valor "abc" — escreve por exemplo 1.500,00.',
        ),
        findsOneWidget,
      );
      expect(container.read(operationsProvider).receipts.length, antes);
    });
  });
}
