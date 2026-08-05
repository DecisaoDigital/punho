import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/presentation/login_screen.dart';
import 'package:punho/shared/widgets/brand_lockup.dart';

/// **O login não encosta ao topo com o teclado aberto.**
///
/// O campo do email tem `autofocus`, portanto o teclado sobe sozinho: é o
/// estado normal deste ecrã, não um caso de canto.
///
/// O `Scaffold` já encolhe o corpo pela altura do teclado
/// (`resizeToAvoidBottomInset`, ligado por omissão). O ecrã somava-lhe **outra
/// vez** `viewInsets.bottom` como padding dentro do `SingleChildScrollView` —
/// e um conteúdo mais alto do que a área visível põe o scroll no topo, o que
/// anula o `Center` que está por cima. O resultado é o texto colado à barra de
/// estado.
void main() {
  /// Redmi Note 10 Pro em retrato: 1080 × 2177 px a 2,75 → 392,7 × 791,6 dp.
  const janela = Size(392.7, 791.6);

  Future<void> montar(WidgetTester tester, {required double teclado}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = janela;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            // O que o Android reporta com o teclado em cima.
            data: MediaQueryData(
              size: janela,
              viewInsets: EdgeInsets.only(bottom: teclado),
              padding: const EdgeInsets.only(top: 33.8),
            ),
            child: LoginScreen(aoCriarConta: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('com o teclado fechado o conteúdo fica centrado', (tester) async {
    await montar(tester, teclado: 0);

    final topo = tester.getTopLeft(find.byType(BrandLockup)).dy;
    final fundo = tester.getBottomLeft(find.byType(BrandLockup)).dy;

    expect(topo, greaterThan(40), reason: 'não pode colar à barra de estado');
    expect(fundo, lessThan(janela.height));
  });

  testWidgets('com o teclado aberto continua a não colar ao topo', (
    tester,
  ) async {
    // 250 dp é um teclado normal em retrato neste aparelho.
    await montar(tester, teclado: 250);

    final topo = tester.getTopLeft(find.byType(BrandLockup)).dy;

    // A marca tem 24 dp de padding por dentro do scroll. Encostada ao topo,
    // apareceria a 24 + a barra de estado. Qualquer coisa acima disso quer
    // dizer que o `Center` ainda está a mandar.
    expect(
      topo,
      greaterThan(24 + 33.8 + 1),
      reason: 'o conteúdo está encostado ao topo — o Center foi anulado',
    );
  });

  testWidgets('nada transborda com o teclado aberto', (tester) async {
    await montar(tester, teclado: 250);

    expect(tester.takeException(), isNull);
  });
}
