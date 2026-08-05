import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/margens_do_canvas.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../../tipos_de_letra.dart';
import '../dashboard/fixtura.dart';

/// O alinhamento da barra das Reservas, com tipos de letra a sério.
///
/// Este ficheiro existe por causa de um defeito que a suite deixou passar. O
/// campo da máquina estava num `Flexible`, que reparte o espaço livre tal como
/// o `Expanded` da data ao lado: com flex igual, o `Row` reservava metade para
/// cada um, o campo usava só o que o texto pedia, e os 85 dp que sobravam da
/// sua quota ficavam mortos — o "+ Reservar" acabava a 100 dp da margem em vez
/// de encostar a ela.
///
/// Os testes de widget não carregam tipos de letra: cada glifo sai como um
/// quadrado, mais largo do que a letra verdadeira. O texto enchia a quota do
/// `Flexible`, não sobrava nada, e o defeito não aparecia. Só se viu numa
/// captura do telemóvel do Cesar.
///
/// Daí [carregarTiposDeLetra] aqui: sem ele, este ficheiro passa a verde com o
/// defeito lá dentro, que é exactamente o que aconteceu.
void main() {
  setUpAll(carregarTiposDeLetra);

  /// Redmi Note 10 Pro deitado: barra de estado em cima, barra de navegação à
  /// direita — a margem que a moldura da shell gasta antes de entregar o canvas.
  const redmiDeitado = Size(838.9, 392.7);
  const margens = FakeViewPadding(top: 33.8, right: 47.3);

  Future<Rect> abrirReservas(
    WidgetTester tester,
    OperationsState estado,
  ) async {
    tester.view.physicalSize = redmiDeitado;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = margens;
    tester.view.viewPadding = margens;
    addTearDown(tester.view.reset);

    final container = containerCom(estado);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: PunhoTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    container.read(navigationProvider.notifier).goTo(AppDestination.bookings);
    await tester.pumpAndSettle();
    return tester.getRect(find.byType(BookingsPage));
  }

  testWidgets('o "+ Reservar" encosta à margem direita do canvas', (
    tester,
  ) async {
    // Sem máquinas é o caso que destapou o defeito: o campo mostra uma frase
    // curta e larga a maior parte da quota que o `Flexible` lhe reservava.
    final canvas = await abrirReservas(tester, estadoSemMovimento());
    final botao = tester.getRect(find.widgetWithText(FilledButton, 'Reservar'));

    expect(
      canvas.right - botao.right,
      moreOrLessEquals(MargensDoCanvas.lateral, epsilon: 0.5),
      reason: 'o botão não está encostado à margem: sobra espaço à direita',
    );
  });

  testWidgets('e continua encostado com máquinas na lista', (tester) async {
    // Com máquinas o campo é um dropdown, com outra largura. A margem é a
    // mesma — se dependesse do conteúdo do campo, não era uma margem.
    final canvas = await abrirReservas(tester, estadoComMovimento());
    final botao = tester.getRect(find.widgetWithText(FilledButton, 'Reservar'));

    expect(
      canvas.right - botao.right,
      moreOrLessEquals(MargensDoCanvas.lateral, epsilon: 0.5),
    );
  });

  testWidgets('os rótulos das metades do dia ficam a 25 dp da margem', (
    tester,
  ) async {
    // 15 da margem do canvas mais 10 pedidos de propósito: são rótulos de
    // linha, não o começo de um ecrã.
    final canvas = await abrirReservas(tester, estadoComMovimento());

    for (final rotulo in ['Manhã', 'Tarde']) {
      expect(
        tester.getRect(find.text(rotulo)).left - canvas.left,
        moreOrLessEquals(MargensDoCanvas.lateral + 10, epsilon: 0.5),
        reason: '"$rotulo" fora da coluna',
      );
    }
  });

  testWidgets('a linha do topo cabe sem partir nem transbordar', (
    tester,
  ) async {
    await abrirReservas(tester, estadoComMovimento());

    // Um `Wrap` partia o botão para uma segunda linha e ninguém dava por isso:
    // o ecrã continuava a montar sem erro. Aqui a altura denuncia-o.
    final botao = tester.getRect(find.widgetWithText(FilledButton, 'Reservar'));
    final maquina = tester.getRect(find.byType(DropdownButton<String>));
    expect(
      botao.center.dy,
      moreOrLessEquals(maquina.center.dy, epsilon: 1),
      reason: 'o botão caiu para outra linha',
    );
    expect(tester.takeException(), isNull);
  });
}
