import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/slides/custos_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/dinheiro_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/pipeline_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/rentabilidade_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/semana_slide.dart';
import 'package:punho/features/dashboard/presentation/widgets/kpi_grid_2x2.dart';

import 'fixtura.dart';

void main() {
  group('Slide 1 · Dinheiro', () {
    testWidgets('mostra recebido, por receber, pago e resultado', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('Estou a facturar o esperado? Preciso de cobrar?'), findsOneWidget);
      expect(find.text('Recebido este mês'), findsOneWidget);
      expect(find.text('1320 €'), findsOneWidget);
      expect(find.text('Por receber'), findsOneWidget);
      expect(find.text('Pago este mês'), findsOneWidget);
      expect(find.text('Resultado provisório'), findsOneWidget);
      // 1320 − 430.
      expect(find.text('890,00 €'), findsOneWidget);
    });

    testWidgets('as setas navegam o mês dentro do próprio card', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Recebido em Junho'), findsOneWidget);
      expect(find.text('1100 €'), findsOneWidget);
      // Os outros cards continuam no mês actual.
      expect(find.text('Pago este mês'), findsOneWidget);
    });

    testWidgets('no mês actual não se pode avançar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      final seta = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Mês seguinte'),
          matching: find.byType(IconButton),
        ),
      );
      expect(seta.onPressed, isNull);
    });

    testWidgets('empresa sem movimentos não mostra zeros, mostra o convite', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('Ainda sem movimentos este mês'), findsOneWidget);
      expect(find.text('Registar recebimento'), findsOneWidget);
      expect(find.text('0,00 €'), findsNothing);
    });
  });

  group('Slide 2 · Pipeline', () {
    testWidgets('mostra confirmadas, leads, conversão e cauções', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        PipelineSlide(agora: agoraFixa),
      );

      expect(find.text('Tenho negócio à porta? Preciso de mais leads?'), findsOneWidget);
      expect(find.text('Reservas confirmadas'), findsOneWidget);
      expect(find.text('1200 € previstos'), findsOneWidget);
      expect(find.text('Leads por contactar'), findsOneWidget);
      expect(find.textContaining('mais antiga há 4 dias'), findsOneWidget);
      expect(find.text('Conversão de leads'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('cauções aparecem como por apurar, não como zero', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        PipelineSlide(agora: agoraFixa),
      );

      expect(find.text('Cauções em posse'), findsOneWidget);
      expect(
        find.text('As cauções ainda não se registam na app.'),
        findsOneWidget,
      );
    });

    testWidgets('sem leads a taxa fica por apurar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento()),
        PipelineSlide(agora: agoraFixa),
      );

      expect(find.text('Sem leads no período para converter.'), findsOneWidget);
    });
  });

  group('Slide 3 · Máquinas', () {
    testWidgets('mostra ocupação, top, paradas e ticket', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        RentabilidadeSlide(agora: agoraFixa),
      );

      expect(find.text('O que está a render? O que está parado sem razão?'), findsOneWidget);
      expect(find.text('Ocupação das máquinas'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget, reason: '2 de 21 dias-máquina');
      expect(find.text('Mais alugadas'), findsOneWidget);
      expect(find.text('Mini escavadora'), findsWidgets);
      expect(find.text('Sem alugar há mais de 7 dias'), findsOneWidget);
      expect(find.textContaining('nunca alugada'), findsOneWidget);
      expect(find.text('Valor médio por reserva'), findsOneWidget);
    });

    testWidgets('sem máquinas a ocupação fica por apurar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento()),
        RentabilidadeSlide(agora: agoraFixa),
      );

      expect(
        find.text('Sem máquinas registadas não há ocupação para medir.'),
        findsOneWidget,
      );
    });
  });

  group('Slide 4 · Custos', () {
    testWidgets('mostra equipa, frota, manutenção e o peso na receita', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        CustosSlide(agora: agoraFixa),
      );

      expect(find.text('Estou dentro do orçamento? Onde posso cortar?'), findsOneWidget);
      expect(find.text('Custo da equipa'), findsOneWidget);
      expect(find.text('1100 €'), findsOneWidget);
      expect(find.text('Custo da frota'), findsOneWidget);
      expect(find.text('Manutenção paga'), findsOneWidget);
      expect(find.text('Custos sobre a receita'), findsOneWidget);
      expect(find.text('Ver todas as métricas →'), findsOneWidget);
    });

    testWidgets('sem frota o card passa a outros custos', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento()),
        CustosSlide(agora: agoraFixa),
      );

      expect(find.text('Outros custos operacionais'), findsOneWidget);
      expect(find.text('Custo da frota'), findsNothing);
    });
  });

  group('Slide 5 · Semana', () {
    testWidgets('mostra uma recomendação com gravidade, e não uma pilha', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        SemanaSlide(agora: agoraFixa),
      );

      expect(find.text('O que faço hoje e esta semana?'), findsOneWidget);
      expect(find.text('Recomendação da semana'), findsOneWidget);
      expect(find.text('Urgente'), findsOneWidget);
      expect(find.text('Adiar 7 dias'), findsOneWidget);
      expect(find.text('Feito'), findsOneWidget);
      // Uma só: o motor devolve três, o slide mostra a mais grave.
      expect(find.textContaining('Alavanca:'), findsOneWidget);
    });

    testWidgets('adiar tira a recomendação e põe outra no lugar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        SemanaSlide(agora: agoraFixa),
      );
      final antes = tester
          .widgetList<Text>(find.textContaining('Alavanca:'))
          .first
          .data;

      await tester.tap(find.text('Adiar 7 dias'));
      await tester.pumpAndSettle();

      final depois = tester
          .widgetList<Text>(find.textContaining('Alavanca:'))
          .first
          .data;
      expect(depois, isNot(antes));
    });

    testWidgets('mostra próximas reservas, tarefas e cobranças', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        SemanaSlide(agora: agoraFixa),
      );

      expect(find.text('Próximas reservas'), findsOneWidget);
      expect(find.textContaining('Construções Silva'), findsWidgets);
      expect(find.text('Tarefas pendentes'), findsOneWidget);
      expect(find.text('Abrir Tarefas →'), findsOneWidget);
      expect(find.text('Cobranças com atraso'), findsOneWidget);
      expect(find.text('Cobrar →'), findsOneWidget);
    });
  });

  group('A grelha enche o espaço', () {
    testWidgets('em landscape são quatro células, sem scroll', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.byType(KpiCard), findsNWidgets(4));
      // Sem overflow: um erro de layout falharia o teste aqui.
      expect(tester.takeException(), isNull);
    });

    testWidgets('num ecrã baixo passa a coluna com scroll em vez de espremer', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
        tamanho: const Size(740, 300),
      );

      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
