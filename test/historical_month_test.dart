import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/historical_month.dart';

void main() {
  group('Onboarding escreve o histórico a partir da faturação declarada', () {
    ProviderContainer container() => ProviderContainer();

    void completar(OperationsController n, {int? revenueLastYearCents}) {
      n.completeOnboarding(
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 0,
        totalMachinesDeclared: 0,
        insertMachinesNow: false,
        revenueLastYearCents: revenueLastYearCents,
      );
    }

    test(
      'faturação divisível por 12 dá o mesmo valor em cada mês do ano '
      'passado',
      () {
        final c = container();
        addTearDown(c.dispose);
        final n = c.read(operationsProvider.notifier);
        completar(n, revenueLastYearCents: 1200000);

        final ano = DateTime.now().year - 1;
        final meses = c.read(operationsProvider).historicalMonths;
        expect(meses, hasLength(12));
        expect(meses.every((m) => m.year == ano), isTrue);
        expect(meses.every((m) => m.revenueReceivedCents == 100000), isTrue);
      },
    );

    test('resto da divisão inteira cai nos primeiros meses e a soma bate '
        'certo com o valor declarado', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      completar(n, revenueLastYearCents: 1000);

      final meses = c.read(operationsProvider).historicalMonths;
      final porMes = {for (final m in meses) m.month: m.revenueReceivedCents};
      // 1000 ~/ 12 = 83, resto 4: os meses 1 a 4 levam 84, os restantes 83.
      expect(porMes[1], 84);
      expect(porMes[4], 84);
      expect(porMes[5], 83);
      expect(porMes[12], 83);
      expect(meses.fold<int>(0, (s, m) => s + m.revenueReceivedCents!), 1000);
    });

    test('sem faturação declarada não escreve histórico nenhum', () {
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      completar(n);

      expect(c.read(operationsProvider).historicalMonths, isEmpty);
    });

    test(
      're-onboarding com um mês do ano já preenchido à mão não o '
      'sobrescreve',
      () {
        final c = container();
        addTearDown(c.dispose);
        final n = c.read(operationsProvider.notifier);
        final ano = DateTime.now().year - 1;
        n.saveHistoricalMonth(
          HistoricalMonth(
            year: ano,
            month: 3,
            revenueReceivedCents: 555555,
          ),
        );

        completar(n, revenueLastYearCents: 1200000);

        final meses = c.read(operationsProvider).historicalMonths;
        expect(meses, hasLength(1));
        expect(meses.single.revenueReceivedCents, 555555);
      },
    );

    test(
      'onboarding preenchido tira "Preencher o histórico mensal" das '
      'tarefas iniciais',
      () {
        final c = container();
        addTearDown(c.dispose);
        final n = c.read(operationsProvider.notifier);
        n.completeOnboarding(
          companyName: 'Alugueres Norte',
          legalForm: 'Lda.',
          hasFleet: false,
          collaborators: 0,
          totalMachinesDeclared: 0,
          insertMachinesNow: false,
          companyTaxId: '123456789',
          ownerName: 'Ana Costa',
          companyPhone: '912000000',
          companyAddress: 'Rua do Campo, 10',
          companyPostalCode: '1000-100',
          companyLocality: 'Lisboa',
          revenueLastYearCents: 1200000,
          revenueThisYearCents: 600000,
          maintenanceLastYearCents: 25000,
          fixedMonthlyCostsCents: 8000,
        );

        expect(
          c.read(operationsProvider).initialDataTasks,
          isNot(contains('Preencher o histórico mensal do ano passado')),
        );
      },
    );
  });

  test('um mês histórico só conta quando contém dados', () {
    const empty = HistoricalMonth(year: 2025, month: 5);
    const filled = HistoricalMonth(
      year: 2025,
      month: 5,
      revenueReceivedCents: 400000,
    );

    expect(empty.hasAnyData, isFalse);
    expect(filled.hasAnyData, isTrue);
  });

  test('histórico completo exige os 12 recebimentos mensais', () {
    final months = List.generate(
      12,
      (index) => HistoricalMonth(
        year: 2025,
        month: index + 1,
        revenueReceivedCents: 100000,
      ),
    );
    final complete = OperationsState(historicalMonths: months);
    final incomplete = OperationsState(
      historicalMonths: months.take(11).toList(),
    );

    expect(complete.hasFullRevenueHistoryFor(2025), isTrue);
    expect(incomplete.hasFullRevenueHistoryFor(2025), isFalse);
  });
}
