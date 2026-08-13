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
///
/// **E a definição é dele, não minha.** A primeira versão separava custos de
/// estrutura de custos de servir o trabalho e dividia o alvo por uma margem de
/// contribuição. Foi corrigida no mesmo dia: *«a despeza é a despesa (...) o
/// breack even é o valor para manter a empresa em operaçao»*. O alvo é o que a
/// casa gasta num mês, todas as rubricas incluídas.
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
    test('o alvo é a despesa do mês, categoria nenhuma de fora', () {
      // Renda, consumíveis e combustível. A tentação era deixar os dois últimos
      // de fora por "variarem com o trabalho" — mas variam à volta de uma
      // média, e é essa média que se paga todos os meses.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 100000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
          despesa('d', DateTime(2026, 8, 5), 20000, ExpenseCategory.supplies),
          despesa('c', DateTime(2026, 8, 6), 5000, ExpenseCategory.fuel),
        ],
      );
      final be = breakEvenDoMes(estado, emAgosto)!;

      expect(be.alvoCents, 225000);
      expect(be.faltaCents, 125000);
      expect(be.atingido, isFalse);
    });

    test('vendendo o alvo, o lucro do mês dá zero', () {
      // É esta a ligação entre os dois KPIs: o break even é a despesa do mês e
      // o lucro é o que passa dela. Se um dia deixarem de bater, um deles está
      // a contar uma despesa que o outro não conta.
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 225000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 2), 200000, ExpenseCategory.rent),
          despesa('d', DateTime(2026, 8, 5), 20000, ExpenseCategory.supplies),
          despesa('c', DateTime(2026, 8, 6), 5000, ExpenseCategory.fuel),
        ],
      );

      expect(breakEvenDoMes(estado, emAgosto)!.faltaCents, 0);
      expect(lucroDoMes(estado, emAgosto)!.valorCents, 0);
    });

    test('sem despesa nenhuma, em mês nenhum, não se inventa um alvo', () {
      final estado = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 5, 18), 100000)],
      );
      expect(breakEvenDoMes(estado, emAgosto), isNull);
      expect(
        motivoSemBreakEven(estado, emAgosto),
        'Sem despesas registadas — neste mês nem nos anteriores',
      );
    });
  });

  group('de onde vem o alvo', () {
    /// Três meses com 2 000 € de renda e 200 € de consumíveis cada.
    OperationsState comTresMeses({
      List<Expense> agosto = const [],
    }) => OperationsState(
      bookings: [
        venda('m', DateTime(2026, 5, 10, 18), 300000),
        venda('j', DateTime(2026, 6, 10, 18), 300000),
        venda('l', DateTime(2026, 7, 10, 18), 300000),
        venda('a', DateTime(2026, 8, 1, 18), 50000),
      ],
      expenses: [
        despesa('m1', DateTime(2026, 5, 3), 200000, ExpenseCategory.rent),
        despesa('m2', DateTime(2026, 5, 9), 20000, ExpenseCategory.supplies),
        despesa('j1', DateTime(2026, 6, 3), 200000, ExpenseCategory.rent),
        despesa('j2', DateTime(2026, 6, 9), 20000, ExpenseCategory.supplies),
        despesa('l1', DateTime(2026, 7, 3), 200000, ExpenseCategory.rent),
        despesa('l2', DateTime(2026, 7, 9), 20000, ExpenseCategory.supplies),
        ...agosto,
      ],
    );

    test('a renda por lançar não faz o mês parecer barato', () {
      // O defeito que a média corrige: sem ela, a 2 de Agosto o alvo era zero e
      // o mês aparecia pago à primeira venda. Depois a renda entrava e o break
      // even saltava — o alvo mexia-se debaixo dos pés do gestor.
      final be = breakEvenDoMes(comTresMeses(), DateTime(2026, 8, 2, 10))!;

      expect(be.despesaLancadaCents, 0);
      expect(be.alvoCents, 220000, reason: 'a média dos três meses');
      expect(be.origem, OrigemDoAlvo.media);
      expect(be.atingido, isFalse);
    });

    test('lançada a despesa, é ela que manda — a média sai da frente', () {
      final be = breakEvenDoMes(
        comTresMeses(
          agosto: [
            despesa('a1', DateTime(2026, 8, 4), 260000, ExpenseCategory.rent),
          ],
        ),
        DateTime(2026, 8, 10, 10),
      );

      expect(be!.alvoCents, 260000);
      expect(
        be.origem,
        OrigemDoAlvo.lancado,
        reason: 'um mês com uma despesa maior não se lê pela média dos normais',
      );
    });

    test('a média não conta meses em branco como meses de 0 € de renda', () {
      // Maio e Junho sem uma despesa lançada. A média tem de ser 2 200 € (só
      // Julho), não 733 € — um mês por preencher não é um mês barato.
      final estado = OperationsState(
        bookings: [venda('l', DateTime(2026, 7, 10, 18), 300000)],
        expenses: [
          despesa('l1', DateTime(2026, 7, 3), 200000, ExpenseCategory.rent),
          despesa('l2', DateTime(2026, 7, 9), 20000, ExpenseCategory.supplies),
        ],
      );
      final be = breakEvenDoMes(estado, DateTime(2026, 8, 2, 10))!;

      expect(be.alvoCents, 220000);
    });

    test('sem histórico, servem os custos fixos declarados', () {
      // Empresa no primeiro mês: não há passado de onde tirar a média, mas ela
      // declarou o que paga. Ignorá-lo era pedir-lhe informação duas vezes.
      const estado = OperationsState(
        custosFixos: [
          CustoFixo(
            id: 'f1',
            categoria: ExpenseCategory.rent,
            valorCents: 180000,
          ),
          CustoFixo(
            id: 'f2',
            categoria: ExpenseCategory.electricity,
            valorCents: 40000,
          ),
        ],
      );
      final be = breakEvenDoMes(estado, DateTime(2026, 8, 2, 10))!;

      expect(be.alvoCents, 220000);
      expect(be.origem, OrigemDoAlvo.declarado);
      expect(be.estimado, isTrue);
    });
  });

  group('o dia em que o mês vira', () {
    test('já passou: diz o dia exacto, contado venda a venda', () {
      // 3 vendas de 1000 €, alvo nos 2400 €: passa na terceira, que acabou a
      // 20. Uma média diária diria outro dia qualquer.
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
      // 1000 € vendidos em 10 dias = 100 €/dia. Alvo nos 2000 € → dia 20.
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
    /// ecrã. Vendas 2 643 €, despesa lançada 2 321 €.
    ///
    /// A despesa dos três meses anteriores, também da base: 2 356,94 € em Maio,
    /// 2 344,96 € em Junho, 2 522,09 € em Julho. A média dá 2 407,99 € —
    /// **acima** dos 2 321 € já lançados em Agosto, e por isso é ela o alvo.
    OperationsState comoEstaNaBase() => OperationsState(
      bookings: [venda('a', DateTime(2026, 8, 6, 18), 264300)],
      expenses: [
        despesa('m', DateTime(2026, 5, 4), 235694, ExpenseCategory.rent),
        despesa('j', DateTime(2026, 6, 4), 234496, ExpenseCategory.rent),
        despesa('l', DateTime(2026, 7, 4), 252209, ExpenseCategory.rent),
        despesa('e', DateTime(2026, 8, 4), 211100, ExpenseCategory.rent),
        despesa('d', DateTime(2026, 8, 4), 21000, ExpenseCategory.supplies),
      ],
    );

    test('o lucro é o que ele viu no ecrã', () {
      expect(lucroDoMes(comoEstaNaBase(), emAgosto)!.valorCents, 32200);
    });

    test('e o mês já se paga — o alvo ficou nos 2408 €', () {
      final be = breakEvenDoMes(comoEstaNaBase(), emAgosto)!;

      expect(be.despesaLancadaCents, 232100);
      expect(be.alvoCents, 240799);
      expect(be.origem, OrigemDoAlvo.media);
      expect(be.atingido, isTrue);
      expect(
        be.diaEmQuePassou,
        6,
        reason: 'a única venda do mês acabou a 6 de Agosto',
      );
    });
  });
}
