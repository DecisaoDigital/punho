import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';

/// **As duas células do lucro, e porque são duas.**
///
/// Pedido do César a 13 de Agosto de 2026: *«quero um Kpi do lucro do mes
/// anterior e um kpi com o lucro até ao momento do mes, lucro ou prejuiso»*.
///
/// Não são o mesmo número visto de dois sítios. O mês a decorrer tem a
/// estrutura toda lá dentro logo nos primeiros dias e as vendas a meio — a dia
/// 13 lê-se mal se não se disser que é dia 13. O mês anterior é o único mês
/// inteiro, e por isso o único que se compara sem ressalvas.
///
/// Os números são os da Depilconcept em produção: Agosto vai em +322 €, Julho
/// fechou em +1 540 €.
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

  CelulaSemaforo celula(String id, OperationsState s, DateTime now) =>
      kpiPorId(id)!.celula(s, now);

  final emAgosto = DateTime(2026, 8, 13, 21);

  OperationsState comoEstaNaBase() => OperationsState(
    bookings: [
      venda('a', DateTime(2026, 8, 6, 18), 264300),
      venda('j', DateTime(2026, 7, 10, 18), 406200),
    ],
    expenses: [
      despesa('ae', DateTime(2026, 8, 4), 211100, ExpenseCategory.rent),
      despesa('ad', DateTime(2026, 8, 4), 21000, ExpenseCategory.supplies),
      despesa('je', DateTime(2026, 7, 4), 211800, ExpenseCategory.rent),
      despesa('jd', DateTime(2026, 7, 4), 40400, ExpenseCategory.supplies),
    ],
  );

  group('o mês a decorrer', () {
    test('diz que é lucro, e que é até hoje', () {
      final c = celula('lucro-mes', comoEstaNaBase(), emAgosto);

      expect(c.valor, '+ 322');
      expect(c.unidade, '€ de lucro até hoje');
    });

    test('e diz prejuízo quando é prejuízo — sem eufemismo', () {
      // Um mês com a renda lançada e uma venda pequena. «− 1 811 €» sozinho
      // obriga a reparar no sinal; a palavra não deixa passar ao lado.
      final so = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 6, 18), 30000)],
        expenses: [
          despesa('e', DateTime(2026, 8, 4), 211100, ExpenseCategory.rent),
        ],
      );
      final c = celula('lucro-mes', so, emAgosto);

      expect(c.valor, '− 1811');
      expect(c.unidade, '€ de prejuízo até hoje');
      expect(c.nivel, NivelSemaforo.vermelho);
    });

    test('a margem passou para a sub-linha, e não se perdeu', () {
      final c = celula('lucro-mes', comoEstaNaBase(), emAgosto);
      expect(c.subtexto, startsWith('Margem 12%'));
    });
  });

  group('o mês anterior', () {
    test('é o mês fechado, com o nome escrito', () {
      final c = celula('lucro-mes-anterior', comoEstaNaBase(), emAgosto);

      expect(c.valor, '+ 1540');
      expect(c.unidade, '€ de lucro em Julho');
    });

    test('em Janeiro vai buscar Dezembro do ano passado', () {
      // A volta ao ano é onde uma conta de meses parte em silêncio: um índice
      // negativo ou um mês 0 dão «em undefined» ou um mês errado, e só se dá
      // por isso em Janeiro.
      final natal = OperationsState(
        bookings: [venda('d', DateTime(2025, 12, 20, 18), 500000)],
        expenses: [
          despesa('e', DateTime(2025, 12, 4), 200000, ExpenseCategory.rent),
        ],
      );
      final c = celula('lucro-mes-anterior', natal, DateTime(2026, 1, 15, 10));

      expect(c.valor, '+ 3000');
      expect(c.unidade, '€ de lucro em Dezembro');
    });

    test('sem registos no mês passado, não mostra zero', () {
      final so = OperationsState(
        bookings: [venda('a', DateTime(2026, 8, 6, 18), 264300)],
      );
      final c = celula('lucro-mes-anterior', so, emAgosto);

      expect(c.nivel, NivelSemaforo.aguarda);
      expect(c.texto, 'Sem registos em Julho');
      expect(c.valor, isNull, reason: '0 € seria dizer que Julho correu mal');
    });
  });

  group('a comparação traz o valor, não só a percentagem', () {
    test('o termo escreve-se em euros', () {
      // «▼ 80%» obriga a fazer a conta de cabeça para saber de onde se caiu.
      final comAnoPassado = OperationsState(
        bookings: [
          venda('h', DateTime(2025, 8, 10, 18), 403100),
          venda('a', DateTime(2026, 8, 6, 18), 264300),
        ],
        expenses: [
          despesa('he', DateTime(2025, 8, 4), 217400, ExpenseCategory.rent),
          despesa('ae', DateTime(2026, 8, 4), 211100, ExpenseCategory.rent),
        ],
      );
      final c = celula('lucro-mes', comAnoPassado, emAgosto);

      expect(c.subtexto, contains('1857 € do ano passado'));
    });
  });
}
