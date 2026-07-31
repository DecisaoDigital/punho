import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:punho/core/cadeado/lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os pontos do PIN não podem prometer um comprimento que a app não conhece.
///
/// O Cesar tinha um PIN de 4 dígitos e o ecrã mostrava 6 círculos: parecia que
/// faltavam dois. Só percebeu que estava completo por carregar em Desbloquear
/// à mesma.
void main() {
  setUp(() {
    // Sem biometria disponível (não há plataforma nos testes), o ecrã cai
    // directo no teclado do PIN — que é o que aqui interessa.
    SharedPreferences.setMockInitialValues({'cadeado.biometria': false});
    // O disparo automático da digital é estático de propósito (o ecrã remonta
    // muito). Entre testes tem de ser rearmado, como o gate faz ao bloquear.
    LockScreen.rearmar();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LockScreen())),
    );
    await tester.pumpAndSettle();
  }

  int pontos(WidgetTester tester) =>
      tester.widgetList(find.byType(AnimatedContainer)).length;

  testWidgets('em branco mostra o mínimo, não o máximo', (tester) async {
    await montar(tester);

    expect(pontos(tester), 4);
  });

  testWidgets('cresce a partir do quinto dígito', (tester) async {
    await montar(tester);

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(pontos(tester), 4, reason: 'quatro dígitos cabem no mínimo');

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(pontos(tester), 5);
  });

  testWidgets('nunca passa dos seis', (tester) async {
    await montar(tester);

    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }

    expect(pontos(tester), 6);
  });
}
