import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/guidance/guidance_engine.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/dashboard/kpis/recomendacao_do_dia.dart';

import 'fixtura.dart';

/// Reserva terminada há [diasDeAtraso] com [cents] por receber.
Booking _dividaDe({
  required String id,
  required String clienteId,
  required String nome,
  required int diasDeAtraso,
  required int cents,
}) => Booking(
  id: id,
  customerId: clienteId,
  customerNameSnapshot: nome,
  machineIds: const ['m1'],
  startsAt: agoraFixa.subtract(Duration(days: diasDeAtraso + 3)),
  endsAt: agoraFixa.subtract(Duration(days: diasDeAtraso)),
  status: BookingStatus.completed,
  expectedValueCents: cents,
);

/// Estado limpo: sem dívidas, sem custos, sem leads. Cada teste acrescenta só
/// o que a sua regra precisa, para nenhuma regra anterior lhe passar à frente.
OperationsState _limpo({
  List<Booking> bookings = const [],
  List<Receipt> receipts = const [],
  List<Expense> expenses = const [],
  List<Lead> leads = const [],
  List<Collaborator> collaborators = const [],
  List<HistoricalMonth> historicalMonths = const [],
}) => OperationsState(
  onboarded: true,
  companyName: 'Alugueres Norte',
  bookings: bookings,
  receipts: receipts,
  expenses: expenses,
  leads: leads,
  collaborators: collaborators,
  historicalMonths: historicalMonths,
  machines: const [
    Machine(
      id: 'm1',
      name: 'Mini escavadora',
      reference: 'ME-01',
      category: 'Escavação',
      status: MachineStatus.available,
    ),
  ],
);

void main() {
  group('Regra 1 · dívida antiga e de valor', () {
    test('cliente com 40 dias e 400 € manda cobrar', () {
      final estado = _limpo(
        bookings: [
          _dividaDe(
            id: 'b1',
            clienteId: 'c9',
            nome: 'João Pereira',
            diasDeAtraso: 40,
            cents: 40000,
          ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r, isNotNull);
      expect(r!.regra, 'divida-urgente');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
      expect(r.texto, 'Cobrar João Pereira — 40 dias em atraso, 400,00 €');
      expect(r.cta, 'Abrir ficha →');
      expect(r.accao, AccaoDoDia.fichaCliente);
      expect(r.clienteId, 'c9');
    });

    test('valor pequeno não sobe a urgente, mesmo com 40 dias', () {
      // 90 € abaixo do limiar dos 100 €: cai na regra da atenção? Não — essa
      // exige entre 15 e 30 dias. Com 40 dias e valor pequeno não vale
      // interromper o dia do gestor.
      final estado = _limpo(
        bookings: [
          _dividaDe(
            id: 'b1',
            clienteId: 'c9',
            nome: 'João',
            diasDeAtraso: 40,
            cents: 9000,
          ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa)?.regra, isNot('divida-urgente'));
    });

    test('soma as reservas do mesmo cliente e usa a dívida mais antiga', () {
      final estado = _limpo(
        bookings: [
          _dividaDe(
            id: 'b1',
            clienteId: 'c9',
            nome: 'João',
            diasDeAtraso: 40,
            cents: 6000,
          ),
          _dividaDe(
            id: 'b2',
            clienteId: 'c9',
            nome: 'João',
            diasDeAtraso: 20,
            cents: 6000,
          ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r!.regra, 'divida-urgente', reason: '60 + 60 passa os 100 €');
      expect(r.texto, contains('40 dias'));
      expect(r.texto, contains('120,00 €'));
    });
  });

  group('Regra 2 · custos a comer a receita', () {
    test('80% ou mais dispara urgente', () {
      final estado = _limpo(
        receipts: [
          Receipt(
            id: 'r1',
            date: agoraFixa,
            amountCents: 100000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
        collaborators: const [
          Collaborator(
            id: 'col-1',
            name: 'Ana',
            status: CollaboratorStatus.active,
            costCents: 85000,
          ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r!.regra, 'custos-criticos');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
      expect(r.texto, 'Custos a comer a receita — 85% do que entrou já saiu');
      expect(r.accao, AccaoDoDia.slideCustos);
    });

    test('sem receita não dispara — não há proporção', () {
      final estado = _limpo(
        collaborators: const [
          Collaborator(
            id: 'col-1',
            name: 'Ana',
            status: CollaboratorStatus.active,
            costCents: 85000,
          ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa)?.regra, isNot('custos-criticos'));
    });
  });

  group('Regra 3 · dívida a caminho de ser problema', () {
    test('entre 15 e 30 dias fica em atenção', () {
      final estado = _limpo(
        bookings: [
          _dividaDe(
            id: 'b1',
            clienteId: 'c9',
            nome: 'Construções Silva',
            diasDeAtraso: 20,
            cents: 5000,
          ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r!.regra, 'divida-atencao');
      expect(r.gravidade, GravidadeRecomendacao.atencao);
      expect(r.texto, 'Construções Silva — 20 dias sem pagar');
      expect(r.accao, AccaoDoDia.fichaCliente);
    });

    test('a dívida urgente passa-lhe à frente', () {
      final estado = _limpo(
        bookings: [
          _dividaDe(
            id: 'b1',
            clienteId: 'c1',
            nome: 'Antigo',
            diasDeAtraso: 40,
            cents: 20000,
          ),
          _dividaDe(
            id: 'b2',
            clienteId: 'c2',
            nome: 'Recente',
            diasDeAtraso: 20,
            cents: 5000,
          ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa)!.regra, 'divida-urgente');
    });
  });

  group('Regra 4 · queda face ao mês homólogo', () {
    test('a facturar menos de 60% do ano passado avisa', () {
      final estado = _limpo(
        receipts: [
          Receipt(
            id: 'r-agora',
            date: agoraFixa,
            amountCents: 40000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
          Receipt(
            id: 'r-homologo',
            date: DateTime(agoraFixa.year - 1, agoraFixa.month, 10),
            amountCents: 100000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r!.regra, 'queda-homologa');
      expect(r.gravidade, GravidadeRecomendacao.atencao);
      expect(r.texto, 'A facturar 40% do que fizeste em Julho do ano passado');
      expect(r.accao, AccaoDoDia.todasAsMetricas);
    });

    test('usa o histórico declarado quando não há recebimentos do ano passado', () {
      final estado = _limpo(
        receipts: [
          Receipt(
            id: 'r-agora',
            date: agoraFixa,
            amountCents: 20000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
        historicalMonths: [
          HistoricalMonth(
            year: agoraFixa.year - 1,
            month: agoraFixa.month,
            revenueReceivedCents: 100000,
          ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa)!.regra, 'queda-homologa');
    });

    test('mês homólogo pequeno não serve de comparação', () {
      // 300 € no ano passado: abaixo do mínimo de 500 €, porque uma queda
      // percentual sobre um valor pequeno não quer dizer nada.
      final estado = _limpo(
        receipts: [
          Receipt(
            id: 'r-homologo',
            date: DateTime(agoraFixa.year - 1, agoraFixa.month, 10),
            amountCents: 30000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa)?.regra, isNot('queda-homologa'));
    });
  });

  group('Regra 5 · conversão boa', () {
    test('40% ou mais sugere pedir referências', () {
      final estado = _limpo(
        leads: [
          for (var i = 0; i < 2; i++)
            Lead(
              id: 'convertida-$i',
              name: 'Cliente $i',
              phone: '910 000 00$i',
              status: LeadStatus.converted,
              createdAt: agoraFixa.subtract(Duration(days: 5 + i)),
            ),
          for (var i = 0; i < 3; i++)
            Lead(
              id: 'nova-$i',
              name: 'Lead $i',
              phone: '911 000 00$i',
              status: LeadStatus.newLead,
              createdAt: agoraFixa.subtract(Duration(days: 2 + i)),
            ),
        ],
      );

      final r = recomendacaoDoDia(estado, agoraFixa);

      expect(r!.regra, 'conversao-boa');
      expect(r.gravidade, GravidadeRecomendacao.oportunidade);
      expect(r.texto, startsWith('Conversão a 30 dias em 40%'));
      expect(r.accao, AccaoDoDia.slidePipeline);
    });

    test('conversão fraca não é notícia', () {
      final estado = _limpo(
        leads: [
          Lead(
            id: 'l1',
            name: 'Uma',
            phone: '910 000 001',
            status: LeadStatus.converted,
            createdAt: agoraFixa.subtract(const Duration(days: 3)),
          ),
          for (var i = 0; i < 9; i++)
            Lead(
              id: 'nova-$i',
              name: 'Lead $i',
              phone: '911 000 00$i',
              status: LeadStatus.newLead,
              createdAt: agoraFixa.subtract(Duration(days: 2 + i)),
            ),
        ],
      );

      expect(recomendacaoDoDia(estado, agoraFixa), isNull);
    });
  });

  group('Sem regra aplicável', () {
    test('devolve null em vez de conselho genérico', () {
      expect(recomendacaoDoDia(_limpo(), agoraFixa), isNull);
      expect(recomendacaoDoDia(estadoSemMovimento(), agoraFixa), isNull);
    });
  });

  group('Ordem das regras na fixture com movimento', () {
    test('os custos críticos ganham à dívida de 20 dias', () {
      // A fixture recebe 1320 € e tem 1730 € de custos (131%): a regra 2 é
      // urgente e passa à frente da dívida de 20 dias, que é só atenção. A
      // regra 1 não se aplica porque 20 < 30 dias.
      final r = recomendacaoDoDia(estadoComMovimento(), agoraFixa);

      expect(r!.regra, 'custos-criticos');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
    });

    test('sem o problema dos custos aparece a dívida', () {
      final semCustos = estadoComMovimento().copyWith(
        collaborators: const [],
        vehicles: const [],
        expenses: const [],
      );

      final r = recomendacaoDoDia(semCustos, agoraFixa);

      expect(r!.regra, 'divida-atencao');
      expect(r.texto, 'João Pereira — 20 dias sem pagar');
    });
  });
}
