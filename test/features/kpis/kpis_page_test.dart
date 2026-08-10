import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/kpis/presentation/kpis_page.dart';

/// A **KPIs (todos)** — a bancada. O que estes testes guardam: a página mostra
/// o catálogo todo agrupado pelo estado de verdade, diz o que falta para os que
/// ainda não chegaram, e um KPI **sobe** de grupo quando o dado entra.
void main() {
  Future<void> abrir(
    WidgetTester tester, {
    OperationRepository? repo,
    DateTime? agora,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repo != null) operationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(body: KpisPage(agora: agora)),
      ),
    ),
  );

  testWidgets('diz o que é e a ideia de crescer com o empresário', (
    tester,
  ) async {
    await abrir(tester);

    // O título saiu da página: a barra lateral já diz o nome do ecrã, e os
    // 24 dp que ele gastava faziam falta ao terceiro cartão. O que fica é a
    // ideia, numa linha.
    expect(find.text('KPIs (todos)'), findsNothing);
    expect(find.textContaining('A app cresce contigo'), findsOneWidget);
  });

  testWidgets('a Caixa e a Tendência também vivem na bancada', (tester) async {
    // Já não são cartões à parte no topo: entraram no catálogo como as outras,
    // desenhadas na mesma célula do painel. Viewport alto para as construir.
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await abrir(tester);

    expect(find.textContaining('CAIXA'), findsWidgets);
    expect(find.textContaining('TENDÊNCIA DO MÊS'), findsOneWidget);
    expect(find.byType(CelulaSemaforo), findsWidgets);
  });

  testWidgets('empresa vazia: os KPIs estão por definir e dizem o que falta', (
    tester,
  ) async {
    // Viewport alto para a lista construir tudo — o ListView é preguiçoso e os
    // itens "por definir" ficam abaixo da dobra num ecrã normal.
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await abrir(tester);

    // Sem dados nenhuns, nada está pronto a subir.
    expect(find.textContaining('Prontos'), findsNothing);
    // Mas a bancada mostra os que faltam e o que os desbloqueia.
    expect(find.textContaining('Por definir'), findsOneWidget);
    expect(find.textContaining('Desbloqueia com:'), findsWidgets);
  });

  testWidgets('quando o dado entra, o KPI sobe a "Prontos"', (tester) async {
    // Uma reserva com valor no mês acende o ticket médio (e os operacionais):
    // deixam de estar "por definir" e passam a poder subir ao painel.
    final repo = LocalDemoOperationRepository()
      ..saveBooking(
        Booking(
          id: 'b1',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime(2026, 8, 12),
          endsAt: DateTime(2026, 8, 14),
          status: BookingStatus.confirmed,
          expectedValueCents: 50000,
        ),
      );

    await abrir(tester, repo: repo, agora: DateTime(2026, 8, 9));

    expect(find.textContaining('Prontos'), findsOneWidget);
  });

  testWidgets('cabe no telemóvel deitado sem transbordar', (tester) async {
    // O Redmi Note 10 Pro em paisagem, menos a barra lateral: é o formato em
    // que esta app se usa, e é o que costuma cortar o rodapé.
    tester.view.physicalSize = const Size(838, 393);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await abrir(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
