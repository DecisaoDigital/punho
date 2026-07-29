import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/dialogo_de_formulario.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/operations/presentation/boas_vindas_screen.dart';
import 'package:punho/features/operations/presentation/mais_dados_screen.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// Auditoria de hit target (task #206).
///
/// A regra: **a área que recebe o toque coincide com a área desenhada.** O
/// defeito que isto persegue é o de um `Container` colorido com um alvo menor
/// por dentro — ou, no caso do avatar da barra lateral, sem alvo nenhum.
///
/// O método é tocar **junto ao bordo de dentro** do desenho, e não no centro:
/// um centro acerta mesmo num alvo mal dimensionado, e é por isso que um teste
/// no centro não prova nada.
///
/// Nota do que a auditoria encontrou, para não se repetir o trabalho: seis dos
/// sete grupos já cumprem, porque usam botões do próprio Material
/// (`FilledButton`, `TextButton`, `PopupMenuButton`, `SegmentedButton`) — nesses
/// é o framework que garante `Material` + `InkWell` com a mesma bounding box. O
/// único que não cumpria era o avatar do Perfil, corrigido no passo anterior e
/// coberto em `test/features/conta/perfil_popup_test.dart`.
void main() {
  /// Toca a 2 dp do bordo esquerdo do widget, à altura do centro.
  Future<void> tocarNoBordo(WidgetTester tester, Finder alvo) async {
    final caixa = tester.getRect(alvo);
    await tester.tapAt(Offset(caixa.left + 2, caixa.center.dy));
    await tester.pumpAndSettle();
  }

  Future<void> montar(
    WidgetTester tester,
    Widget ecra, {
    Size tamanho = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ecra));
    await tester.pumpAndSettle();
  }

  group('1 · BoasVindasScreen', () {
    testWidgets('"Entrar na Punho" dispara ao toque no bordo', (tester) async {
      var entrou = 0;
      await montar(
        tester,
        BoasVindasScreen(aoEntrar: () => entrou++),
        tamanho: const Size(480, 960),
      );

      await tocarNoBordo(tester, find.widgetWithText(FilledButton, 'Entrar na Punho →'));

      expect(entrou, 1);
    });
  });

  group('2 · MaisDadosScreen', () {
    testWidgets('"Continuar" dispara ao toque no bordo', (tester) async {
      var avancou = 0;
      await montar(
        tester,
        MaisDadosScreen(aoAvancar: () => avancou++),
        tamanho: const Size(480, 960),
      );

      await tocarNoBordo(tester, find.widgetWithText(FilledButton, 'Continuar →'));

      expect(avancou, 1);
    });
  });

  group('3 · Passos do onboarding', () {
    testWidgets('"Continuar" avança ao toque no bordo', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento().copyWith(onboarded: false)),
        const OnboardingPage(),
        tamanho: const Size(520, 1000),
      );
      expect(find.text('1 de 12'), findsOneWidget);

      await tocarNoBordo(tester, find.widgetWithText(FilledButton, 'Continuar'));

      expect(find.text('2 de 12'), findsOneWidget);
    });
  });

  group('4 · DialogoDeFormulario', () {
    testWidgets('Cancelar e Guardar disparam ao toque no bordo', (tester) async {
      var guardou = 0;
      await montar(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DialogoDeFormulario(
                    titulo: 'Teste',
                    corpo: const Text('corpo'),
                    aoGuardar: () => guardou++,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tocarNoBordo(tester, find.widgetWithText(FilledButton, 'Guardar'));
      expect(guardou, 1);

      await tocarNoBordo(tester, find.widgetWithText(TextButton, 'Cancelar'));
      expect(find.byType(DialogoDeFormulario), findsNothing);
    });
  });

  group('5 · Cards de acção do painel', () {
    testWidgets('a navegação por nome de slide dispara no bordo', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      await tocarNoBordo(tester, find.widgetWithText(TextButton, 'Pipeline'));

      expect(find.text('Pipeline e compromissos'), findsOneWidget);
    });
  });

  group('6 · Chip de estado da máquina', () {
    testWidgets('abre o menu ao toque no bordo do chip', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const MachinesPage(),
        tamanho: const Size(1280, 900),
      );

      // O chip vive dentro de um PopupMenuButton: o alvo é o chip desenhado.
      await tocarNoBordo(tester, find.byType(Chip).first);

      expect(find.text('Em manutenção'), findsWidgets);
    });
  });

  group('7 · Botão "Cobrar" do slide 1', () {
    testWidgets('o alvo cobre o desenho inteiro', (tester) async {
      // Aqui a asserção é geométrica e não de comportamento: o que interessa é
      // que o `InkWell` do botão não seja menor do que a caixa pintada. Tocar e
      // verificar que "não lançou excepção" não provava nada — um toque que
      // falha também não lança.
      await montarLandscape(
        tester,
        containerCom(estadoComDividaAntiga()),
        DashboardPage(agora: agoraFixa),
      );

      final botao = find.widgetWithText(FilledButton, 'Cobrar →').first;
      final desenho = tester.getRect(botao);
      final alvo = tester.getRect(
        find.descendant(of: botao, matching: find.byType(InkWell)).first,
      );

      expect(alvo.left, lessThanOrEqualTo(desenho.left));
      expect(alvo.top, lessThanOrEqualTo(desenho.top));
      expect(alvo.right, greaterThanOrEqualTo(desenho.right));
      expect(alvo.bottom, greaterThanOrEqualTo(desenho.bottom));
    });
  });

  group('Alvos maiores do que o desenho ficam como estão', () {
    testWidgets('os pontos do carrossel têm alvo generoso de propósito', (
      tester,
    ) async {
      // A regra existe para impedir alvos **menores** do que o desenho. Um
      // ponto de 8 dp com alvo de 8 dp seria impossível de acertar num tablet;
      // os 4 dp de `Padding` em volta são deliberados e não se corrigem.
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      final ponto = find
          .descendant(
            of: find.byType(InkWell),
            matching: find.byType(Container),
          )
          .first;
      final desenho = tester.getRect(ponto);
      final alvo = tester.getRect(
        find.ancestor(of: ponto, matching: find.byType(InkWell)).first,
      );

      expect(desenho.height, 8, reason: 'o ponto desenhado tem 8 dp');
      expect(
        alvo.height,
        greaterThan(desenho.height),
        reason: 'o alvo é maior de propósito, para se poder acertar',
      );
    });
  });
}
