import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/margens_do_canvas.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/core/operations/painel_controller.dart';
import 'package:punho/features/dashboard/presentation/widgets/dots_indicator.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../dashboard/fixtura.dart';

/// A distância da primeira letra de cada menu ao topo do canvas.
///
/// É a medida que o olho faz ao mudar de menu, e a que estava toda diferente:
/// 11,5 nas Reservas, 12 no painel, 17,5 nos Clientes, 20 nas Tarefas, 20,5 nas
/// Máquinas, 24 nos Colaboradores, 28,5 na Empresa. Cada ecrã com o seu número,
/// escrito num ficheiro diferente, e nenhum sítio onde os corrigir a todos.
///
/// Este teste não fixa um valor — fixa que os ecrãs do mesmo tipo dão o mesmo
/// resultado. Mudar [MargensDoCanvas.vertical] move-os a todos e o teste
/// continua verde; mudar um só ficheiro é que o parte.
void main() {
  const redmiDeitado = Size(838.9, 392.7);
  const topoDoCanvas = 27.0;

  /// Distância do topo do canvas à primeira letra visível, seja ela texto solto
  /// ou o rótulo de um botão — é o rótulo que o olho vê, não a caixa à volta.
  double primeiraLetra(WidgetTester tester) {
    var maisAcima = double.infinity;
    for (final e in find.byType(Text).evaluate()) {
      final caixa = e.renderObject;
      if (caixa is! RenderBox || !caixa.hasSize) continue;
      final canto = caixa.localToGlobal(Offset.zero);
      if (canto.dx < 88) continue; // barra lateral
      if (canto.dy < topoDoCanvas) continue;
      if (canto.dy < maisAcima) maisAcima = canto.dy;
    }
    return maisAcima - topoDoCanvas;
  }

  Future<ProviderContainer> abrir(WidgetTester tester) async {
    tester.view.physicalSize = redmiDeitado;
    tester.view.devicePixelRatio = 1.0;
    const margens = FakeViewPadding(top: 33.8, right: 47.3);
    tester.view.padding = margens;
    tester.view.viewPadding = margens;
    addTearDown(tester.view.reset);

    final container = containerCom(estadoComMovimento());
    // O painel nasce vazio, e o carrossel — setas, rodapé, nomes — só existe
    // quando lá está alguma coisa. Cinco KPIs dão duas páginas, que é o mínimo
    // para o rodapé ter nome de cada lado.
    final painel = container.read(painelProvider.notifier);
    for (final id in kpisNoPainelParaMedir) {
      painel.alternar(id, escolher: true);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: PunhoTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('os menus que começam por texto medem todos o mesmo', (
    tester,
  ) async {
    final container = await abrir(tester);
    // O painel começa pela saudação, os Colaboradores por "Funcionários", as
    // Tarefas pela contagem de pendentes. Texto nu, sem nada à volta.
    const porTexto = [
      AppDestination.management,
      AppDestination.employees,
      AppDestination.tasks,
    ];

    for (final destino in porTexto) {
      container.read(navigationProvider.notifier).goTo(destino);
      await tester.pumpAndSettle();
      expect(
        primeiraLetra(tester),
        MargensDoCanvas.vertical,
        reason: '${destino.name} não segue a margem vertical',
      );
    }
  });

  testWidgets('o que se vê fica a [lateral] da barra, com seta ou sem ela', (
    tester,
  ) async {
    final container = await abrir(tester);

    /// A coisa mais à esquerda que o olho apanha dentro do canvas: uma letra,
    /// ou o glifo de uma seta.
    double primeiroPixel(WidgetTester tester) {
      var maisAEsquerda = double.infinity;
      for (final f in [find.byType(Text), find.byType(Icon)]) {
        for (final e in f.evaluate()) {
          final caixa = e.renderObject;
          if (caixa is! RenderBox || !caixa.hasSize) continue;
          final canto = caixa.localToGlobal(Offset.zero);
          if (canto.dx < 88) continue; // barra lateral
          if (canto.dx < maisAEsquerda) maisAEsquerda = canto.dx;
        }
      }
      return maisAEsquerda - 88;
    }

    // O painel começa por uma seta de carrossel, os outros por texto. A seta
    // traz 8 dp por dentro e por isso o painel escreve 7 no padding — para os
    // dois darem o mesmo ao olho.
    for (final destino in [
      AppDestination.management,
      AppDestination.employees,
      AppDestination.tasks,
      AppDestination.clients,
    ]) {
      container.read(navigationProvider.notifier).goTo(destino);
      await tester.pumpAndSettle();
      expect(
        primeiroPixel(tester),
        MargensDoCanvas.lateral,
        reason: '${destino.name} não encosta à margem lateral',
      );
    }
  });

  testWidgets('os menus que começam por botão medem todos o mesmo', (
    tester,
  ) async {
    final container = await abrir(tester);
    const porBotao = [AppDestination.machines, AppDestination.clients];

    final medidas = <AppDestination, double>{};
    for (final destino in porBotao) {
      container.read(navigationProvider.notifier).goTo(destino);
      await tester.pumpAndSettle();
      medidas[destino] = primeiraLetra(tester);
    }

    // A margem é a mesma nos dois — o que não é igual é o ar que cada botão
    // põe entre ela e o rótulo, porque os rótulos não têm o mesmo tamanho de
    // letra: "Adicionar máquina" ocupa uma linha de 14 dp, "Novo cliente" uma
    // de 20. Dá 3 dp de diferença entre dois ecrãs que deviam ler-se iguais.
    //
    // Fica registado como está, e não escondido atrás de uma tolerância: é uma
    // decisão de desenho por tomar — ou os botões passam a ter o mesmo estilo,
    // ou aceita-se que estes dois menus não alinham ao pixel.
    expect(medidas[AppDestination.machines], 21.5);
    expect(medidas[AppDestination.clients], 18.5);
    // Os dois acima da margem: é o ar do botão a somar-se a ela.
    for (final medida in medidas.values) {
      expect(medida, greaterThan(MargensDoCanvas.verticalComBotaoNoTopo));
    }
  });

  testWidgets('a saudação do painel fica centrada, por escolha', (
    tester,
  ) async {
    await abrir(tester);

    // Ficou centrada por acidente, quando o botão de editar saiu do ecrã e
    // levou com ele o `Expanded` que a encostava à esquerda. Chegou a ser
    // "corrigida" para a margem, mas o Cesar viu o resultado e preferiu-o
    // assim. Fica registado como decisão, para a próxima limpeza não a
    // arrastar de volta para os 15 dp achando que é um defeito.
    final canvas = tester.getRect(find.byType(DashboardPage));
    final saudacao = tester.getRect(find.textContaining('·').first);

    expect(
      saudacao.center.dx,
      moreOrLessEquals(canvas.center.dx, epsilon: 1),
      reason: 'a saudação saiu do centro do canvas',
    );
  });

  testWidgets('o rodapé do painel encosta às duas margens', (tester) async {
    await abrir(tester);

    // O último nome de ecrã ficava a 64,8 dp da margem direita: a caixa dos
    // três nomes tinha 300 dp fixos e vinha centrada no espaço que sobrava, em
    // vez de o ocupar. Do lado esquerdo o "1/2 · …" encostava certo — os dois
    // extremos do rodapé não batiam um com o outro.
    //
    // Procura-se dentro do rodapé, e não no ecrã todo: os nomes dos ecrãs são
    // títulos de KPIs, e os mesmos títulos estão nas células do painel.
    final canvas = tester.getRect(find.byType(DashboardPage));
    final rodape = find.byType(DotsIndicator);
    final contador = tester.getRect(
      find.descendant(of: rodape, matching: find.textContaining('1/2')).first,
    );
    final ultimoNome = tester.getRect(
      find.descendant(of: rodape, matching: find.text(nomeDoSegundoEcra)),
    );

    expect(
      contador.left - canvas.left,
      moreOrLessEquals(MargensDoCanvas.lateral, epsilon: 0.01),
    );
    expect(
      canvas.right - ultimoNome.right,
      moreOrLessEquals(MargensDoCanvas.lateral, epsilon: 0.01),
    );
  });
}
