import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/margens_do_canvas.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../dashboard/fixtura.dart';

/// A faixa escura do topo, medida.
///
/// Três defeitos reais viveram aqui, e nenhum se via numa captura:
///  1. a faixa saía com **largura zero** — `SizedBox(height:)` num `Column` que
///     centra dá restrições soltas, e um `ColoredBox` sem filho não tem largura.
///     Comia 18 dp de altura e não pintava um pixel;
///  2. a altura descontava 6 dp com um tecto de 20, números inventados para
///     aparar um recorte de câmara que em landscape nem sequer está no topo;
///  3. nada disto chegava a correr, porque a app não desenhava por baixo das
///     barras e `MediaQuery.padding.top` vinha a zero.
///
/// Estes testes olham para a geometria. É a única forma de os apanhar.
void main() {
  const redmiDeitado = Size(873, 393);

  /// Barra de estado do Redmi Note 10 Pro deitado, medida no telemóvel.
  const barraDeEstado = 33.8;

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

  /// A faixa é o `ColoredBox` navy que está encostado ao topo. A barra lateral
  /// usa a mesma cor, por isso distingue-se pela posição.
  Rect faixaDoTopo(WidgetTester tester) {
    for (final elemento in find.byType(ColoredBox).evaluate()) {
      final widget = elemento.widget as ColoredBox;
      if (widget.color != PunhoTheme.navyDeep) continue;
      final caixa = elemento.renderObject! as RenderBox;
      final canto = caixa.localToGlobal(Offset.zero);
      if (canto.dy == 0) return canto & caixa.size;
    }
    fail('não há faixa navy encostada ao topo');
  }

  testWidgets('a faixa atravessa o ecrã todo', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, left: recorte),
    );

    expect(
      faixaDoTopo(tester).width,
      redmiDeitado.width,
      reason: 'faixa com largura parcial: não cobre a barra de estado',
    );
  });

  testWidgets('a faixa pára onde os glifos param', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, left: recorte),
    );

    // 27 dp: o fim dos glifos mais 5,2 dp de ar por baixo, cerca de metade da
    // folga que têm em cima. Os 6,8 dp que sobram da barra do sistema passam
    // para o conteúdo.
    expect(faixaDoTopo(tester).height, 27.0);
  });

  testWidgets('numa barra mais baixa a faixa acompanha-a', (tester) async {
    // Quanto mais alta a faixa, mais fácil é passar da margem que o sistema
    // reporta — e uma faixa maior do que a barra é navy a invadir o conteúdo.
    await montar(
      tester,
      margens: const FakeViewPadding(top: 18, left: recorte),
    );

    expect(faixaDoTopo(tester).height, 18.0);
  });

  testWidgets('a barra lateral mantém 88 dp úteis com o furo à esquerda', (
    tester,
  ) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, left: recorte),
    );

    // A largura total cresce com o recorte para o conteúdo continuar a ter os
    // 88 dp por que foi desenhado. Sem isto ficavam 54 e os rótulos apertavam.
    expect(tester.getSize(find.byKey(chaveDaBarraLateral)).width, 88 + recorte);
  });

  testWidgets('a barra de navegação não encolhe a barra lateral', (
    tester,
  ) async {
    // Em edge-to-edge, a barra de navegação do sistema — que em landscape fica
    // à direita — passa a ser reportada como margem. Foi assim que os rótulos
    // ficaram em "P…" e "Cli…": o `SafeArea` da barra lateral descontava 47 dp
    // de uma barra que está do outro lado do ecrã.
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    final barra = find.byKey(chaveDaBarraLateral);
    expect(tester.getSize(barra).width, 88);
    // E o que lá vai dentro tem os 88 dp inteiros.
    final coluna = find.descendant(of: barra, matching: find.byType(Column));
    expect(tester.getSize(coluna.first).width, 88);
  });

  testWidgets('o canvas não desconta as margens uma segunda vez', (
    tester,
  ) async {
    // A moldura já gastou as margens do sistema. Se as deixasse no MediaQuery,
    // o `SafeArea` de cada página descontava-as outra vez — e os 47,3 dp da
    // barra de navegação saíam duas vezes, com o painel encostado à esquerda e
    // uma tira branca à direita a não fazer nada.
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    final canvas = tester.element(find.byType(DashboardPage));
    expect(MediaQuery.paddingOf(canvas), EdgeInsets.zero);
  });

  testWidgets('o painel estica até à aresta do canvas', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    // Largura da janela menos a barra lateral e menos a barra de navegação:
    // é isto que o painel tem de ocupar, e não menos.
    final canvasEsperado = redmiDeitado.width - 88 - 47;
    expect(tester.getSize(find.byType(DashboardPage)).width, canvasEsperado);
  });

  testWidgets('as setas do carrossel não ficam coladas às arestas', (
    tester,
  ) async {
    // Esticar o painel até à aresta do canvas não pode significar setas coladas
    // à barra lateral de um lado e à barra de navegação do outro: são alvos de
    // toque, e um alvo encostado à aresta é um alvo que se falha.
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    final canvas = tester.getRect(find.byType(DashboardPage));
    final esquerda = tester.getRect(find.byIcon(Icons.chevron_left));
    final direita = tester.getRect(find.byIcon(Icons.chevron_right));

    // 15 dp de cada lado. Esteve em 14 e 18 — a esquerda menor porque a barra
    // lateral navy já separa por si — mas ao olho lia-se como desalinhamento.
    expect(esquerda.left - canvas.left, 15);
    expect(canvas.right - direita.right, 15);
  });

  testWidgets('a saudação não flutua longe da faixa', (tester) async {
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    final canvas = tester.getRect(find.byType(DashboardPage));
    final saudacao = tester.getRect(find.textContaining('·').first);

    // A margem do canvas, e nada mais.
    //
    // Esteve em 15,5 dp que ninguém controlava: o `Row` centrava a saudação
    // contra o botão de editar, e era a altura do botão (48 dp de alvo de
    // toque) que a decidia. Esse botão vai sair do ecrã; a medida não podia
    // ficar dependente dele. Segue a constante em vez de repetir o número,
    // senão mudar a margem obrigava a vir aqui corrigir à mão.
    expect(saudacao.top - canvas.top, MargensDoCanvas.vertical);
  });

  testWidgets('todos os destinos partilham o mesmo canvas', (tester) async {
    // O canvas é da moldura, não das páginas: quem mudar uma página não pode
    // sair com um canvas diferente do dos outros destinos.
    await montar(
      tester,
      margens: const FakeViewPadding(top: barraDeEstado, right: 47),
    );

    final esperado = tester.getRect(find.byType(DashboardPage));
    for (final destino in AppDestination.values) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      container.read(navigationProvider.notifier).goTo(destino);
      await tester.pumpAndSettle();

      final pagina = find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(Scaffold),
      );
      if (pagina.evaluate().length < 2) continue;
      expect(
        tester.getRect(pagina.at(1)),
        esperado,
        reason: 'o destino ${destino.name} tem canvas próprio',
      );
    }
  });

  testWidgets('sem margens do sistema não há faixa nenhuma', (tester) async {
    await montar(tester, margens: const FakeViewPadding());

    // Num tablet sem recortes a moldura não tem razão de existir, e não deve
    // roubar altura ao conteúdo. A barra lateral fica encostada ao topo e é
    // navy também — o que não pode existir é navy a atravessar o ecrã todo.
    for (final elemento in find.byType(ColoredBox).evaluate()) {
      final widget = elemento.widget as ColoredBox;
      if (widget.color != PunhoTheme.navyDeep) continue;
      final caixa = elemento.renderObject! as RenderBox;
      if (caixa.localToGlobal(Offset.zero).dy != 0) continue;
      expect(caixa.size.width, lessThan(redmiDeitado.width));
    }
  });
}
