import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/kpis/presentation/kpis_page.dart';

/// A **KPIs (todos)** — a bancada. O que estes testes guardam: a página mostra
/// os KPIs que já dizem verdade, um KPI **aparece** quando o dado entra, e uma
/// empresa sem dados nenhuns não fica a olhar para um ecrã em branco.
///
/// Os grupos «A chegar» e «Por definir» saíram a 10 de Agosto de 2026, a pedido
/// do César: com 23 dos 25 do catálogo já verificados, o que sobrava neles era
/// uma lista comprida de coisas que não se podem fazer, à frente das que se
/// podem.
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
    await abrir(tester, repo: _comRecebimento(), agora: DateTime(2026, 8, 9));

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

    // Com um recebimento no mês, a Caixa e a Tendência têm fonte e aparecem.
    // Sem ele não apareceriam nenhumas: desde que os grupos «A chegar» e «Por
    // definir» saíram, a bancada só mostra o que já diz verdade.
    await abrir(tester, repo: _comRecebimento(), agora: DateTime(2026, 8, 9));

    expect(find.textContaining('CAIXA'), findsWidgets);
    expect(find.textContaining('TENDÊNCIA DO MÊS'), findsOneWidget);
    expect(find.byType(CelulaSemaforo), findsWidgets);
  });

  testWidgets('empresa vazia: a bancada diz que está vazia e porquê', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await abrir(tester);

    // Os grupos «A chegar» e «Por definir» saíram a pedido do César (10 Ago
    // 2026): com 23 dos 25 KPIs assinados, o que sobrava em baixo era uma
    // lista comprida de coisas que não se podem fazer, à frente das que se
    // podem.
    //
    // O que não pode voltar com eles é o ecrã em branco. Sem um único KPI com
    // fonte, a bancada não mostra cartão nenhum — e tem de dizer isso, senão
    // uma empresa acabada de abrir fica a olhar para o nada.
    expect(find.byType(CelulaSemaforo), findsNothing);
    expect(find.textContaining('Ainda não há KPIs a dizer verdade'), findsOne);
    expect(find.textContaining('Desbloqueia com:'), findsNothing);
  });

  testWidgets('quando o dado entra, o KPI aparece na bancada', (tester) async {
    // Alto para a lista construir tudo: é preguiçosa, e o ticket médio não é o
    // primeiro cartão.
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(find.textContaining('TICKET MÉDIO'), findsOneWidget);
    expect(find.textContaining('KPIs a dizer verdade'), findsOneWidget);
  });

  /// **Os que não estão à vista deixam rasto.** O César, a 10 de Agosto de
  /// 2026, com nove cartões no ecrã de vinte e cinco que existem: «só me
  /// aparecem 9 KPIs na bancada, não deveriam ser 15?». A regra de só mostrar
  /// o que diz verdade é a certa; o que faltava era a resposta à pergunta.
  group('o rasto dos que faltam', () {
    testWidgets('diz quantos faltam, fechado', (tester) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await abrir(tester, repo: _comRecebimento(), agora: DateTime(2026, 8, 9));

      expect(
        find.textContaining('toca para ver o que os acende'),
        findsOneWidget,
      );
      // Fechado é fechado: a razão de cada um só aparece depois do toque.
      expect(
        find.text('Custos fixos declarados em Empresa › Custos fixos'),
        findsNothing,
      );
    });

    testWidgets('aberto, diz o que acende cada um', (tester) async {
      tester.view.physicalSize = const Size(600, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await abrir(tester, repo: _comRecebimento(), agora: DateTime(2026, 8, 9));
      await tester.tap(find.textContaining('toca para ver o que os acende'));
      await tester.pumpAndSettle();

      expect(find.text('Gastos previstos do mês'), findsOneWidget);
      expect(
        find.text('Custos fixos declarados em Empresa › Custos fixos'),
        findsWidgets,
      );
      // Um KPI com fonte cheia mas conta por assinar não espera por dados
      // nenhuns — espera por nós, e não se lhe manda preencher nada.
      expect(find.text('Conta por verificar do nosso lado'), findsWidgets);
    });
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

/// Um recebimento no mês chega para a Caixa e a Tendência terem fonte.
LocalDemoOperationRepository _comRecebimento() =>
    LocalDemoOperationRepository()..saveReceipt(
      Receipt(
        id: 'r1',
        date: DateTime(2026, 8, 5),
        amountCents: 120000,
        customerId: 'c1',
        method: PaymentMethod.transfer,
      ),
    );
