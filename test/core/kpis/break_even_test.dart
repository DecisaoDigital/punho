import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/kpis/break_even.dart';
import 'package:punho/core/operations/kpis_da_cadeia.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';

/// **O caso que este ficheiro existe para resolver.**
///
/// O César, a 13 de Agosto de 2026, a olhar para um Lucro do mês de 322 € que
/// eu queria "corrigir" por estar a comparar 13 dias com um mês inteiro:
/// *«não faz mal, porque é o previsto até hoje. poderia ser negativo ainda não
/// se ter feito o break even do mês»*.
///
/// A conta não estava errada — faltava-lhe o par. A meio do mês a estrutura já
/// entrou toda e as vendas ainda vão a meio; o que diz se o mês virou não é o
/// lucro, é **quanto falta vender para ele se pagar**.
void main() {
  Booking venda(String id, DateTime fim, int cents) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: fim.subtract(const Duration(hours: 9)),
    endsAt: fim,
    status: BookingStatus.completed,
    expectedValueCents: cents,
  );

  Expense despesa(String id, DateTime data, int cents, ExpenseCategory cat) =>
      Expense(
        id: id,
        date: data,
        amountCents: cents,
        category: cat,
        status: ExpensePaymentStatus.paid,
      );

  final emAgosto = DateTime(2026, 8, 13, 21);

  group('a conta', () {
    test('vendendo o break even, o lucro do mês dá zero', () {
      // É esta a prova de que a conta é uma identidade e não uma regra de três
      // simples: leva-se o estado até às vendas necessárias e confirma-se que
      // o lucro fecha em zero, com os custos directos a acompanhar.
      final estrutura = 200000;
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 100000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), estrutura, ExpenseCategory.rent),
          despesa('d', DateTime(2026, 8, 5), 20000, ExpenseCategory.supplies),
        ],
      );
      final be = breakEvenDoMes(estado, emAgosto)!;

      // Margem de contribuição: (100000 − 20000) / 100000 = 0,8
      expect(be.margemDeContribuicao, closeTo(0.8, 0.0001));
      expect(be.vendasNecessariasCents, 250000); // 200000 / 0,8

      // Ao vender as necessárias, com os directos na mesma proporção:
      final directosNoAlvo = (250000 * (1 - be.margemDeContribuicao)).round();
      expect(250000 - estrutura - directosNoAlvo, 0);
    });

    test('sem despesas de estrutura não há alvo a cobrir', () {
      // Um mês só com consumíveis não tem casa para pagar — inventar um break
      // even aqui era inventar um custo que ninguém lançou.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 100000)],
        expenses: [
          despesa('d', DateTime(2026, 8, 5), 20000, ExpenseCategory.supplies),
        ],
      );
      expect(breakEvenDoMes(estado, emAgosto), isNull);
      expect(
        motivoSemBreakEven(estado, emAgosto),
        'Sem despesas de estrutura lançadas este mês',
      );
    });

    test('margem negativa: não há volume de vendas que pague o mês', () {
      // Vendeu 500 € e gastou 700 € em consumíveis. Dizer "faltam X €" aqui era
      // mandar o gestor trabalhar mais para perder mais.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 50000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
          despesa('d', DateTime(2026, 8, 5), 70000, ExpenseCategory.supplies),
        ],
      );
      final be = breakEvenDoMes(estado, emAgosto)!;

      expect(be.margemDeContribuicao, lessThan(0));
      expect(be.vendasNecessariasCents, isNull);
      expect(be.faltaCents, isNull);
      expect(be.atingido, isFalse);
    });
  });

  group('quando ainda não há vendas este mês', () {
    /// Dia 2 do mês: a renda já entrou, ainda não acabou trabalho nenhum.
    OperationsState comHistorico() => OperationsState(
      bookings: [
        venda('j1', DateTime(2026, 7, 10, 18), 300000),
        venda('j2', DateTime(2026, 6, 10, 18), 100000),
      ],
      expenses: [
        despesa('jd', DateTime(2026, 7, 5), 60000, ExpenseCategory.supplies),
        despesa('id', DateTime(2026, 6, 5), 20000, ExpenseCategory.supplies),
        despesa('ae', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
      ],
    );

    test('empresta a margem dos meses anteriores, e diz que é emprestada', () {
      final be = breakEvenDoMes(comHistorico(), DateTime(2026, 8, 2, 10))!;

      // Agregada, não média de percentagens: (400000 − 80000) / 400000 = 0,8.
      expect(be.margemDeContribuicao, closeTo(0.8, 0.0001));
      expect(be.margemDoProprioMes, isFalse);
      expect(be.vendasNecessariasCents, 250000);
      expect(be.faltaCents, 250000, reason: 'ainda não vendeu nada');
    });

    test('sem vendas em mês nenhum, cala-se e diz porquê', () {
      final estado = OperationsState(
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
        ],
      );
      expect(breakEvenDoMes(estado, emAgosto), isNull);
      expect(
        motivoSemBreakEven(estado, emAgosto),
        'Ainda não há vendas — deste mês nem dos anteriores',
      );
    });
  });

  group('o dia em que o mês vira', () {
    test('já passou: diz o dia exacto, contado venda a venda', () {
      // 3 vendas de 1000 €, break even nos 2500 €: passa na terceira, que
      // acabou a 20. Uma média diária diria outro dia qualquer.
      final estado = OperationsState(
        bookings: [
          venda('a', DateTime(2026, 8, 4, 18), 100000),
          venda('b', DateTime(2026, 8, 11, 18), 100000),
          venda('c', DateTime(2026, 8, 20, 18), 100000),
        ],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 240000, ExpenseCategory.rent),
        ],
      );
      final be = breakEvenDoMes(estado, DateTime(2026, 8, 25, 21))!;

      expect(be.atingido, isTrue);
      expect(be.diaEmQuePassou, 20);
      expect(be.diaPrevisto, isNull, reason: 'já não se prevê o que aconteceu');
    });

    test('ainda não passou: projecta pelo ritmo, e só dentro do mês', () {
      // 1000 € vendidos em 10 dias = 100 €/dia. Break even nos 2000 € → dia 20.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 100000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
        ],
      );
      final be = breakEvenDoMes(estado, DateTime(2026, 8, 10, 21))!;

      expect(be.atingido, isFalse);
      expect(be.faltaCents, 100000);
      expect(be.diaPrevisto, 20);
    });

    test('ao ritmo de hoje não chega este mês: não aponta um dia que não há', () {
      // 100 € em 10 dias, com 2000 € a pagar. Ao ritmo actual precisava de 200
      // dias — dizer "chega a 200 de Agosto" era ruído, e "chega em Março" era
      // uma promessa que este KPI não faz.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 10000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
        ],
      );
      final be = breakEvenDoMes(estado, DateTime(2026, 8, 10, 21))!;

      expect(be.atingido, isFalse);
      expect(be.diaPrevisto, isNull);
    });
  });

  group('os números que estão mesmo em produção', () {
    /// Agosto de 2026 da Depilconcept, conferido contra a base a 13/8/2026 —
    /// e conferido **no telemóvel** pelo César, que leu 322 € de lucro no
    /// ecrã. Vendas 2643 €, estrutura 2111 €, directos 210 €.
    OperationsState comoEstaNaBase() => OperationsState(
      bookings: [venda('a', DateTime(2026, 8, 6, 18), 264300)],
      expenses: [
        despesa('e', DateTime(2026, 8, 4), 211100, ExpenseCategory.rent),
        despesa('d', DateTime(2026, 8, 4), 21000, ExpenseCategory.supplies),
      ],
    );

    test('o lucro é o que ele viu no ecrã', () {
      expect(lucroDoMes(comoEstaNaBase(), emAgosto)!.valorCents, 32200);
    });

    test('e o mês já se paga — o break even ficou nos 2293 €', () {
      final be = breakEvenDoMes(comoEstaNaBase(), emAgosto)!;

      expect(be.margemDeContribuicao, closeTo(0.9205, 0.0001));
      expect(be.margemDoProprioMes, isTrue);
      expect((be.vendasNecessariasCents! / 100).round(), 2293);
      expect(be.atingido, isTrue);
      expect(
        be.diaEmQuePassou,
        6,
        reason: 'a única venda do mês acabou a 6 de Agosto',
      );
    });
  });
}
