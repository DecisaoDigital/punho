import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/kpis/atencao.dart';
import 'package:punho/core/operations/kpis_da_cadeia.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';

/// **O caso que este ficheiro existe para resolver.**
///
/// Abril de 2026 na Depilconcept, tal como está semeado em produção por
/// `scripts/semear_historico_kpis.sql`: as vendas subiram 0,7% e o lucro passou
/// de +1 053 € para −48 €. A estrutura tinha saltado de 2 326 € para 3 234 €
/// (renda 450 → 620 €, salários 1 350 → 2 100 €).
///
/// Um painel que pintasse o lucro de vermelho e ficasse por aí mandava o gestor
/// procurar clientes — que é exactamente o trabalho errado. A app tem de saber
/// dizer: **as vendas mantiveram-se; o que subiu foi a estrutura**.
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

  /// Março (o mês de referência) e Abril (o mês mau), com a mesma procura e a
  /// estrutura a saltar.
  OperationsState abrilDeSustos() {
    final marco = DateTime(2026, 3, 15, 18);
    final abril = DateTime(2026, 4, 15, 18);
    return OperationsState(
      bookings: [venda('m-1', marco, 337900), venda('a-1', abril, 340200)],
      expenses: [
        // Estrutura de Março: renda + salários.
        despesa('d-m1', DateTime(2026, 3, 4), 45000, ExpenseCategory.rent),
        despesa('d-m2', DateTime(2026, 3, 4), 187600, ExpenseCategory.salaries),
        // Estrutura de Abril: os mesmos dois, muito mais caros.
        despesa('d-a1', DateTime(2026, 4, 4), 62000, ExpenseCategory.rent),
        despesa('d-a2', DateTime(2026, 4, 4), 261400, ExpenseCategory.salaries),
        // Consumíveis — custo directo, igual nos dois meses.
        despesa('c-m', DateTime(2026, 3, 4), 21000, ExpenseCategory.supplies),
        despesa('c-a', DateTime(2026, 4, 4), 21000, ExpenseCategory.supplies),
      ],
    );
  }

  final emAbril = DateTime(2026, 4, 30);

  group('a conta', () {
    test('o lucro é vendas menos tudo o que o mês custou', () {
      final estado = abrilDeSustos();
      // Abril: 3402 − (620 + 2614 + 210) = 3402 − 3444 = −42
      expect(lucroDoMes(estado, emAbril)!.valorCents, 340200 - 344400);
      // Março: 3379 − (450 + 1876 + 210) = 3379 − 2536 = +843
      expect(
        lucroDoMes(estado, DateTime(2026, 3, 31))!.valorCents,
        337900 - 253600,
      );
    });

    test('os efeitos das parcelas somam **exactamente** a queda do lucro', () {
      // É esta identidade que faz da explicação uma conta e não um palpite.
      // Se ela falhar, a app está a nomear um culpado ao acaso.
      final a = atencaoDoLucro(abrilDeSustos(), emAbril)!;
      final soma = a.parcelas.fold(0, (t, p) => t + p.efeitoCents);
      expect(soma, a.variacaoCents);
    });

    test('sem mês de referência não se explica nada', () {
      // Um primeiro mês de vida não tem com que comparar. Inventar uma
      // explicação aqui era pior do que não dizer nada.
      final so = OperationsState(
        bookings: [venda('x', DateTime(2026, 4, 15, 18), 100000)],
      );
      expect(atencaoDoLucro(so, emAbril), isNull);
    });
  });

  group('quem é o culpado', () {
    test('é a estrutura, e não as vendas', () {
      final a = atencaoDoLucro(abrilDeSustos(), emAbril)!;

      expect(a.piorou, isTrue);
      expect(a.responsavel.kpiId, 'estrutura-mes');
      expect(a.responsavel.deCents, 232600);
      expect(a.responsavel.paraCents, 323400);
    });

    test('as vendas aparecem do lado de quem ajudou', () {
      final a = atencaoDoLucro(abrilDeSustos(), emAbril)!;
      final vendas = a.parcelas.firstWhere((p) => p.kpiId == 'vendas-mes');

      expect(vendas.ajudou, isTrue, reason: 'subiram 23 €, por pouco que seja');
      expect(a.contraCorrente.map((p) => p.kpiId), contains('vendas-mes'));
    });

    test('a parcela responsável leva a um KPI a que se pode ir', () {
      // Sem `kpiId` a explicação era um beco: percebe-se a causa e não há como
      // ir vê-la.
      expect(
        atencaoDoLucro(abrilDeSustos(), emAbril)!.responsavel.kpiId,
        isNotNull,
      );
    });
  });

  group('a frase', () {
    test('nomeia a causa e diz que as vendas se mantiveram', () {
      final frase = fraseDaAtencao(atencaoDoLucro(abrilDeSustos(), emAbril)!);

      expect(frase, contains('O lucro caiu'));
      expect(frase, contains('a estrutura'));
      expect(
        frase,
        contains('as vendas'),
        reason: 'sem isto lê-se como se as vendas também tivessem corrido mal',
      );
      expect(frase, contains('mantiveram-se'));
    });

    test('traz sempre os números ao lado da afirmação', () {
      // «A estrutura subiu» sem quanto não se pode conferir contra nada.
      final frase = fraseDaAtencao(atencaoDoLucro(abrilDeSustos(), emAbril)!);
      expect(frase, contains('2326 € → 3234 €'));
    });

    test('compara com o mês passado quando não há ano passado', () {
      final a = atencaoDoLucro(abrilDeSustos(), emAbril)!;
      expect(a.homologo, isFalse);
      expect(fraseDaAtencao(a), contains('o mês passado'));
    });
  });

  group('os números que estão mesmo em produção', () {
    /// Abril de 2026 da Depilconcept, conferido contra a base a 13/8/2026 com
    /// a query que está em `docs/kpis/MAPA_DADOS.md` §7. Não são números
    /// inventados para o teste passar: são os que a app tem de saber explicar
    /// quando o César abrir o painel dela.
    ///
    /// | mês       | vendas | estrutura | directos | lucro |
    /// |-----------|-------:|----------:|---------:|------:|
    /// | 2025-04   |  3366  |    2113   |    618   |  635  |
    /// | 2026-04   |  3402  |    3003   |    447   |  −48  |
    OperationsState comoEstaNaBase() => OperationsState(
      bookings: [
        venda('h', DateTime(2025, 4, 15, 18), 336600),
        venda('a', DateTime(2026, 4, 15, 18), 340200),
      ],
      expenses: [
        despesa('h-e', DateTime(2025, 4, 4), 211296, ExpenseCategory.rent),
        despesa('h-d', DateTime(2025, 4, 4), 61848, ExpenseCategory.supplies),
        despesa('a-e', DateTime(2026, 4, 4), 300324, ExpenseCategory.rent),
        despesa('a-d', DateTime(2026, 4, 4), 44712, ExpenseCategory.supplies),
      ],
    );

    test('o lucro bate ao cêntimo com o que a base tem', () {
      final a = atencaoDoLucro(comoEstaNaBase(), emAbril)!;
      expect(a.lucroCents, -4836);
      expect(a.lucroDeReferenciaCents, 63456);
      expect(a.variacaoCents, -68292);
    });

    test('e a explicação é a estrutura, contra o Abril do ano passado', () {
      final a = atencaoDoLucro(comoEstaNaBase(), emAbril)!;

      expect(
        a.homologo,
        isTrue,
        reason: 'há 26 meses semeados, o ano passado existe',
      );
      expect(a.responsavel.kpiId, 'estrutura-mes');
      expect(a.responsavel.efeitoCents, 211296 - 300324);
      expect(a.parcelas.fold(0, (t, p) => t + p.efeitoCents), a.variacaoCents);
    });

    test('a frase que ele vai ler', () {
      expect(
        fraseDaAtencao(atencaoDoLucro(comoEstaNaBase(), emAbril)!),
        'O lucro caiu 683 € face ao mesmo mês do ano passado. '
        'O que mais subiu foi a estrutura: 890 € (2113 € → 3003 €). '
        'Já as vendas mantiveram-se.',
      );
    });
  });

  group('o homólogo ganha ao mês anterior', () {
    test('havendo ano passado, é com ele que se compara', () {
      // Um estúdio com estações: Abril do ano passado diz mais sobre Abril do
      // que Março diz.
      final comAnoPassado = OperationsState(
        bookings: [
          venda('h', DateTime(2025, 4, 15, 18), 336600),
          venda('m', DateTime(2026, 3, 15, 18), 337900),
          venda('a', DateTime(2026, 4, 15, 18), 340200),
        ],
        expenses: [
          despesa('h-d', DateTime(2025, 4, 4), 240600, ExpenseCategory.rent),
          despesa('m-d', DateTime(2026, 3, 4), 232600, ExpenseCategory.rent),
          despesa('a-d', DateTime(2026, 4, 4), 323400, ExpenseCategory.rent),
        ],
      );
      final a = atencaoDoLucro(comAnoPassado, emAbril)!;

      expect(a.homologo, isTrue);
      expect(a.lucroDeReferenciaCents, 336600 - 240600);
      expect(fraseDaAtencao(a), contains('o mesmo mês do ano passado'));
    });
  });
}
