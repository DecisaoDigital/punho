import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';

import 'fixtura.dart';

/// As quatro células que antes viviam no slide de Procura e vendas.
///
/// A célula "clientes novos" conta pela data de registo do cliente
/// (`Customer.createdAt`). Contou pela primeira reserva até 10 de Agosto de
/// 2026, e esses testes estão aqui em baixo virados do avesso: com dois
/// clientes criados nessa manhã e reservas marcadas para dia 11 e 12, o número
/// dava **zero**, porque a janela olhava para a data de **início** da reserva e
/// parava em hoje.
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

  Customer cliente(String id, {DateTime? criado, bool arquivado = false}) =>
      Customer(
        id: id,
        name: id,
        phone: '910',
        createdAt: criado,
        archived: arquivado,
      );

  group('clientesNovos', () {
    test('sem clientes com data devolve null, não zero', () {
      // Zero diria "não angariaste ninguém". A verdade é que não se sabe.
      expect(
        clientesNovos(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('conta cada cliente uma vez, pela data de registo', () {
      final estado = OperationsState(
        onboarded: true,
        customers: [
          cliente('c1', criado: dia(7, 2)),
          cliente('c2', criado: dia(7, 5)),
        ],
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
        customers: [cliente('c1', criado: dia(1, 10))],
        bookings: [
          reserva('velha', 'c1', dia(1, 10)),
          reserva('recente', 'c1', dia(7, 10)),
        ],
      );

      expect(clientesNovos(estado, agora), 0);
    });

    /// **O bug de 10 de Agosto de 2026.** Dois clientes criados de manhã, com
    /// reservas para dia 11 e 12, e o KPI a dizer 0. A janela media a data de
    /// início da reserva e cortava em hoje: o cliente só contaria como novo no
    /// dia em que a máquina saísse.
    test(
      'cliente registado hoje com reserva para a semana que vem conta já',
      () {
        final estado = OperationsState(
          onboarded: true,
          customers: [cliente('c1', criado: agora)],
          bookings: [reserva('futura', 'c1', dia(8, 20))],
        );

        expect(clientesNovos(estado, agora), 1);
      },
    );

    /// O outro furo do mesmo dia: sem uma reserva, o cliente não existia.
    test('cliente sem reserva nenhuma conta na mesma', () {
      final estado = OperationsState(
        onboarded: true,
        customers: [cliente('c1', criado: dia(7, 14))],
      );

      expect(clientesNovos(estado, agora), 1);
      expect(clientesNovosComReserva(estado, agora), 0);
    });

    test('clientes arquivados não contam como angariados', () {
      final estado = OperationsState(
        onboarded: true,
        customers: [
          cliente('c1', criado: dia(7, 14)),
          cliente('c2', criado: dia(7, 14), arquivado: true),
        ],
      );

      expect(clientesNovos(estado, agora), 1);
    });

    /// Os clientes gravados antes de existir o campo não perdem a data: o id
    /// é o relógio do instante em que foram criados.
    test('sem createdAt, a data vem do id', () {
      final quando = dia(7, 9);
      final id = 'c${quando.microsecondsSinceEpoch}';

      expect(Customer.dataDoId(id), quando);
      expect(
        Customer.dataDoId('c1'),
        isNull,
        reason: 'as sementes de demonstração não são um relógio',
      );
    });
  });

  group('clientesNovosComReserva', () {
    test('conta só quem já tem máquina marcada', () {
      final estado = OperationsState(
        onboarded: true,
        customers: [
          cliente('c1', criado: dia(7, 10)),
          cliente('c2', criado: dia(7, 11)),
        ],
        bookings: [reserva('ok', 'c1', dia(8, 1))],
      );

      expect(clientesNovos(estado, agora), 2);
      expect(clientesNovosComReserva(estado, agora), 1);
    });

    test('uma reserva cancelada não conta como máquina marcada', () {
      final estado = OperationsState(
        onboarded: true,
        customers: [cliente('c1', criado: dia(7, 10))],
        bookings: [
          Booking(
            id: 'x',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(7, 10),
            endsAt: dia(7, 12),
            status: BookingStatus.cancelled,
          ),
        ],
      );

      expect(clientesNovosComReserva(estado, agora), 0);
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
        customers: [
          cliente('c1', criado: dia(7, 1)),
          cliente('c2', criado: dia(7, 5)),
        ],
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
    expect(find.text('Todos já com reserva'), findsOneWidget);
    expect(find.textContaining('420 €', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('50 % · 1 de 2', findRichText: true),
      findsOneWidget,
    );
  });

  /// **Recompras, e não "recorrência".** O César pediu o número de recompras a
  /// 10 de Agosto de 2026, e não é o mesmo número: recorrência 1×/mês são
  /// **zero** recompras — cada cliente comprou uma vez e não voltou. Dizer "1"
  /// deixava por saber se aquilo era uma compra ou uma repetição.
  group('ticket médio — as recompras', () {
    Future<void> montarTicket(WidgetTester tester, List<Booking> reservas) =>
        montarLandscape(
          tester,
          containerCom(
            OperationsState(
              onboarded: true,
              companyName: 'Alugueres Norte',
              bookings: reservas,
            ),
          ),
          PaginaDoPainel(ids: const ['ticket-medio-mes'], agora: agora),
        );

    testWidgets('uma compra por cliente é ninguém a repetir', (tester) async {
      await montarTicket(tester, [
        reserva('a', 'c1', dia(7, 2), valor: 40000),
        reserva('b', 'c2', dia(7, 6), valor: 44000),
      ]);

      expect(
        find.text('Ninguém repetiu este mês · 2 clientes'),
        findsOneWidget,
      );
    });

    testWidgets('quem volta conta como recompra', (tester) async {
      // Quatro compras, dois clientes: duas recompras, uma por cliente.
      await montarTicket(tester, [
        reserva('a', 'c1', dia(7, 2), valor: 40000),
        reserva('b', 'c1', dia(7, 9), valor: 40000),
        reserva('c', 'c2', dia(7, 6), valor: 44000),
        reserva('d', 'c2', dia(7, 13), valor: 44000),
      ]);

      expect(
        find.textContaining('1 recompras por cliente (2 no total)'),
        findsOneWidget,
      );
    });

    testWidgets('meia recompra escreve-se com vírgula', (tester) async {
      // Três compras, dois clientes: uma recompra, 0,5 por cliente.
      await montarTicket(tester, [
        reserva('a', 'c1', dia(7, 2), valor: 40000),
        reserva('b', 'c1', dia(7, 9), valor: 40000),
        reserva('c', 'c2', dia(7, 6), valor: 44000),
      ]);

      expect(
        find.textContaining('0,5 recompras por cliente (1 no total)'),
        findsOneWidget,
      );
    });
  });
}
