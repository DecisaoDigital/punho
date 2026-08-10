import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';

import 'fixtura.dart';

/// As quatro células que antes viviam no slide de Procura e vendas.
///
/// A célula "clientes novos" é a única do painel cujo dado não existe no
/// modelo: `Customer` não guarda data de criação. É inferida da primeira
/// reserva — e estes testes fixam essa regra, para ninguém a trocar por um
/// número inventado outra vez.
const idsDeProcura = [
  'clientes-novos-30d',
  'leads-pipeline',
  'ticket-medio-mes',
  'conversao-lead-cliente',
];

void main() {
  final agora = DateTime(2026, 7, 15, 10, 30);
  DateTime dia(int mes, int d) => DateTime(2026, mes, d);

  Booking reserva(String id, String cliente, DateTime comeca, {int? valor}) =>
      Booking(
        id: id,
        customerId: cliente,
        machineIds: const ['m1'],
        startsAt: comeca,
        endsAt: comeca.add(const Duration(days: 2)),
        status: BookingStatus.confirmed,
        expectedValueCents: valor,
      );

  Lead lead(String id, LeadStatus estado, DateTime criada) =>
      Lead(id: id, name: id, phone: '910', status: estado, createdAt: criada);

  group('clientesNovos', () {
    test('sem reservas devolve null, não zero', () {
      // Zero diria "não angariaste ninguém". A verdade é que não se sabe.
      expect(
        clientesNovos(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('conta cada cliente uma vez, pela primeira reserva', () {
      final estado = OperationsState(
        onboarded: true,
        bookings: [
          reserva('a', 'c1', dia(7, 2)),
          reserva('b', 'c1', dia(7, 10)),
          reserva('c', 'c2', dia(7, 5)),
        ],
      );

      expect(clientesNovos(estado, agora), 2);
    });

    test('cliente antigo com reserva recente não é novo', () {
      final estado = OperationsState(
        onboarded: true,
        bookings: [
          // Primeira reserva em Janeiro: já era cliente muito antes da janela.
          reserva('velha', 'c1', dia(1, 10)),
          reserva('recente', 'c1', dia(7, 10)),
        ],
      );

      expect(clientesNovos(estado, agora), 0);
    });

    test('reservas canceladas não fazem de ninguém cliente', () {
      final estado = OperationsState(
        onboarded: true,
        bookings: [
          Booking(
            id: 'x',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(7, 10),
            endsAt: dia(7, 12),
            status: BookingStatus.cancelled,
          ),
          reserva('ok', 'c2', dia(7, 11)),
        ],
      );

      expect(clientesNovos(estado, agora), 1);
    });

    test('reserva futura não conta como cliente já angariado', () {
      final estado = OperationsState(
        onboarded: true,
        bookings: [reserva('futura', 'c1', dia(8, 20))],
      );

      expect(clientesNovos(estado, agora), 0);
    });
  });

  testWidgets('empresa vazia não mostra número nenhum inventado', (
    tester,
  ) async {
    final container = containerCom(
      const OperationsState(onboarded: true, companyName: 'Alugueres Norte'),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDeProcura, agora: agora),
    );

    expect(find.text('Ainda sem clientes'), findsOneWidget);
    expect(find.text('Sem reservas com valor'), findsOneWidget);
    expect(find.text('Sem leads em 30 dias'), findsOneWidget);
    expect(find.text('Por apurar'), findsNothing);
    expect(find.textContaining('17'), findsNothing);
    expect(find.textContaining('28'), findsNothing);
  });

  testWidgets('os KPIs vêm do estado', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        bookings: [
          reserva('a', 'c1', dia(7, 2), valor: 40000),
          reserva('b', 'c2', dia(7, 6), valor: 44000),
        ],
        leads: [
          lead('l1', LeadStatus.converted, dia(7, 1)),
          lead('l2', LeadStatus.newLead, dia(7, 14)),
        ],
      ),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDeProcura, agora: agora),
    );

    // 2 clientes novos, 1 lead por contactar, ticket médio 420 €, conversão 50%.
    expect(
      find.textContaining('2 clientes', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('420 €', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('50 % · 1 de 2', findRichText: true),
      findsOneWidget,
    );
  });
}
