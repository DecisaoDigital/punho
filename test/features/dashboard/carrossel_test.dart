import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/dashboard/presentation/slides/dinheiro_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/pipeline_slide.dart';
import 'package:punho/features/dashboard/presentation/todas_metricas_page.dart';

import 'fixtura.dart';

void main() {
  group('Carrossel do painel', () {
    testWidgets('abre no slide do dinheiro e diz onde estamos', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      expect(find.text('1/5 · Dinheiro'), findsOneWidget);
      expect(find.byType(DinheiroSlide), findsOneWidget);
      // Cabeçalho com o responsável e a data, sem uma saudação artificial.
      expect(find.text('Alfredo'), findsOneWidget);
      expect(find.text('Quarta-feira, 15 Julho 2026'), findsOneWidget);
    });

    testWidgets('a seta direita avança de slide', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      await tester.tap(find.byTooltip('Slide seguinte'));
      await tester.pumpAndSettle();

      expect(find.text('2/5 · Pipeline'), findsOneWidget);
      expect(find.byType(PipelineSlide), findsOneWidget);
    });

    testWidgets('no primeiro slide a seta esquerda está desligada', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      final seta = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Slide anterior'),
          matching: find.byType(IconButton),
        ),
      );
      expect(seta.onPressed, isNull);
    });

    testWidgets('tocar no nome de outro slide salta para lá', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Pipeline'));
      await tester.pumpAndSettle();

      expect(find.text('2/5 · Pipeline'), findsOneWidget);
      expect(find.byType(PipelineSlide), findsOneWidget);
    });

    testWidgets('arrastar para o lado muda de slide', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('2/5 · Pipeline'), findsOneWidget);
    });

    testWidgets('as setas do teclado navegam para quem está no PC', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2/5 · Pipeline'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('1/5 · Dinheiro'), findsOneWidget);
    });

    testWidgets('no último slide não avança mais', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Slide seguinte'));
        await tester.pumpAndSettle();
      }

      final seta = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Slide seguinte'),
          matching: find.byType(IconButton),
        ),
      );
      expect(seta.onPressed, isNull);
    });

    testWidgets('o botão de dados da empresa continua no cabeçalho', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
      );

      expect(find.byTooltip('Editar dados da empresa'), findsOneWidget);
    });
  });

  group('Todas as métricas', () {
    testWidgets('a lista antiga continua acessível e completa', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      // Amostra das 17: nenhuma foi apagada com o redesenho.
      expect(find.text('Colaboradores ativos / vagas'), findsOneWidget);
      expect(find.text('Recebido hoje'), findsOneWidget);
      expect(find.text('Sem alugar há mais de 7 dias'), findsOneWidget);
      expect(find.text('Leads por contactar'), findsOneWidget);
      expect(
        find.text('Resultado provisório (recebido − pago)'),
        findsOneWidget,
      );
      expect(find.text('Valor previsto em reservas confirmadas'), findsOneWidget);
      // E a frase da semana, que saiu do painel.
      expect(find.text('FRASE DA SEMANA'), findsOneWidget);
    });
  });
}
