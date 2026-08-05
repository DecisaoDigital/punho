import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/caixa.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';

/// A Caixa é a conta mais simples da app e é por isso que tem de estar certa.
///
/// Duas regras, e as duas existem para não enganar quem lê: o valor grande é
/// **só deste mês**, e o que vinha de trás vai à parte. Somar as duas coisas
/// faz um mês mau parecer bom por causa de uma almofada antiga.
void main() {
  Receipt recebimento(String id, DateTime data, int cents) => Receipt(
    id: id,
    customerId: 'c1',
    date: data,
    amountCents: cents,
    method: PaymentMethod.transfer,
  );

  Expense despesa(
    String id,
    DateTime data,
    int cents, {
    ExpensePaymentStatus estado = ExpensePaymentStatus.paid,
  }) => Expense(
    id: id,
    date: data,
    amountCents: cents,
    category: ExpenseCategory.other,
    status: estado,
    description: 'despesa',
  );

  OperationsState estado({
    List<Receipt> recebimentos = const [],
    List<Expense> despesas = const [],
  }) => OperationsState(receipts: recebimentos, expenses: despesas);

  final hoje = DateTime(2026, 8, 5);

  test('entrou menos saiu, do dia 1 até hoje', () {
    final caixa = caixaDoMes(
      estado(
        recebimentos: [
          recebimento('r1', DateTime(2026, 8, 2), 50000),
          recebimento('r2', DateTime(2026, 8, 5), 30000),
        ],
        despesas: [despesa('d1', DateTime(2026, 8, 3), 20000)],
      ),
      hoje,
    );

    expect(caixa.entradasCents, 80000);
    expect(caixa.saidasCents, 20000);
    expect(caixa.saldoCents, 60000);
    expect(caixa.semMovimentos, isFalse);
  });

  test('o dia de hoje conta — não se corta às zero horas', () {
    // Um recebimento lançado hoje de manhã já é dinheiro que entrou.
    final caixa = caixaDoMes(
      estado(recebimentos: [recebimento('r1', hoje, 12345)]),
      hoje,
    );

    expect(caixa.entradasCents, 12345);
  });

  test('o que ainda não aconteceu não entra na caixa', () {
    // Uma transferência agendada e registada com data futura inflaria o mês
    // antes de o dinheiro existir. O limite é hoje, não o fim do mês.
    final caixa = caixaDoMes(
      estado(
        recebimentos: [
          recebimento('r1', DateTime(2026, 8, 4), 10000),
          recebimento('futuro', DateTime(2026, 8, 20), 999999),
        ],
      ),
      hoje,
    );

    expect(caixa.entradasCents, 10000);
  });

  test('o mês passado não se mistura com este', () {
    final caixa = caixaDoMes(
      estado(
        recebimentos: [
          recebimento('julho', DateTime(2026, 7, 28), 90000),
          recebimento('agosto', DateTime(2026, 8, 1), 10000),
        ],
        despesas: [despesa('julho-d', DateTime(2026, 7, 30), 20000)],
      ),
      hoje,
    );

    // O grande é só de Agosto...
    expect(caixa.entradasCents, 10000);
    expect(caixa.saidasCents, 0);
    expect(caixa.saldoCents, 10000);
    // ...e o de trás está lá, à parte: 900 − 200.
    expect(caixa.acumuladoAnteriorCents, 70000);
  });

  test('despesa por pagar não é saída de caixa', () {
    // Dever não é ter pago. A caixa conta o que saiu da conta.
    final caixa = caixaDoMes(
      estado(
        recebimentos: [recebimento('r1', DateTime(2026, 8, 2), 50000)],
        despesas: [
          despesa(
            'd1',
            DateTime(2026, 8, 3),
            40000,
            estado: ExpensePaymentStatus.unpaid,
          ),
        ],
      ),
      hoje,
    );

    expect(caixa.saidasCents, 0);
    expect(caixa.saldoCents, 50000);
  });

  test('sem histórico nenhum, o acumulado não existe — não é zero', () {
    // "0 €" leria-se como "estava a zero". A verdade é não haver registo.
    final caixa = caixaDoMes(
      estado(recebimentos: [recebimento('r1', DateTime(2026, 8, 2), 5000)]),
      hoje,
    );

    expect(caixa.acumuladoAnteriorCents, isNull);
  });

  test('acumulado negativo diz-se como é', () {
    final caixa = caixaDoMes(
      estado(despesas: [despesa('d1', DateTime(2026, 6, 10), 30000)]),
      hoje,
    );

    expect(caixa.acumuladoAnteriorCents, -30000);
  });

  test('mês sem nada não inventa um zero', () {
    final caixa = caixaDoMes(
      estado(recebimentos: [recebimento('r1', DateTime(2026, 7, 2), 5000)]),
      hoje,
    );

    expect(caixa.semMovimentos, isTrue);
    // E o de trás continua a saber-se.
    expect(caixa.acumuladoAnteriorCents, 5000);
  });

  test('o período que se mostra é o que se contou', () {
    final caixa = caixaDoMes(estado(), hoje);

    expect(caixa.mes, DateTime(2026, 8));
    expect(caixa.ate, DateTime(2026, 8, 5));
  });
}
