import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/kpis/presentation/cartao_tendencia.dart';

/// O cartão de tendência que o Cesar pediu para a página "KPIs (todos)": o mesmo
/// indicador que abre o Painel, mas agora fora do carrossel. O número grande é
/// o **previsto** do mês, e a sub-linha diz a variação e contra quê — homólogo
/// quando há, mês passado só como recurso.
const _empresa = OnboardingData(
  ownerName: 'Alfredo Nogueira',
  companyName: 'Aluguer Nogueira',
  legalForm: 'Empresário em Nome Individual',
  hasFleet: false,
  collaborators: 0,
  declaredVehicleCount: 0,
  totalMachinesDeclared: 6,
  insertMachinesNow: false,
  companyTaxId: '248193066',
  companyPhone: '912 000 000',
  fixedMonthlyCostsCents: 180000,
);

Future<void> _pump(
  WidgetTester tester,
  OperationRepository repo, {
  required DateTime agora,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [operationRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: Scaffold(body: CartaoTendencia(agora: agora)),
    ),
  ),
);

void main() {
  group('CartaoTendencia', () {
    testWidgets('sem previsto nem histórico, aguarda em vez de acusar', (
      tester,
    ) async {
      final repo = LocalDemoOperationRepository()..saveOnboarding(_empresa);

      await _pump(tester, repo, agora: DateTime(2026, 8, 6));

      expect(find.text('Sem entradas nem histórico'), findsOneWidget);
      // Sem histórico não se inventa uma percentagem.
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('compara o previsto com o mês passado e mostra a queda', (
      tester,
    ) async {
      final repo = LocalDemoOperationRepository()
        ..saveOnboarding(_empresa)
        // Julho fechou em 1.000 € (via histórico do contabilista).
        ..saveHistoricalMonth(
          const HistoricalMonth(
            year: 2026,
            month: 7,
            revenueReceivedCents: 100000,
          ),
        )
        // Agosto leva 600 € recebidos até agora — previsto 600 €, −40%.
        ..saveReceipt(
          Receipt(
            id: 'r-agosto',
            date: DateTime(2026, 8, 5),
            amountCents: 60000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        );

      await _pump(tester, repo, agora: DateTime(2026, 8, 6));

      // O número grande é o previsto (600 €), não o homólogo nem o mês passado.
      // O valor vive num RichText (valor + unidade no mesmo span).
      expect(find.textContaining('600', findRichText: true), findsOneWidget);
      // A seta é para baixo e diz contra o mês passado.
      expect(
        find.textContaining('▼ 40% previsto face ao mês passado'),
        findsOneWidget,
      );
    });

    testWidgets('compara sempre com o mês passado, mesmo havendo homólogo', (
      tester,
    ) async {
      // A diferença face a "Dinheiros que entraram": este card é de crescimento
      // e ignora o homólogo de propósito. Julho de 2026 (mês passado) fechou em
      // 1.000 €; Julho de 2025 (homólogo) em 500 €. Com 600 € previstos, o
      // homólogo daria +20% (▲) e o mês passado dá −40% (▼). Tem de mostrar o
      // −40% — senão voltou a preferir o homólogo.
      final repo = LocalDemoOperationRepository()
        ..saveOnboarding(_empresa)
        ..saveHistoricalMonth(
          const HistoricalMonth(
            year: 2026,
            month: 7,
            revenueReceivedCents: 100000,
          ),
        )
        ..saveHistoricalMonth(
          const HistoricalMonth(
            year: 2025,
            month: 7,
            revenueReceivedCents: 50000,
          ),
        )
        ..saveReceipt(
          Receipt(
            id: 'r-agosto',
            date: DateTime(2026, 8, 5),
            amountCents: 60000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        );

      await _pump(tester, repo, agora: DateTime(2026, 8, 6));

      expect(
        find.textContaining('▼ 40% previsto face ao mês passado'),
        findsOneWidget,
      );
      expect(find.textContaining('▲'), findsNothing);
    });

    testWidgets('é a mesma célula que o painel usa', (tester) async {
      final repo = LocalDemoOperationRepository()..saveOnboarding(_empresa);

      await _pump(tester, repo, agora: DateTime(2026, 8, 6));

      expect(find.byType(CelulaSemaforo), findsOneWidget);
    });
  });
}
