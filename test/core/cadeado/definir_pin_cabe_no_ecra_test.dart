import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/cadeado/definicoes_cadeado_page.dart';

/// **Definir um PIN tem de caber no ecrã com o teclado aberto.**
///
/// A 13/8/2026 o César disse «o pin também não está a funcionar». Não era o
/// PIN: era o ecrã que o pede. O primeiro campo tem `autofocus`, portanto o
/// teclado abre **sozinho** ao entrar — e no Redmi deitado o teclado come 200
/// dos 393 dp de altura. O que fica são 145 dp para 264 dp de conteúdo: o
/// campo de repetir e o botão «Guardar» ficam fora do ecrã, sem nada para
/// rolar até lá. Ou seja, deitado o cadeado não se conseguia activar de todo.
///
/// Passou-me ao lado na noite anterior porque eu conduzi a app por `adb`: para
/// chegar ao segundo campo carreguei em "voltar atrás" para esconder o teclado,
/// uma manobra que ninguém faz com o dedo — e escrevi isso como uma esquisitice
/// do `uiautomator` em vez de a ler pelo que era.
///
/// Estas medidas são as do aparelho dele: 2177x1080 físicos a 2.75.
void main() {
  const dpr = 2.75;
  const ecraDeitado = Size(2177, 1080);
  const ecraDePe = Size(1080, 2400);
  const tecladoDp = 200.0;

  /// Monta o ecrã com o teclado aberto, como ele aparece de verdade — o campo
  /// tem `autofocus`, o teclado não é opcional.
  Future<void> comTeclado(WidgetTester tester, Size ecra) async {
    tester.view.physicalSize = ecra;
    tester.view.devicePixelRatio = dpr;
    tester.view.viewInsets = const FakeViewPadding(bottom: tecladoDp * dpr);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: DefinirPinScreen()),
    );
    await tester.pump();
  }

  /// A altura que sobra depois de o teclado tomar o que é dele.
  double alturaVisivel(Size ecra) => ecra.height / dpr - tecladoDp;

  testWidgets('deitado, o botão Guardar fica dentro do ecrã', (tester) async {
    await comTeclado(tester, ecraDeitado);

    expect(
      tester.takeException(),
      isNull,
      reason: 'o ecrã transbordou antes mesmo de se medir o botão',
    );

    final guardar = tester.getRect(find.widgetWithText(FilledButton, 'Guardar'));
    expect(
      guardar.bottom,
      lessThanOrEqualTo(alturaVisivel(ecraDeitado)),
      reason:
          'o «Guardar» acaba a ${guardar.bottom.toStringAsFixed(0)} dp e só há '
          '${alturaVisivel(ecraDeitado).toStringAsFixed(0)} acima do teclado — '
          'sem isto não há forma de activar o cadeado deitado',
    );
    expect(
      guardar.height,
      greaterThanOrEqualTo(48),
      reason: 'o botão que fecha o ecrã não pode ser mais pequeno que um dedo',
    );
  });

  testWidgets('deitado, o campo de repetir o PIN também', (tester) async {
    await comTeclado(tester, ecraDeitado);
    expect(tester.takeException(), isNull);

    final repetir = tester.getRect(find.widgetWithText(TextField, 'Repetir PIN'));
    expect(
      repetir.bottom,
      lessThanOrEqualTo(alturaVisivel(ecraDeitado)),
      reason: 'não se confirma um PIN que não se vê',
    );
  });

  testWidgets('e escreve-se o PIN duas vezes até ao fim', (tester) async {
    await comTeclado(tester, ecraDeitado);

    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
    await tester.enterText(
      find.widgetWithText(TextField, 'Repetir PIN'),
      '4321',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // O ecrã fecha-se devolvendo o PIN: é o sinal de que a validação passou.
    expect(find.byType(DefinirPinScreen), findsNothing);
  });

  testWidgets('dois PINs diferentes continuam a ser recusados', (tester) async {
    await comTeclado(tester, ecraDeitado);

    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
    await tester.enterText(
      find.widgetWithText(TextField, 'Repetir PIN'),
      '1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();

    expect(find.text('Os PINs não coincidem.'), findsOneWidget);
  });

  // Controlo: de pé sempre coube. Se esta régua deixar de saber apanhar um
  // ecrã que não cabe, o teste de cima passa a passar por engano.
  testWidgets('de pé cabia — e continua a caber', (tester) async {
    await comTeclado(tester, ecraDePe);
    expect(tester.takeException(), isNull);

    final guardar = tester.getRect(find.widgetWithText(FilledButton, 'Guardar'));
    expect(guardar.bottom, lessThanOrEqualTo(alturaVisivel(ecraDePe)));
  });
}
