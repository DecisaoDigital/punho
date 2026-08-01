@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../../tipos_de_letra.dart';
import '../dashboard/fixtura.dart';

/// Diagnóstico da moldura de topo no telemóvel do Cesar, deitado.
///
/// O Redmi Note 10 Pro tem furo de câmara ao centro **do topo em pé** — ou seja
/// **de lado quando deitado**. Em landscape a margem superior que o sistema
/// reporta é só a barra de estado; o recorte aparece à esquerda ou à direita,
/// conforme o lado para que se roda. Estas capturas fixam as duas rotações para
/// se ver o que é faixa, o que é padding e o que é cabeçalho.
void main() {
  setUpAll(carregarTiposDeLetra);

  /// Redmi Note 10 Pro deitado, em unidades lógicas.
  const redmiDeitado = Size(873, 393);

  /// Barra de estado do Android em landscape: só ela, sem recorte.
  const barraDeEstado = 24.0;

  /// Furo da câmara, na aresta para que fica virado.
  const recorte = 34.0;

  Future<void> montar(
    WidgetTester tester, {
    required FakeViewPadding margens,
  }) async {
    tester.view.physicalSize = redmiDeitado;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = margens;
    tester.view.viewPadding = margens;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerCom(estadoComMovimento()),
        child: MaterialApp(theme: PunhoTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('camara a esquerda', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, left: recorte),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../docs/design/screenshots/diagnostico/moldura_camara_esquerda.png',
      ),
    );
  });

  testWidgets('camara a direita', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: recorte),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../docs/design/screenshots/diagnostico/moldura_camara_direita.png',
      ),
    );
  });
}
