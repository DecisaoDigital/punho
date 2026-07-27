import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/todas_metricas_page.dart';

import 'fixtura.dart';

/// Onde o gestor vai buscar um número específico. Só tem de estar completa,
/// legível e nunca inventar zeros.
void main() {
  group('Secções', () {
    testWidgets('estão todas e por esta ordem', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      final titulos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where(
            (t) => const [
              'DINHEIRO',
              'PIPELINE',
              'MÁQUINAS',
              'CUSTOS',
              'SEMANA',
              'COMPARAÇÃO COM MÊS HOMÓLOGO',
              'FRASE DA SEMANA',
            ].contains(t),
          )
          .toList();

      expect(titulos, [
        'DINHEIRO',
        'PIPELINE',
        'MÁQUINAS',
        'CUSTOS',
        'SEMANA',
        'COMPARAÇÃO COM MÊS HOMÓLOGO',
        'FRASE DA SEMANA',
      ]);
    });
  });

  group('As métricas do painel antigo continuam todas cá', () {
    testWidgets('dinheiro, pipeline, máquinas e custos', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      // Amostra que cobre as 17 do Wrap original.
      for (final metrica in const [
        'Recebido este mês',
        'Recebido hoje',
        'Despesas pagas hoje',
        'Pago este mês',
        'Por receber',
        'Por pagar',
        'Resultado provisório (recebido − pago)',
        'Leads por contactar',
        'Valor previsto em reservas confirmadas',
        'Reservas confirmadas nas próximas 2 semanas',
        'Máquinas declaradas',
        'Máquinas identificadas',
        'Máquinas disponíveis',
        'Sem alugar há mais de 7 dias',
        'Colaboradores ativos / vagas',
        'Custo real com pessoal',
        'Custo estimado mensal de frota',
      ]) {
        expect(find.text(metrica), findsOneWidget, reason: metrica);
      }
    });

    testWidgets('os valores vêm dos KPIs, não de contas próprias', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      // Os mesmos números que o slide do dinheiro mostra.
      expect(find.text('1320 €'), findsOneWidget);
      expect(find.text('430,00 €'), findsOneWidget);
      expect(find.text('890,00 €'), findsOneWidget);
    });

    testWidgets('a frase da semana sobreviveu ao redesenho', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      expect(find.text('FRASE DA SEMANA'), findsOneWidget);
      expect(find.textContaining('Vilfredo Pareto'), findsWidgets);
    });
  });

  group('Sem dados', () {
    testWidgets('mostra "Por apurar" em vez de zeros inventados', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoSemMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      // Resultado do mês, conversão, ocupação e ticket médio: todos sem base
      // para calcular.
      expect(find.text('Por apurar'), findsWidgets);
    });

    testWidgets('a secção homóloga explica-se e oferece o caminho', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 3800),
      );

      expect(
        find.text('Histórico do ano passado por preencher.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Preencher'), findsOneWidget);
    });
  });

  group('Navegação', () {
    testWidgets('tem AppBar com título e botão de voltar', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TodasMetricasPage(agora: agoraFixa),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Todas as métricas'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TodasMetricasPage), findsNothing);
    });
  });
}
