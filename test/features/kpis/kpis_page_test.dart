import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/dashboard/presentation/widgets/grelha_de_kpis.dart';
import 'package:punho/features/kpis/presentation/cartao_caixa.dart';
import 'package:punho/features/kpis/presentation/kpis_page.dart';

/// A página dos KPIs e o primeiro que lá vive.
///
/// O risco desta página não é ter poucos indicadores — é alguém a encher de
/// exemplos enquanto os dados reais não chegam. Estes testes guardam o
/// contrário: o que está no ecrã vem de uma fonte, ou não está no ecrã.
void main() {
  Future<void> abrir(WidgetTester tester) => tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: KpisPage())),
    ),
  );

  testWidgets('diz o que é e para que serve', (tester) async {
    await abrir(tester);

    expect(find.text('KPIs (todos)'), findsOneWidget);
    expect(find.textContaining('Todos os indicadores num sítio só'), findsOne);
  });

  testWidgets('a Caixa é o primeiro indicador da lista', (tester) async {
    await abrir(tester);

    expect(find.byType(CartaoCaixa), findsOneWidget);
    // A célula do painel escreve o rótulo em maiúsculas, e leva o período
    // colado: é o formato de lá, e é esse que este ecrã segue.
    expect(find.textContaining('CAIXA · 1 A'), findsOneWidget);
  });

  testWidgets('empresa sem movimentos não vê um zero', (tester) async {
    // Um "0 €" diria "não facturaste". Sem registos, a verdade é outra.
    await abrir(tester);

    expect(find.text('Sem movimentos este mês'), findsOneWidget);
    expect(find.textContaining('+ 0,00 €'), findsNothing);
    // E sem histórico não há "vinha de trás" nenhum para mostrar.
    expect(find.text('Vinha de trás'), findsNothing);
  });

  /// «o KPI no menu dos KPIs tem de ter o mesmo formato e tamanho dos KPIs no
  /// dashboard» — Cesar, 5/8/2026, e outra vez a seguir porque a primeira
  /// tentativa falhou: aliguei-o ao `KpiCard`, que **o painel nunca usou**. O
  /// painel desenha `CelulaSemaforo` dentro de uma `GrelhaDeKpis`, e é a essas
  /// duas que este ecrã tem de obedecer.
  group('é um KPI do painel, não um parecido', () {
    testWidgets('usa a mesma célula que o painel usa', (tester) async {
      await abrir(tester);

      expect(find.byType(CelulaSemaforo), findsOneWidget);
    });

    testWidgets('mede-se pela grelha do painel, não por um número copiado', (
      tester,
    ) async {
      // Duas colunas com 10 de intervalo, que é a regra da `GrelhaDeKpis`. Se
      // alguém puser aqui uma lista de largura inteira, este teste cai.
      tester.view.physicalSize = const Size(873, 393);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await abrir(tester);
      await tester.pumpAndSettle();

      final celula = tester.getSize(find.byType(CelulaSemaforo));
      final pagina = tester.getSize(find.byType(GrelhaDeKpis));
      expect(celula.width, (pagina.width - 10) / 2);
      expect(celula.height, (pagina.height - 10) / 2);
    });
  });

  testWidgets('cabe no telemóvel deitado sem transbordar', (tester) async {
    // O Redmi Note 10 Pro em paisagem, menos a barra lateral de 88 dp: é o
    // formato em que esta app se usa, e é o que costuma cortar o rodapé.
    tester.view.physicalSize = const Size(838, 393);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await abrir(tester);

    expect(tester.takeException(), isNull);
  });
}
