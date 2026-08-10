import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/core/operations/painel_controller.dart';
import 'package:punho/features/kpis/presentation/kpis_page.dart';

import '../dashboard/fixtura.dart';

/// **A bancada é onde o painel se monta.**
///
/// Marca-se à esquerda, arrasta-se pela pega à direita, e no meio fica a
/// célula verdadeira — escolhe-se o KPI a olhar para o que ele vai mostrar, e
/// não para o nome dele numa lista.
///
/// A regra que estes testes guardam é uma só: **só os prontos se marcam**.
/// Deixar promover um que ainda não passou pelo nosso crivo era pôr no painel
/// um número que nós próprios não assinamos.
void main() {
  final estado = estadoComMovimento();
  final prontos = [
    for (final k in catalogoKpis)
      if (k.estado(estado, agoraFixa) == EstadoVerdade.pronto) k,
  ];
  final naoProntos = [
    for (final k in catalogoKpis)
      if (k.estado(estado, agoraFixa) != EstadoVerdade.pronto) k,
  ];

  test('a fixtura ainda dá matéria para estes testes', () {
    // Se um dia os dados de teste mudarem e deixarem de haver prontos — ou
    // deixarem de haver não-prontos —, os testes abaixo passavam a não provar
    // nada e ninguém dava por isso.
    expect(prontos.length, greaterThanOrEqualTo(2));
    expect(naoProntos, isNotEmpty);
  });

  group('só os prontos se marcam', () {
    testWidgets('todos os prontos têm caixa, e mais ninguém', (tester) async {
      final container = containerCom(estado);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      final rotulos = await _rotulosDasCaixas(tester);

      expect(
        rotulos,
        containsAll([for (final k in prontos) '${k.titulo} no painel']),
      );
      for (final k in naoProntos) {
        expect(
          rotulos,
          isNot(contains('${k.titulo} no painel')),
          reason: '${k.titulo} ainda não passou pelo crivo',
        );
      }
    });

    testWidgets('a pega de arrastar é só dos prontos', (tester) async {
      final container = containerCom(estado);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      // Os prontos vêm primeiro na página.
      expect(find.byIcon(Icons.drag_indicator), findsWidgets);

      await _atePaginaAbaixo(tester);
      expect(
        find.byIcon(Icons.drag_indicator),
        findsNothing,
        reason: 'os grupos de baixo não se ordenam — não estão no painel',
      );
    });
  });

  group('marcar', () {
    testWidgets('a caixa marcada põe o KPI no painel', (tester) async {
      final container = containerCom(estado);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      expect(container.read(painelProvider).noPainel, isEmpty);

      await tester.tap(_caixaDe(prontos.first));
      await tester.pumpAndSettle();

      expect(container.read(painelProvider).noPainel, [prontos.first.id]);
    });

    testWidgets('desmarcar tira-o de lá', (tester) async {
      final container = containerCom(estado);
      container
          .read(painelProvider.notifier)
          .alternar(prontos.first.id, escolher: true);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      await tester.tap(_caixaDe(prontos.first));
      await tester.pumpAndSettle();

      expect(container.read(painelProvider).noPainel, isEmpty);
    });

    testWidgets('um KPI que caiu do painel continua a poder sair dele', (
      tester,
    ) async {
      // O caso real: as "Entregas hoje" sobem ao painel num dia com entregas,
      // e no dia seguinte não há nenhuma — o KPI volta a "aguarda" e sai dos
      // prontos. Se a caixa só existisse lá, ficava preso no painel a dizer
      // "aguarda", sem forma de o tirar até o dado voltar.
      final container = containerCom(estado);
      final deFora = naoProntos.first;
      container
          .read(painelProvider.notifier)
          .alternar(deFora.id, escolher: true);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      // Os grupos de baixo ficam fora do ecrã, e uma `ListView` nem chega a
      // construir o que não se vê.
      await tester.scrollUntilVisible(
        _caixaDe(deFora),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_caixaDe(deFora), findsOneWidget);
      // `scrollUntilVisible` pára assim que a linha entra no ecrã, e ela pode
      // ficar meia fora — o toque no centro caía então ao lado.
      await tester.ensureVisible(_caixaDe(deFora));
      await tester.pumpAndSettle();
      await tester.tap(_caixaDe(deFora));
      await tester.pumpAndSettle();

      expect(container.read(painelProvider).noPainel, isEmpty);
      // E deixa de ter caixa: já não está no painel, e marcar de novo um que
      // não passou pelo crivo é que não se pode.
      expect(_caixaDe(deFora), findsNothing);
    });

    testWidgets('o cabeçalho diz quantos já lá estão', (tester) async {
      final container = containerCom(estado);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));
      expect(
        find.textContaining('marca os que queres no painel'),
        findsOneWidget,
      );

      await tester.tap(_caixaDe(prontos.first));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 no painel'), findsOneWidget);
    });
  });

  group('no Redmi deitado', () {
    // A janela real do aparelho dele. A bancada ganhou duas colunas — a caixa
    // à esquerda e a pega à direita — e é aqui que se vê se a célula do meio
    // ainda cabe, em vez de se estimar que sim.
    const redmiDeitado = Size(838.9, 392.7);

    testWidgets('as linhas cabem, com caixa e pega', (tester) async {
      final container = containerCom(estado);
      await montarLandscape(
        tester,
        container,
        KpisPage(agora: agoraFixa),
        tamanho: redmiDeitado,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a caixa de marcar não fica abaixo do alvo de toque', (
      tester,
    ) async {
      final container = containerCom(estado);
      await montarLandscape(
        tester,
        container,
        KpisPage(agora: agoraFixa),
        tamanho: redmiDeitado,
      );

      // 48 dp é o mínimo do Material. Abaixo disto falha-se a marcação com o
      // dedo — e numa lista de linhas iguais falhar significa marcar a errada.
      final caixa = tester.getSize(find.byType(Checkbox).first);
      expect(caixa.width, greaterThanOrEqualTo(48));
    });
  });

  group('arrastar', () {
    testWidgets('a pega troca a ordem, e o painel segue-a', (tester) async {
      final container = containerCom(estado);
      final painel = container.read(painelProvider.notifier);
      painel
        ..alternar(prontos[0].id, escolher: true)
        ..alternar(prontos[1].id, escolher: true);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      expect(container.read(painelProvider).noPainel, [
        prontos[0].id,
        prontos[1].id,
      ]);

      await _arrastarAPrimeiraParaBaixo(tester);

      expect(container.read(painelProvider).noPainel, [
        prontos[1].id,
        prontos[0].id,
      ]);
    });

    testWidgets('arrastar não marca nem desmarca ninguém', (tester) async {
      final container = containerCom(estado);
      container
          .read(painelProvider.notifier)
          .alternar(prontos[1].id, escolher: true);
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      await _arrastarAPrimeiraParaBaixo(tester);

      // Só um continua no painel — o que lá estava. Mudou o lugar, não a
      // escolha.
      expect(container.read(painelProvider).noPainel, [prontos[1].id]);
    });
  });
}

/// Rola a página até ao fim, colhendo pelo caminho o rótulo de cada caixa.
///
/// A lista dos prontos passou a ser um sliver e só constrói o que se vê —
/// contar caixas no ecrã contava as visíveis, não as que existem. Rola-se pelo
/// meio da página, longe da coluna da pega, para o arrasto não ser confundido
/// com uma reordenação.
Future<Set<String>> _rotulosDasCaixas(WidgetTester tester) async {
  final vistos = <String>{};
  void colher() {
    for (final e in find.byType(Checkbox).evaluate()) {
      final rotulo = (e.widget as Checkbox).semanticLabel;
      if (rotulo != null) vistos.add(rotulo);
    }
  }

  colher();
  await _atePaginaAbaixo(tester, aCadaPasso: colher);
  return vistos;
}

/// Rola até o fim da página deixar de se mexer.
Future<void> _atePaginaAbaixo(
  WidgetTester tester, {
  void Function()? aCadaPasso,
}) async {
  final pagina = find.byType(CustomScrollView);
  double? anterior;
  for (var i = 0; i < 30; i++) {
    final posicao = tester
        .state<ScrollableState>(
          find.descendant(of: pagina, matching: find.byType(Scrollable)).first,
        )
        .position;
    if (anterior != null && posicao.pixels == anterior) return;
    anterior = posicao.pixels;
    await tester.drag(pagina, const Offset(0, -260));
    await tester.pumpAndSettle();
    aCadaPasso?.call();
  }
}

/// Pega na primeira linha e larga-a por baixo da segunda.
///
/// O passo tem de ser dado aos bocados: a primeira deslocação é a que faz o
/// gesto ser reconhecido como arrasto, e só as seguintes é que a lista lê como
/// mudança de lugar. Um `moveBy` grande de uma vez levantava a linha e
/// pousava-a onde estava.
Future<void> _arrastarAPrimeiraParaBaixo(WidgetTester tester) async {
  final pegas = find.byIcon(Icons.drag_indicator);
  final origem = tester.getCenter(pegas.first);
  final passo = tester.getCenter(pegas.at(1)).dy - origem.dy;

  final gesto = await tester.startGesture(origem);
  await tester.pump();
  for (var andado = 0.0; andado < passo * 1.2; andado += passo / 4) {
    await gesto.moveBy(Offset(0, passo / 4));
    await tester.pump();
  }
  await gesto.up();
  await tester.pumpAndSettle();
}

/// A caixa de marcar de um KPI, pelo rótulo que se lê em voz alta.
///
/// Numa lista de catorze linhas iguais, "caixa de verificação, marcada" não
/// diz de quê — daí o `semanticLabel`, que serve o leitor de ecrã e serve
/// aqui para não se apanhar a linha errada por índice.
Finder _caixaDe(KpiDefinicao kpi) => find.byWidgetPredicate(
  (w) => w is Checkbox && w.semanticLabel == '${kpi.titulo} no painel',
);
