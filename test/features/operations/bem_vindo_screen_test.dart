import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/operations/presentation/bem_vindo_screen.dart';
import 'package:punho/shared/widgets/simbolo_punho.dart';

/// **Quem recebe é a marca, e a marca é a nossa.**
///
/// «a mão no primeiro bem-vindo não é a original, e quero que seja» — Cesar,
/// 5/8/2026. O ecrã abria com `Icons.back_hand_outlined`, a mão genérica do
/// Material — uma palma aberta, que nem punho é. No primeiro ecrã que a pessoa
/// vê da app, o símbolo tem de ser o do ficheiro da marca.
void main() {
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BemVindoScreen(nome: 'Alfredo', aoAvancar: () {})),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('recebe com a mão da marca, não com a do Material', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byType(SimboloPunho), findsOneWidget);
    expect(find.byIcon(Icons.back_hand_outlined), findsNothing);
  });

  testWidgets('o símbolo é o ficheiro da marca', (tester) async {
    await abrir(tester);

    final imagem = tester.widget<Image>(
      find.descendant(
        of: find.byType(SimboloPunho),
        matching: find.byType(Image),
      ),
    );
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/brand/punho_elo_operacao_v010.png',
    );
  });

  testWidgets('cumprimenta pelo nome de quem entra', (tester) async {
    await abrir(tester);

    expect(find.text('Bem-vindo, Alfredo.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Vamos a isto'), findsOneWidget);
  });
}
