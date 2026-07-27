import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// "Que raio de frase é aquela para quem vai entrar na empresa e estamos a
/// perguntar o nome?" — o sub-texto do passo 1 era o pitch do produto, não era
/// ajuda a preencher o campo.
void main() {
  Future<void> abrirOnboarding(WidgetTester tester) => montarLandscape(
    tester,
    containerCom(estadoSemMovimento().copyWith(onboarded: false)),
    const OnboardingPage(),
  );

  testWidgets('o passo 1 pergunta o nome e mais nada', (tester) async {
    await abrirOnboarding(tester);

    expect(find.text('Como te chamas?'), findsOneWidget);
    expect(
      find.text(
        'O Punho orienta a pessoa responsável por decidir e agir na empresa.',
      ),
      findsNothing,
    );
    expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
  });

  testWidgets('nenhum sub-texto visível é pitch do produto', (tester) async {
    // Heurística: apanha filosofia a fugir de volta para o fluxo. Percorre os
    // três primeiros passos, que são os que tinham pitch — e não os 12, porque
    // um passo mais à frente tem um overflow horizontal pré-existente que
    // rebentaria o teste por outra razão (registado no doc da v0.0.5).
    const proibidas = ['orienta', 'responsável por decidir', 'agir na empresa'];
    await abrirOnboarding(tester);

    for (var passo = 0; passo < 3; passo++) {
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      for (final texto in textos) {
        for (final proibida in proibidas) {
          expect(
            texto.toLowerCase(),
            isNot(contains(proibida.toLowerCase())),
            reason: 'passo ${passo + 1}: "$texto"',
          );
        }
      }
      final continuar = find.widgetWithText(FilledButton, 'Continuar');
      if (continuar.evaluate().isEmpty) break;
      await tester.tap(continuar);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('sem sub-texto o campo fica logo debaixo da pergunta', (
    tester,
  ) async {
    await abrirOnboarding(tester);

    final pergunta = tester.getBottomLeft(find.text('Como te chamas?')).dy;
    final campo = tester.getTopLeft(find.byType(TextField).first).dy;
    // 24 dp de respiração e nada mais: sem o colapso ficavam ~40.
    expect(campo - pergunta, lessThan(32));
  });
}
