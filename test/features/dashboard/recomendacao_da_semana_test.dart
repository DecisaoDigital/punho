import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/guidance/guidance_engine.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/workforce.dart';

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
  List<Machine> machines = const [
    Machine(
      id: 'm1',
      name: 'Mini escavadora',
      reference: 'ME-01',
      category: 'Escavação',
      status: MachineStatus.available,
    ),
  ],
}) => OperationsState(
  onboarded: true,
  companyName: 'Alugueres Norte',
  bookings: bookings,
  receipts: receipts,
  expenses: expenses,
  leads: leads,
  collaborators: collaborators,
  historicalMonths: historicalMonths,
  machines: machines,
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

      final r = recomendacaoDaSemana(estado, agoraFixa);

      expect(r, isNotNull);
      expect(r!.id, 'divida-urgente');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
      expect(r.title, 'Cobrar João Pereira — 40 dias em atraso, 400 €');
      expect(r.action, 'Abrir ficha →');
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

      expect(
        recomendacaoDaSemana(estado, agoraFixa)?.id,
        isNot('divida-urgente'),
      );
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

      final r = recomendacaoDaSemana(estado, agoraFixa);

      expect(r!.id, 'divida-urgente', reason: '60 + 60 passa os 100 €');
      expect(r.title, contains('40 dias'));
      expect(r.title, contains('120 €'));
    });
  });

  group('Regra 2 · custos a comer a receita', () {
    // Os dois testes que fixam as percentagens da Decisão 12 correm ao último
    // dia do mês de propósito: aí o mês já correu todo, o custo incorrido é o
    // custo mensal inteiro, e as contas dão os números redondos que a decisão
    // documenta. A meio do mês dariam metade — e é isso que se quer.
    final ultimoDiaDoMes = DateTime(2026, 7, 31, 10, 30);

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

      final r = recomendacaoDaSemana(estado, ultimoDiaDoMes);

      expect(r!.id, 'custos-criticos');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
      // 850 € de bruto sobre 1.000 € de receita liam-se como 85%. Com a TSU
      // patronal — que é dinheiro que sai da empresa — são 1.051 €, ou seja
      // 105%: a empresa está a gastar mais do que recebe. Decisão 12.
      expect(
        r.title,
        'Custos a comer a receita — já vão em 105% do que entrou',
      );
    });

    test('um custo que parecia seguro passa a disparar', () {
      // É este o caso que a Decisão 12 destrava. 700 € de bruto sobre 1.000 €
      // de receita são 70% e ficavam calados; com a carga social são 86,6% e a
      // regra dispara. Não é falso positivo — era falso negativo.
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
            costCents: 70000,
          ),
        ],
      );

      final r = recomendacaoDaSemana(estado, ultimoDiaDoMes);

      expect(r!.id, 'custos-criticos');
      expect(r.title, 'Custos a comer a receita — já vão em 87% do que entrou');
    });

    test('quem está a recibos verdes não leva carga social', () {
      // O mesmo bruto, outro vínculo: 700 € a recibos verdes são 70% e não
      // disparam. A TSU patronal não existe aqui.
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
            costCents: 70000,
            employmentType: EmploymentType.recibosVerdes,
          ),
        ],
      );

      expect(
        recomendacaoDaSemana(estado, agoraFixa)?.id,
        isNot('custos-criticos'),
      );
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

      expect(
        recomendacaoDaSemana(estado, agoraFixa)?.id,
        isNot('custos-criticos'),
      );
    });

    test('no princípio do mês não grita só porque o mês ainda mal começou', () {
      // Apanhado num telemóvel a 4 de Agosto: o painel dizia "Entradas 128 ·
      // Saídas 0" e, no card ao lado, "2149% do que entrou já saiu". Os dois
      // números vinham do mesmo mês, mas não do mesmo pedaço dele — o custo
      // era de 31 dias e a receita de 4.
      final empresa = _limpo(
        receipts: [
          Receipt(
            id: 'r1',
            date: DateTime(2026, 8, 2),
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

      // Dia 4 de 31: 1.051 € de custo mensal valem 135 € de custo incorrido
      // sobre 1.000 € recebidos. 14% — nada a assinalar.
      expect(
        recomendacaoDaSemana(empresa, DateTime(2026, 8, 4, 10, 30))?.id,
        isNot('custos-criticos'),
      );
    });

    test('a mesma empresa dispara quando o mês inteiro justifica', () {
      // Contraprova do teste anterior: o que muda não é a empresa, é quanto do
      // mês já correu. Sem isto, a correcção podia ter matado a regra.
      final empresa = _limpo(
        receipts: [
          Receipt(
            id: 'r1',
            date: DateTime(2026, 8, 2),
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

      final r = recomendacaoDaSemana(empresa, DateTime(2026, 8, 31, 10, 30));

      expect(r!.id, 'custos-criticos');
      expect(
        r.title,
        'Custos a comer a receita — já vão em 105% do que entrou',
      );
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

      final r = recomendacaoDaSemana(estado, agoraFixa);

      expect(r!.id, 'divida-atencao');
      expect(r.gravidade, GravidadeRecomendacao.atencao);
      expect(r.title, 'Construções Silva — 20 dias sem pagar');
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

      expect(recomendacaoDaSemana(estado, agoraFixa)!.id, 'divida-urgente');
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

      final r = recomendacaoDaSemana(estado, agoraFixa);

      expect(r!.id, 'queda-homologa');
      expect(r.gravidade, GravidadeRecomendacao.atencao);
      expect(r.title, 'A facturar 40% do que fizeste em Julho do ano passado');
    });

    test(
      'usa o histórico declarado quando não há recebimentos do ano passado',
      () {
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

        expect(recomendacaoDaSemana(estado, agoraFixa)!.id, 'queda-homologa');
      },
    );

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

      expect(
        recomendacaoDaSemana(estado, agoraFixa)?.id,
        isNot('queda-homologa'),
      );
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

      final r = recomendacaoDaSemana(estado, agoraFixa);

      expect(r!.id, 'conversao-boa');
      expect(r.gravidade, GravidadeRecomendacao.oportunidade);
      expect(r.title, startsWith('Conversão a 30 dias em 40%'));
    });

    test('conversão fraca não é notícia', () {
      // Sem máquina nenhuma, pela mesma razão do teste "Sem regra
      // aplicável": isola o teste da regra "quarta-feira fraca".
      final estado = _limpo(
        machines: const [],
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

      expect(recomendacaoDaSemana(estado, agoraFixa), isNull);
    });
  });

  group('Sem regra aplicável', () {
    test('devolve null em vez de conselho genérico', () {
      // Sem máquina nenhuma: a regra "quarta-feira fraca" do GuidanceEngine
      // não dispara (precisa de uma máquina disponível e parada — testado à
      // parte em guidance_engine_test.dart), o que isola este teste ao que
      // ele quer verificar: nenhuma das regras específicas se aplica.
      expect(
        recomendacaoDaSemana(_limpo(machines: const []), agoraFixa),
        isNull,
      );
      expect(recomendacaoDaSemana(estadoSemMovimento(), agoraFixa), isNull);
    });
  });

  group('Ordem das regras na fixture com movimento', () {
    test('os custos críticos ganham à dívida de 20 dias', () {
      // A fixture recebe 1320 € e tem 1730 € de custos (131%): a regra 2 é
      // urgente e passa à frente da dívida de 20 dias, que é só atenção. A
      // regra 1 não se aplica porque 20 < 30 dias.
      final r = recomendacaoDaSemana(estadoComMovimento(), agoraFixa);

      expect(r!.id, 'custos-criticos');
      expect(r.gravidade, GravidadeRecomendacao.urgente);
    });

    test('sem o problema dos custos aparece a dívida', () {
      final semCustos = estadoComMovimento().copyWith(
        collaborators: const [],
        vehicles: const [],
        expenses: const [],
      );

      final r = recomendacaoDaSemana(semCustos, agoraFixa);

      expect(r!.id, 'divida-atencao');
      expect(r.title, 'João Pereira — 20 dias sem pagar');
    });
  });
}
