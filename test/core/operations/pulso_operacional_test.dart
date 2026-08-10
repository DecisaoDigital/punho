import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';

/// KPIs do slide 2 · o pulso do dia.
///
/// O `now` entra sempre de fora: sem isso a suite mudava de resultado com o dia
/// em que corre, e um teste que só passa às terças não é um teste.
void main() {
  final agora = DateTime(2026, 7, 15, 10, 30);
  DateTime dia(int d) => DateTime(2026, 7, d);

  Booking reserva({
    required String id,
    required int comeca,
    required int acaba,
    BookingStatus status = BookingStatus.confirmed,
    int? valorCents,
    String cliente = 'c1',
  }) => Booking(
    id: id,
    customerId: cliente,
    machineIds: const ['m1'],
    startsAt: dia(comeca),
    endsAt: dia(acaba),
    status: status,
    expectedValueCents: valorCents,
  );

  OperationsState com(
    List<Booking> reservas, {
    List<Receipt> recibos = const [],
  }) => OperationsState(
    onboarded: true,
    companyName: 'Alugueres Norte',
    bookings: reservas,
    receipts: recibos,
  );

  group('sem dados', () {
    test('empresa sem reservas nenhumas assinala falta de dados', () {
      final p = pulsoOperacional(com(const []), agora);

      expect(p.semDados, isTrue);
    });

    test('com reservas registadas deixa de ser falta de dados', () {
      // Um dia sem trabalho é uma boa notícia, não um buraco. A distinção é o
      // que impede a app de dizer "0 entregas" a quem nunca registou nada.
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'b1',
            comeca: 1,
            acaba: 2,
            status: BookingStatus.completed,
          ),
        ]),
        agora,
      );

      expect(p.semDados, isFalse);
      expect(p.entregasHoje, 0);
    });
  });

  group('reservas activas', () {
    test('conta as que envolvem o dia de hoje', () {
      final p = pulsoOperacional(
        com([
          reserva(id: 'a', comeca: 10, acaba: 20, status: BookingStatus.rented),
          reserva(id: 'b', comeca: 15, acaba: 15),
          reserva(id: 'fora', comeca: 20, acaba: 25),
          reserva(
            id: 'passada',
            comeca: 1,
            acaba: 5,
            status: BookingStatus.completed,
          ),
        ]),
        agora,
      );

      expect(p.reservasActivas, 2);
    });

    test('as canceladas nunca contam', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'x',
            comeca: 10,
            acaba: 20,
            status: BookingStatus.cancelled,
          ),
        ]),
        agora,
      );

      expect(p.reservasActivas, 0);
    });

    test('assinala as que terminam dentro de 48h', () {
      final p = pulsoOperacional(
        com([
          reserva(id: 'ja', comeca: 10, acaba: 16),
          reserva(id: 'longe', comeca: 10, acaba: 30),
        ]),
        agora,
      );

      expect(p.reservasActivas, 2);
      expect(p.reservasATerminar48h, 1);
    });
  });

  group('entregas', () {
    test('conta as que começam hoje e separa as que ainda não saíram', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'saiu',
            comeca: 15,
            acaba: 18,
            status: BookingStatus.rented,
          ),
          reserva(id: 'por-sair', comeca: 15, acaba: 18),
          reserva(id: 'amanha', comeca: 16, acaba: 18),
        ]),
        agora,
      );

      expect(p.entregasHoje, 2);
      expect(p.entregasPorFazer, 1);
    });
  });

  group('recolhas', () {
    test('conta as de hoje e as das próximas 48h', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'hoje',
            comeca: 10,
            acaba: 15,
            status: BookingStatus.rented,
          ),
          reserva(
            id: 'amanha',
            comeca: 10,
            acaba: 16,
            status: BookingStatus.rented,
          ),
          reserva(
            id: 'longe',
            comeca: 10,
            acaba: 25,
            status: BookingStatus.rented,
          ),
        ]),
        agora,
      );

      expect(p.recolhasHoje, 1);
      expect(p.recolhasProximas48h, 2);
      expect(p.recolhasEmAtraso, 0);
    });

    test('reserva que passou do fim e continua alugada é recolha em atraso', () {
      // Ninguém deu a máquina por recolhida: ela está no cliente e a app tem de
      // o dizer. É a aproximação possível enquanto não houver o evento de
      // recolha que o colaborador regista no terreno.
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'atrasada',
            comeca: 1,
            acaba: 12,
            status: BookingStatus.rented,
          ),
        ]),
        agora,
      );

      expect(p.recolhasEmAtraso, 1);
      expect(p.diasDaRecolhaMaisAtrasada, 3);
    });

    test('reserva terminada e fechada não gera recolha nenhuma', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'fechada',
            comeca: 1,
            acaba: 12,
            status: BookingStatus.completed,
          ),
        ]),
        agora,
      );

      expect(p.recolhasEmAtraso, 0);
      expect(p.diasDaRecolhaMaisAtrasada, isNull);
    });

    test('a antiguidade é a da recolha mais antiga', () {
      final p = pulsoOperacional(
        com([
          reserva(id: 'a', comeca: 1, acaba: 13, status: BookingStatus.rented),
          reserva(id: 'b', comeca: 1, acaba: 5, status: BookingStatus.rented),
        ]),
        agora,
      );

      expect(p.recolhasEmAtraso, 2);
      expect(p.diasDaRecolhaMaisAtrasada, 10);
    });
  });

  group('reservas agendadas (Pedido) já contam', () {
    // O Cesar decidiu (9 Ago): uma reserva em Pedido/agendada já é agenda
    // ocupada — entra nos operacionais antes de ser confirmada. Só cancelada e
    // concluída é que não geram trabalho.
    test('um pedido que cobre hoje conta como reserva activa', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'pedido',
            comeca: 10,
            acaba: 20,
            status: BookingStatus.request,
          ),
        ]),
        agora,
      );

      expect(p.reservasActivas, 1);
    });

    test('um pedido que começa hoje é entrega prevista e está por fazer', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'pedido',
            comeca: 15,
            acaba: 18,
            status: BookingStatus.request,
          ),
        ]),
        agora,
      );

      expect(p.entregasHoje, 1);
      expect(p.entregasPorFazer, 1);
    });

    test('um pedido que acaba hoje é recolha prevista', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'pedido',
            comeca: 10,
            acaba: 15,
            status: BookingStatus.request,
          ),
        ]),
        agora,
      );

      expect(p.recolhasHoje, 1);
    });

    test('um pedido passado nunca é recolha em atraso — nada saiu', () {
      // Em atraso só a máquina que saiu (alugada). Um pedido que expirou não é
      // uma recolha por fazer, é uma reserva morta.
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'pedido-velho',
            comeca: 1,
            acaba: 12,
            status: BookingStatus.request,
          ),
        ]),
        agora,
      );

      expect(p.recolhasEmAtraso, 0);
      expect(p.diasDaRecolhaMaisAtrasada, isNull);
    });
  });

  group('cobranças a vencer', () {
    test('soma o que está por receber dentro de 7 dias', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'a',
            comeca: 10,
            acaba: 15,
            valorCents: 50000,
            cliente: 'c1',
          ),
          reserva(
            id: 'b',
            comeca: 10,
            acaba: 18,
            valorCents: 30000,
            cliente: 'c2',
          ),
          reserva(
            id: 'longe',
            comeca: 10,
            acaba: 40,
            valorCents: 90000,
            cliente: 'c3',
          ),
        ]),
        agora,
      );

      expect(p.cobrancasAVencerCents, 80000);
      expect(p.clientesACobrar, 2);
    });

    test('o que já foi recebido não aparece por cobrar', () {
      final p = pulsoOperacional(
        com(
          [reserva(id: 'a', comeca: 10, acaba: 15, valorCents: 50000)],
          recibos: [
            Receipt(
              id: 'r1',
              date: dia(14),
              amountCents: 50000,
              customerId: 'c1',
              method: PaymentMethod.transfer,
              bookingId: 'a',
            ),
          ],
        ),
        agora,
      );

      expect(p.cobrancasAVencerCents, 0);
      expect(p.clientesACobrar, 0);
    });

    test('destaca o que vence hoje', () {
      final p = pulsoOperacional(
        com([
          reserva(id: 'hoje', comeca: 10, acaba: 15, valorCents: 34000),
          reserva(id: 'depois', comeca: 10, acaba: 19, valorCents: 20000),
        ]),
        agora,
      );

      expect(p.venceHojeCents, 34000);
      expect(p.cobrancasAVencerCents, 54000);
    });

    test('o mesmo cliente com duas reservas conta uma vez', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'a',
            comeca: 10,
            acaba: 15,
            valorCents: 10000,
            cliente: 'c1',
          ),
          reserva(
            id: 'b',
            comeca: 10,
            acaba: 16,
            valorCents: 10000,
            cliente: 'c1',
          ),
        ]),
        agora,
      );

      expect(p.clientesACobrar, 1);
    });
  });

  group('linha de alertas', () {
    test('cala-se quando não há nada a assinalar', () {
      // "0 alertas" ocupa uma linha para não dizer nada.
      final p = pulsoOperacional(
        com([
          reserva(id: 'a', comeca: 10, acaba: 25, status: BookingStatus.rented),
        ]),
        agora,
      );

      expect(p.alertas, isNull);
    });

    test('põe o atraso à frente da entrega por fazer', () {
      final p = pulsoOperacional(
        com([
          reserva(
            id: 'atrasada',
            comeca: 1,
            acaba: 12,
            status: BookingStatus.rented,
          ),
          reserva(id: 'entrega', comeca: 15, acaba: 20),
        ]),
        agora,
      );

      expect(p.alertas, '1 recolha em atraso · 1 entrega por fazer');
    });

    test('inclui a cobrança que vence hoje', () {
      final p = pulsoOperacional(
        com([reserva(id: 'a', comeca: 10, acaba: 15, valorCents: 34000)]),
        agora,
      );

      expect(p.alertas, contains('340 € vence hoje'));
    });

    test('o plural muda com a contagem', () {
      final p = pulsoOperacional(
        com([
          reserva(id: 'a', comeca: 1, acaba: 12, status: BookingStatus.rented),
          reserva(id: 'b', comeca: 1, acaba: 13, status: BookingStatus.rented),
        ]),
        agora,
      );

      expect(p.alertas, '2 recolhas em atraso');
    });
  });
}
