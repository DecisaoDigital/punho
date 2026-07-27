import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/slides/custos_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/dinheiro_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/pipeline_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/rentabilidade_slide.dart';
import 'package:punho/features/dashboard/presentation/slides/semana_slide.dart';
import 'package:punho/features/dashboard/presentation/widgets/kpi_grid_2x2.dart';
import 'package:punho/features/dashboard/presentation/widgets/recomendacao_card.dart';

import 'fixtura.dart';

void main() {
  group('Slide 1 · Dinheiro', () {
    testWidgets('mostra três KPIs de dinheiro e a recomendação do dia', (
      tester,
    ) async {
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
      // A quarta célula deixou de ser o "Resultado provisório".
      expect(find.text('Recomendação do dia'), findsOneWidget);
      expect(find.text('Resultado provisório'), findsNothing);
    });

    testWidgets('as setas mudam o mês nos KPIs de recebido e pago', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      // Duas setas para trás: uma em cada card, com o mesmo estado por trás.
      expect(find.byTooltip('Mês anterior'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Mês anterior').first);
      await tester.pumpAndSettle();

      expect(find.text('Recebido em Junho'), findsOneWidget);
      expect(find.text('1100 €'), findsOneWidget);
      // O "Pago" acompanha: um mês diferente em cada card dava duas verdades no
      // mesmo ecrã.
      expect(find.text('Pago em Junho'), findsOneWidget);
      expect(find.text('Pago este mês'), findsNothing);
    });

    testWidgets('a recomendação do dia não muda ao navegar no tempo', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );
      final antes = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(RecomendacaoCard),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();

      await tester.tap(find.byTooltip('Mês anterior').last);
      await tester.pumpAndSettle();

      final depois = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(RecomendacaoCard),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();
      expect(depois, antes, reason: 'recomendar sobre um mês passado não faz sentido');
    });

    testWidgets('o "Por receber" assume que só sabe o mês actual', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('só o mês actual'), findsNothing);

      await tester.tap(find.byTooltip('Mês anterior').first);
      await tester.pumpAndSettle();

      // O modelo não guarda como a dívida estava no fim de cada mês; o card
      // diz-lo em vez de mostrar um número que não sabe.
      expect(find.text('só o mês actual'), findsOneWidget);
    });

    testWidgets('no mês actual não se pode avançar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      for (final seta in tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      )) {
        expect(seta.onPressed, isNull);
      }
    });

    testWidgets('não recua para antes do primeiro registo', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DinheiroSlide(agora: agoraFixa),
      );

      // O registo mais antigo da fixture é de Maio.
      for (var i = 0; i < 3; i++) {
        final recuar = tester
            .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .first;
        if (recuar.onPressed == null) break;
        await tester.tap(find.byTooltip('Mês anterior').first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Recebido em Maio'), findsOneWidget);
      for (final seta in tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      )) {
        expect(seta.onPressed, isNull, reason: 'antes de Maio não há registos');
      }
    });

    testWidgets('recomendação vermelha aparece com bordo de urgente', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComDividaAntiga()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('Urgente'), findsOneWidget);
      expect(
        find.textContaining('Cobrar Manuel Antunes — 45 dias em atraso'),
        findsOneWidget,
      );
      expect(find.text('Abrir ficha →'), findsOneWidget);
    });

    testWidgets('sem uma única despesa registada o "Pago" não mostra 0 €', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComDividaAntiga()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('Ainda não registaste nenhuma despesa.'), findsOneWidget);
      expect(find.text('0,00 €'), findsNothing);
    });

    testWidgets('sem regra aplicável mostra o vazio, não um card em falta', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemRecomendacao()),
        DinheiroSlide(agora: agoraFixa),
      );

      expect(find.text('Recomendação do dia'), findsOneWidget);
      expect(find.text('Sem sugestão para hoje'), findsOneWidget);
      expect(find.text('Urgente'), findsNothing);
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
