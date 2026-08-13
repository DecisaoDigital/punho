import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/kpis/dinheiro_por_mexer.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';

/// **O espaço entre vender e receber, que é onde vive a tesouraria.**
///
/// A app sabia dizer quanto se vendeu e quanto entrou na conta. Faltavam as duas
/// pontas do dinheiro que ainda não mexeu: o que já devia ter entrado e não
/// entrou, e o que ainda tem de sair.
///
/// A regra que estes testes guardam, e que é a razão de a célula existir: as
/// «Cobranças a vencer (7d)» **misturam** — o filtro delas não tem piso, e por
/// isso a factura de há três meses está lá dentro somada à que vence na sexta.
/// Aqui é só o que passou do prazo.
void main() {
  final hoje = DateTime(2026, 8, 13, 21);

  Booking trabalho(
    String id,
    DateTime fim,
    int cents, {
    String cliente = 'c1',
    String nome = 'Herdade do Vale',
    BookingStatus status = BookingStatus.completed,
  }) => Booking(
    id: id,
    customerId: cliente,
    customerNameSnapshot: nome,
    machineIds: const ['m1'],
    startsAt: fim.subtract(const Duration(days: 2)),
    endsAt: fim,
    status: status,
    expectedValueCents: cents,
  );

  Receipt recebido(String bookingId, int cents) => Receipt(
    id: 'r-$bookingId',
    date: DateTime(2026, 8, 12),
    amountCents: cents,
    customerId: 'c1',
    method: PaymentMethod.transfer,
    bookingId: bookingId,
  );

  Expense despesa(
    String id,
    DateTime data,
    int cents, {
    ExpensePaymentStatus status = ExpensePaymentStatus.unpaid,
    ExpenseCategory categoria = ExpenseCategory.rent,
    bool archived = false,
  }) => Expense(
    id: id,
    date: data,
    amountCents: cents,
    category: categoria,
    status: status,
    archived: archived,
  );

  group('em atraso', () {
    test('o que acaba hoje ainda não está atrasado', () {
      // A fronteira. O trabalho acabou esta manhã e o cliente não pagou — não é
      // uma cobrança falhada, e a outra célula já o pinta de vermelho no «vence
      // hoje». Dar-lhe atraso aqui era acusar quem não fez nada de mal.
      final estado = OperationsState(
        bookings: [trabalho('a', DateTime(2026, 8, 13, 18), 50000)],
      );

      expect(cobrancasVencidas(estado, hoje), isNull);
      final celula = kpiCobrancasEmAtraso(estado, hoje);
      expect(celula.nivel, NivelSemaforo.verde);
      expect(celula.texto, 'Ninguém em atraso');
    });

    test('o de ontem já conta, e conta um dia', () {
      final estado = OperationsState(
        bookings: [trabalho('a', DateTime(2026, 8, 12, 18), 50000)],
      );
      final v = cobrancasVencidas(estado, hoje)!;

      expect(v.totalCents, 50000);
      expect(v.diasDoMaisAntigo, 1);
      expect(v.grave, isFalse);
      expect(kpiCobrancasEmAtraso(estado, hoje).nivel, NivelSemaforo.laranja);
      expect(
        kpiCobrancasEmAtraso(estado, hoje).subtexto,
        'A mais velha é de Herdade do Vale, há 1 dia · 500 €',
      );
    });

    test('um mês sem pagar já não é um esquecimento', () {
      final estado = OperationsState(
        bookings: [trabalho('a', DateTime(2026, 7, 10, 18), 50000)],
      );

      expect(cobrancasVencidas(estado, hoje)!.grave, isTrue);
      expect(kpiCobrancasEmAtraso(estado, hoje).nivel, NivelSemaforo.vermelho);
    });

    test('só o que falta receber, e não o valor do trabalho', () {
      final estado = OperationsState(
        bookings: [trabalho('a', DateTime(2026, 8, 1, 18), 50000)],
        receipts: [recebido('a', 30000)],
      );

      expect(cobrancasVencidas(estado, hoje)!.totalCents, 20000);
    });

    test('diz quantos clientes, porque 2000 € de um só é outro problema', () {
      // Um valor grande de um cliente é um telefonema; espalhado por três é um
      // processo de cobrança que não existe.
      final estado = OperationsState(
        bookings: [
          trabalho('a', DateTime(2026, 8, 5, 18), 50000),
          trabalho('b', DateTime(2026, 8, 6, 18), 50000, cliente: 'c2'),
          trabalho('c', DateTime(2026, 8, 7, 18), 50000, cliente: 'c2'),
        ],
      );

      expect(cobrancasVencidas(estado, hoje)!.clientes, 2);
      expect(kpiCobrancasEmAtraso(estado, hoje).unidade, '€ · 2 clientes');
    });

    test('uma reserva cancelada não deve dinheiro nenhum', () {
      final estado = OperationsState(
        bookings: [
          trabalho(
            'a',
            DateTime(2026, 7, 1, 18),
            50000,
            status: BookingStatus.cancelled,
          ),
        ],
      );

      expect(cobrancasVencidas(estado, hoje), isNull);
      // E sem mais nenhuma reserva com valor, a célula fica à espera de dados em
      // vez de dizer que está tudo bem: não há de onde vir uma cobrança.
      expect(kpiCobrancasEmAtraso(estado, hoje).nivel, NivelSemaforo.aguarda);
    });

    test('o trabalho a decorrer é dinheiro a caminho, não dívida', () {
      final estado = OperationsState(
        bookings: [trabalho('a', DateTime(2026, 8, 20, 18), 50000)],
      );

      expect(cobrancasVencidas(estado, hoje), isNull);
      expect(kpiCobrancasEmAtraso(estado, hoje).nivel, NivelSemaforo.verde);
    });
  });

  group('contas a pagar', () {
    test('conta as de meses anteriores — a dívida não vira com o calendário', () {
      // Era o defeito a evitar: limitar ao mês corrente fazia a factura de Junho
      // desaparecer do ecrã no dia 1 de Julho sem ter sido paga.
      final estado = OperationsState(
        expenses: [
          despesa('junho', DateTime(2026, 6, 5), 80000),
          despesa('agosto', DateTime(2026, 8, 4), 20000),
        ],
      );
      final c = contasAPagar(estado, hoje)!;

      expect(c.totalCents, 100000);
      expect(c.quantas, 2);
      expect(c.maisAntiga.id, 'junho');
      expect(c.velha, isTrue, reason: '69 dias por pagar');
      expect(kpiContasAPagar(estado, hoje).nivel, NivelSemaforo.vermelho);
    });

    test('a paga e a arquivada ficam de fora', () {
      final estado = OperationsState(
        expenses: [
          despesa(
            'paga',
            DateTime(2026, 8, 2),
            80000,
            status: ExpensePaymentStatus.paid,
          ),
          despesa('fora', DateTime(2026, 8, 3), 90000, archived: true),
          despesa('esta', DateTime(2026, 8, 10), 15000),
        ],
      );
      final c = contasAPagar(estado, hoje)!;

      expect(c.totalCents, 15000);
      expect(c.quantas, 1);
      expect(kpiContasAPagar(estado, hoje).unidade, '€ · 1 despesa');
      expect(kpiContasAPagar(estado, hoje).nivel, NivelSemaforo.laranja);
    });

    test('tudo pago é verde, e não «aguarda»', () {
      // **O que se vai ver em produção.** A semente marca todas as despesas como
      // pagas no próprio dia (ver `docs/kpis/HANDOVER.md`, ponto 3), portanto
      // esta célula vai dizer «Nada por pagar» na Depilconcept. Está certa: os
      // dados é que não têm nada por pagar. Se dissesse «aguarda», lia-se como
      // se a app não soubesse.
      final estado = OperationsState(
        expenses: [
          despesa(
            'paga',
            DateTime(2026, 8, 2),
            80000,
            status: ExpensePaymentStatus.paid,
          ),
        ],
      );

      expect(contasAPagar(estado, hoje), isNull);
      final celula = kpiContasAPagar(estado, hoje);
      expect(celula.nivel, NivelSemaforo.verde);
      expect(celula.texto, 'Nada por pagar');
    });

    test('sem uma despesa registada, a célula diz o que lhe falta', () {
      const estado = OperationsState();
      expect(kpiContasAPagar(estado, hoje).nivel, NivelSemaforo.aguarda);
    });

    test('a mais velha vem com a rubrica, para se saber a quem se liga', () {
      final estado = OperationsState(
        expenses: [
          despesa(
            'luz',
            DateTime(2026, 8, 3),
            9000,
            categoria: ExpenseCategory.electricity,
          ),
        ],
      );

      expect(
        kpiContasAPagar(estado, hoje).subtexto,
        'A mais velha é de electricidade, há 10 dias',
      );
    });
  });
}
