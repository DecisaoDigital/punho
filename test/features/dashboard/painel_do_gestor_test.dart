import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/core/operations/painel_controller.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/kpis/presentation/cadeia_do_kpi_page.dart';

import 'fixtura.dart';

/// **O painel é o que o gestor lá puser.**
///
/// Eram três slides escritos à mão, doze células fixas iguais para toda a
/// gente. Uma empresa sem leads abria a app e via quatro caixas a dizer
/// "aguarda" — a app parecia não saber nada da vida dela, e tinha razão.
///
/// Estes testes defendem as três coisas que fazem a diferença: que **começa
/// vazio** (não se sugere nada por ele), que mostra **quatro por ecrã**, e que
/// a **ordem da lista é a ordem daqui** — não há segunda regra escondida.
void main() {
  group('começa vazio', () {
    testWidgets('sem escolha nenhuma, o painel diz o que falta fazer', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(find.text('O painel ainda está vazio'), findsOneWidget);
      expect(find.text('Escolher KPIs'), findsOneWidget);
      // O ponto: nem uma célula. Nem sequer as que já sabiam dizer verdade —
      // sugeri-las seria a app a decidir o que interessa ao negócio dele.
      expect(find.byType(CelulaSemaforo), findsNothing);
    });

    testWidgets('a uma empresa nova não se manda escolher o que não há', (
      tester,
    ) async {
      // Sem uma reserva, um recebimento ou uma despesa, o catálogo inteiro
      // está em "aguarda" e a bancada não tem uma única caixa. Dizer-lhe
      // "escolhe os que queres" era mandá-lo a uma porta fechada — e a
      // primeira coisa que a app lhe dizia era falsa.
      final container = containerCom(estadoSemMovimento());
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(find.text('Ainda não há KPIs a dizer verdade'), findsOneWidget);
      expect(find.text('Ver o que falta'), findsOneWidget);
      expect(find.text('Escolher KPIs'), findsNothing);
    });
  });

  group('o que se escolhe é o que aparece', () {
    testWidgets('um KPI marcado sobe ao painel', (tester) async {
      final container = containerCom(estadoComMovimento());
      container.read(painelProvider.notifier).alternar('caixa', escolher: true);

      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(find.text('O painel ainda está vazio'), findsNothing);
      expect(find.byType(CelulaSemaforo), findsOneWidget);
      // A barra do fundo chama cada ecrã pelo primeiro KPI que lá está: quem a
      // lê quer saber o que está do outro lado, e um "Painel 1" não diz nada.
      expect(find.textContaining('1/1 · Caixa'), findsOneWidget);
    });

    testWidgets('quatro por ecrã, e o quinto começa o ecrã seguinte', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      final painel = container.read(painelProvider.notifier);
      for (final id in _cincoDoCatalogo) {
        painel.alternar(id, escolher: true);
      }

      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(find.byType(CelulaSemaforo), findsNWidgets(4));
      expect(find.textContaining('1/2 · '), findsOneWidget);
    });

    testWidgets('a ordem da lista é a ordem do painel', (tester) async {
      final container = containerCom(estadoComMovimento());
      final painel = container.read(painelProvider.notifier);
      painel
        ..alternar('caixa', escolher: true)
        ..alternar('entradas-mes', escolher: true);

      painel.reordenar(['entradas-mes', 'caixa']);
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(
        find.textContaining('1/1 · Dinheiros que entraram'),
        findsOneWidget,
      );
    });
  });

  group('desmarcar não parte o que está aberto', () {
    testWidgets('encolher o painel com o gestor no último ecrã', (
      tester,
    ) async {
      // O `PageView` guarda a página no controlador, não no estado do widget.
      // Sem a correcção, ficava parado num ecrã que já não existe: painel em
      // branco, barra a dizer "2/1", e erro nenhum a explicá-lo.
      final container = containerCom(estadoComMovimento());
      final painel = container.read(painelProvider.notifier);
      for (final id in _cincoDoCatalogo) {
        painel.alternar(id, escolher: true);
      }
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      await tester.tap(find.byTooltip('Ecrã seguinte'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2/2 · '), findsOneWidget);

      painel.alternar(_cincoDoCatalogo.last, escolher: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('1/1 · '), findsOneWidget);
      expect(find.byType(CelulaSemaforo), findsNWidgets(4));
    });

    testWidgets('desmarcar o último devolve o painel ao estado vazio', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      final painel = container.read(painelProvider.notifier);
      painel.alternar('caixa', escolher: true);
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      painel.alternar('caixa', escolher: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('O painel ainda está vazio'), findsOneWidget);
    });
  });

  group('um id que esta versão já não conhece', () {
    testWidgets('desaparece do painel sem fazer barulho', (tester) async {
      // Painel arrumado numa app mais nova, aberto numa mais velha. Rebentar
      // aqui prendia o gestor fora do painel até actualizar — e a
      // actualização é a coisa que ele faz por último.
      final container = containerCom(estadoComMovimento());
      container.read(painelProvider.notifier)
        ..alternar('kpi-que-ainda-nao-existe', escolher: true)
        ..alternar('caixa', escolher: true);

      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(tester.takeException(), isNull);
      expect(find.byType(CelulaSemaforo), findsOneWidget);
    });
  });

  group('no Redmi deitado', () {
    testWidgets('o rodapé aguenta os nomes compridos do catálogo', (
      tester,
    ) async {
      // O rodapé passou de três nomes curtos escritos à mão para nomes de KPIs
      // escolhidos por ele — e "Utilização vs Rentabilidade" tem 27 caracteres.
      // Enche-se o painel com os mais compridos que o catálogo tem, para o
      // rodapé apanhar o pior caso que pode mesmo acontecer.
      final container = containerCom(estadoComMovimento());
      final painel = container.read(painelProvider.notifier);
      final maisCompridos = [...catalogoKpis]
        ..sort((a, b) => b.titulo.length.compareTo(a.titulo.length));
      for (final kpi in maisCompridos) {
        painel.alternar(kpi.id, escolher: true);
      }

      await montarLandscape(
        tester,
        container,
        DashboardPage(agora: agoraFixa),
        tamanho: const Size(838.9, 392.7),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('o caminho para onde se age', () {
    testWidgets('a célula das entradas continua a abrir as Finanças', (
      tester,
    ) async {
      // Vivia dentro do slide da síntese e desaparecia assim que a célula
      // fosse mostrada noutro sítio. Passou a andar com o KPI, no catálogo.
      expect(kpiPorId('entradas-mes')?.destino, isNotNull);

      final container = containerCom(estadoComMovimento());
      container
          .read(painelProvider.notifier)
          .alternar('entradas-mes', escolher: true);
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(_celulaTocavel, findsOneWidget);
    });

    testWidgets('um KPI sem destino não finge que leva a algum lado', (
      tester,
    ) async {
      // Era a Caixa que servia de exemplo. Deixou de servir a 13 de Agosto de
      // 2026: com a cadeia, a Caixa passou a ser a raiz de tudo e ganhou filhos
      // — e um toque nela abre o ecrã de atenção. O caso continua a existir, só
      // que agora é a satisfação do cliente: não tem destino, e é folha.
      expect(kpiPorId('satisfacao-cliente')?.destino, isNull);
      expect(filhosDe('satisfacao-cliente'), isEmpty);

      final container = containerCom(estadoComMovimento());
      container
          .read(painelProvider.notifier)
          .alternar('satisfacao-cliente', escolher: true);
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      expect(_celulaTocavel, findsNothing);
    });

    testWidgets('um KPI com filhos abre a cadeia em vez do destino', (
      tester,
    ) async {
      // A Caixa tem destino **e** filhos. Quem lhe toca quer saber porquê antes
      // de saber onde — e o ecrã da cadeia acaba com o botão para as Finanças,
      // portanto não se perde caminho nenhum.
      expect(filhosDe('caixa'), isNotEmpty);

      final container = containerCom(estadoComMovimento());
      container.read(painelProvider.notifier).alternar('caixa', escolher: true);
      await montarLandscape(tester, container, DashboardPage(agora: agoraFixa));

      await tester.tap(_celulaTocavel.first);
      await tester.pumpAndSettle();

      expect(find.byType(CadeiaDoKpiPage), findsOneWidget);
    });
  });
}

/// A célula embrulhada num toque que leva a algum lado.
///
/// Contar `InkWell`s do ecrã todo não servia: a barra do fundo tem os seus, e
/// o teste passava a dizer que a célula era tocável quando o que estava
/// tocável eram os pontinhos.
final _celulaTocavel = find.ancestor(
  of: find.byType(CelulaSemaforo),
  matching: find.byType(InkWell),
);

/// Cinco ids do catálogo, quantos bastam para o painel passar a duas páginas.
/// São ids reais de propósito — um inventado não provava a paginação, provava
/// que o painel aceita lixo.
const _cincoDoCatalogo = [
  'caixa',
  'entradas-mes',
  'encontro-contas',
  'reservas-activas',
  'ticket-medio-mes',
];
