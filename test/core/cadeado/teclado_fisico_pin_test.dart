// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:fist/core/cadeado/cadeado_service.dart';
import 'package:fist/core/cadeado/definicoes_cadeado_page.dart';
import 'package:fist/core/cadeado/lock_screen.dart';
import 'package:fist/shared/widgets/brand_lockup.dart';
import 'package:fist/shared/widgets/simbolo_punho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O PIN também se escreve no teclado do PC: linha de cima e bloco numérico.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'cadeado.biometria': false});
    FlutterSecureStorage.setMockInitialValues({});
    LockScreen.rearmar();
  });

  Future<ProviderContainer> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(cadeadoBloqueadoProvider.notifier).state = true;
    await c.read(cadeadoServiceProvider).guardarPin('1234');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: LockScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  int cheios(WidgetTester tester) => tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .where(
        (a) =>
            ((a.decoration as BoxDecoration).color ?? Colors.transparent) !=
            Colors.transparent,
      )
      .length;

  testWidgets('dígitos da linha de cima enchem os pontos', (tester) async {
    await montar(tester);
    for (final k in [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2]) {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }
    expect(cheios(tester), 2);
  });

  testWidgets('bloco numérico enche os pontos e Backspace apaga', (
    tester,
  ) async {
    await montar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
    await tester.pump();
    expect(cheios(tester), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(cheios(tester), 2);
  });

  testWidgets('1234 (linha de cima + numpad) e Enter desbloqueiam', (
    tester,
  ) async {
    final c = await montar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.pump();
    expect(c.read(cadeadoBloqueadoProvider), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(c.read(cadeadoBloqueadoProvider), isFalse);
  });

  testWidgets('Enter com menos de 4 dígitos não faz nada', (tester) async {
    final c = await montar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.read(cadeadoBloqueadoProvider), isTrue);
    expect(find.text('PIN errado.'), findsNothing);
  });

  testWidgets('letras são ignoradas', (tester) async {
    await montar(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(cheios(tester), 0);
  });

  testWidgets('definir PIN: Enter no segundo campo guarda', (tester) async {
    String? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async =>
                resultado = await Navigator.of(ctx).push<String>(
                  MaterialPageRoute(builder: (_) => const DefinirPinScreen()),
                ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), '4321');
    await tester.enterText(campos.at(1), '4321');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(resultado, '4321');
  });

  testWidgets('lockup de entrada é 2,25x no Windows e igual no resto', (
    tester,
  ) async {
    Future<double> lado(bool win) async {
      BrandLockup.forcarWindows = win;
      addTearDown(() => BrandLockup.forcarWindows = null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandLockup(key: UniqueKey(), entrada: true, grande: true),
          ),
        ),
      );
      return tester.getSize(find.byType(SimboloFist)).width;
    }

    final normal = await lado(false);
    final win = await lado(true);
    expect(win / normal, closeTo(2.25, 0.01));
  });
}
