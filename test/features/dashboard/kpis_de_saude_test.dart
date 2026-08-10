import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/kpis_de_saude.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';

/// **As contas de saúde da empresa.**
///
/// Cada uma destas nasceu de uma linha da auditoria
/// (`docs/AUDITORIA_KPIS_EMPRESA.md`) que dizia «não coberto». O que os testes
/// guardam não é o valor — é a **decisão** que cada conta tomou: o que entra,
/// o que fica de fora, e o que devolve quando não há fonte.
///
/// A regra transversal: **sem fonte devolve `null`**, e nunca zero. Zero é uma
/// resposta («não há saldo»), `null` é uma pergunta («não sei»), e a célula
/// pinta-as de maneiras diferentes — uma com número, a outra a dizer o que
/// falta.
void main() {
  final agora = DateTime(2026, 8, 10, 15);
  final mesPassado = DateTime(2026, 7, 15);

  Receipt recebimento(
    String id,
    int cents,
    DateTime data, {
    String cliente = 'c1',
    String? reserva,
  }) => Receipt(
    id: id,
    date: data,
    amountCents: cents,
    customerId: cliente,
    method: PaymentMethod.transfer,
    // Sem `bookingId` o recebimento não abate à reserva — é assim que a app
    // conta o que está por cobrar em todo o lado, e o ciclo segue a mesma
    // regra.
    bookingId: reserva,
  );

  Expense despesa(
    String id,
    int cents,
    DateTime data,
    ExpenseCategory categoria, {
    ExpensePaymentStatus estado = ExpensePaymentStatus.paid,
  }) => Expense(
    id: id,
    date: data,
    amountCents: cents,
    category: categoria,
    status: estado,
  );

  group('saldo e autonomia', () {
    test('sem movimento nenhum não é saldo zero, é falta de dados', () {
      expect(
        saldoEAutonomia(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('o saldo é o que entrou menos o que se pagou', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 500000, DateTime(2026, 8, 3))],
        expenses: [
          despesa('d1', 120000, DateTime(2026, 8, 4), ExpenseCategory.rent),
          // Por pagar não sai da conta: o dinheiro ainda lá está.
          despesa(
            'd2',
            80000,
            DateTime(2026, 8, 5),
            ExpenseCategory.supplies,
            estado: ExpensePaymentStatus.unpaid,
          ),
        ],
      );

      expect(saldoEAutonomia(estado, agora)!.saldoCents, 380000);
    });

    test('a autonomia sai dos custos fixos declarados', () {
      final estado = OperationsState(
        onboarded: true,
        custosFixos: const [
          CustoFixo(
            id: 'f1',
            categoria: ExpenseCategory.rent,
            valorCents: 87000,
          ),
        ],
        receipts: [recebimento('r1', 500000, DateTime(2026, 8, 3))],
      );

      final saude = saldoEAutonomia(estado, agora)!;
      // 870 €/mês ÷ 4,348 semanas = 200,09 €/semana. 5000 € dá 25 semanas.
      expect(saude.queimaSemanalCents, 20009);
      expect(saude.semanas, closeTo(24.99, 0.05));
      expect(saude.apertado, isFalse);
    });

    test('sem nada a queimar não há autonomia para calcular', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 100000, DateTime(2026, 8, 3))],
      );

      // Não é «autonomia infinita»: é uma empresa que ainda não disse o que
      // gasta. A célula pede os custos fixos em vez de mostrar um número.
      expect(saldoEAutonomia(estado, agora)!.semanas, isNull);
    });

    test('o mês em curso não entra na média da queima', () {
      // A 10 de Agosto o mês tem dez dias de despesas. Contá-lo como um mês
      // inteiro puxava a média para baixo — e numa medida de risco isso
      // *aumenta* a autonomia anunciada, que é a mentira que dói.
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 1000000, DateTime(2026, 8, 1))],
        expenses: [
          despesa('d1', 60000, DateTime(2026, 7, 10), ExpenseCategory.fuel),
          despesa('d2', 3000, DateTime(2026, 8, 2), ExpenseCategory.fuel),
        ],
      );

      // Só Julho tem registo completo: 600 €/mês, e não (600+30)/3 = 210.
      expect(saldoEAutonomia(estado, agora)!.queimaSemanalCents, 13799);
    });

    test('sem rubricas, o total do onboarding não se soma às despesas', () {
      // Somar dava a renda contada duas vezes: uma no total redondo que ele
      // declarou, outra na despesa de renda que lançou. Fica a maior das duas.
      final estado = OperationsState(
        onboarded: true,
        fixedMonthlyCostsCents: 100000,
        receipts: [recebimento('r1', 1000000, DateTime(2026, 8, 1))],
        expenses: [
          despesa('d1', 90000, DateTime(2026, 7, 5), ExpenseCategory.rent),
        ],
      );

      // 1000 € declarados contra 900 € medidos: manda o declarado, e não 1900.
      expect(saldoEAutonomia(estado, agora)!.queimaSemanalCents, 22999);
    });

    test('com rubricas, o que elas não cobrem soma-se por cima', () {
      final estado = OperationsState(
        onboarded: true,
        custosFixos: const [
          CustoFixo(
            id: 'f1',
            categoria: ExpenseCategory.rent,
            valorCents: 87000,
          ),
        ],
        receipts: [recebimento('r1', 1000000, DateTime(2026, 8, 1))],
        expenses: [
          // A renda já está na rubrica: não conta outra vez.
          despesa('d1', 87000, DateTime(2026, 7, 3), ExpenseCategory.rent),
          despesa('d2', 43000, DateTime(2026, 7, 4), ExpenseCategory.fuel),
        ],
      );

      // 870 da rubrica + 430 de combustível = 1300 €/mês.
      expect(saldoEAutonomia(estado, agora)!.queimaSemanalCents, 29899);
    });

    test('menos de seis semanas é apertado', () {
      final estado = OperationsState(
        onboarded: true,
        custosFixos: const [
          CustoFixo(
            id: 'f1',
            categoria: ExpenseCategory.rent,
            valorCents: 400000,
          ),
        ],
        receipts: [recebimento('r1', 300000, DateTime(2026, 8, 3))],
      );

      expect(saldoEAutonomia(estado, agora)!.apertado, isTrue);
    });
  });

  group('margem bruta', () {
    test('sem receita no mês não há margem — não há denominador', () {
      expect(
        margemBruta(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('só os custos directos entram; a estrutura fica de fora', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 100000, DateTime(2026, 8, 3))],
        expenses: [
          despesa(
            'd1',
            20000,
            DateTime(2026, 8, 4),
            ExpenseCategory.machineMaintenance,
          ),
          // Renda é estrutura: paga-se com a máquina parada, e por isso não
          // desconta à margem bruta.
          despesa('d2', 50000, DateTime(2026, 8, 5), ExpenseCategory.rent),
        ],
      );

      final margem = margemBruta(estado, agora)!;
      expect(margem.custosDirectosCents, 20000);
      expect(margem.percent, 80);
    });

    test('a despesa por pagar não desconta à margem', () {
      // Caixa dos dois lados. Com o custo lançado mas não pago a entrar na
      // conta, atrasar um pagamento fazia a margem *piorar* no mês em que se
      // lançava e melhorar no mês em que se pagava — duas vezes a mesma
      // despesa, em meses diferentes.
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 100000, DateTime(2026, 8, 3))],
        expenses: [
          despesa(
            'd1',
            30000,
            DateTime(2026, 8, 4),
            ExpenseCategory.fuel,
            estado: ExpensePaymentStatus.unpaid,
          ),
        ],
      );

      expect(margemBruta(estado, agora)!.custosDirectosCents, 0);
      expect(margemBruta(estado, agora)!.percent, 100);
    });

    test('a trajectória compara com o mês passado, em pontos', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [
          recebimento('r1', 100000, DateTime(2026, 8, 3)),
          recebimento('r0', 100000, mesPassado),
        ],
        expenses: [
          despesa('d1', 20000, DateTime(2026, 8, 4), ExpenseCategory.fuel),
          despesa('d0', 40000, mesPassado, ExpenseCategory.fuel),
        ],
      );

      final margem = margemBruta(estado, agora)!;
      expect(margem.mesAnteriorPercent, 60);
      expect(margem.variacao, 20);
    });
  });

  group('ciclo de tesouraria', () {
    test('sem receita na janela não há ciclo a medir', () {
      expect(
        cicloDeTesouraria(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('o que está por cobrar puxa os dias para cima', () {
      final estado = OperationsState(
        onboarded: true,
        machines: const [
          Machine(
            id: 'm1',
            name: 'Giratória',
            reference: 'G1',
            category: 'escavação',
            status: MachineStatus.available,
          ),
        ],
        bookings: [
          Booking(
            id: 'b1',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 7, 1),
            endsAt: DateTime(2026, 7, 10),
            status: BookingStatus.completed,
            expectedValueCents: 200000,
          ),
        ],
        receipts: [
          recebimento('r1', 100000, DateTime(2026, 7, 12), reserva: 'b1'),
        ],
      );

      final ciclo = cicloDeTesouraria(estado, agora)!;
      // Metade por cobrar sobre a receita da janela: 100000/100000 × 90 dias.
      expect(ciclo.diasACobrar, closeTo(90, 0.5));
      // Dez dias alugada em noventa: oitenta parada.
      expect(ciclo.diasParada, closeTo(80, 1));
      expect(ciclo.diasAPagar, 0);
    });

    test('a máquina comprada a meio não conta parada antes de existir', () {
      // O ciclo piorava por se ter investido: a máquina comprada ontem
      // arrastava consigo os 89 dias em que ainda não era da empresa.
      final estado = OperationsState(
        onboarded: true,
        machines: [
          Machine(
            id: 'm1',
            name: 'Giratória',
            reference: 'G1',
            category: 'escavação',
            status: MachineStatus.available,
            acquiredOn: DateTime(2026, 8, 9),
            purchasePriceCents: 300000,
          ),
        ],
        receipts: [recebimento('r1', 100000, DateTime(2026, 7, 12))],
      );

      // Dois dias na frota (9 e 10 de Agosto), nenhum alugado.
      expect(cicloDeTesouraria(estado, agora)!.diasParada, closeTo(2, 0.01));
    });

    test('pagar tarde a fornecedores desconta ao ciclo', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 100000, DateTime(2026, 7, 12))],
        expenses: [
          despesa(
            'd1',
            50000,
            DateTime(2026, 7, 20),
            ExpenseCategory.supplies,
            estado: ExpensePaymentStatus.unpaid,
          ),
          despesa('d2', 50000, DateTime(2026, 7, 21), ExpenseCategory.supplies),
        ],
      );

      // Metade das despesas da janela por pagar: 45 dias de crédito.
      expect(cicloDeTesouraria(estado, agora)!.diasAPagar, closeTo(45, 0.5));
    });
  });

  group('fluxo de caixa livre', () {
    test('a máquina comprada no mês desconta ao que sobrou', () {
      final estado = OperationsState(
        onboarded: true,
        machines: [
          Machine(
            id: 'm1',
            name: 'Giratória',
            reference: 'G1',
            category: 'escavação',
            status: MachineStatus.available,
            acquiredOn: DateTime(2026, 8, 2),
            purchasePriceCents: 300000,
          ),
        ],
        receipts: [recebimento('r1', 500000, DateTime(2026, 8, 3))],
        expenses: [
          despesa('d1', 100000, DateTime(2026, 8, 4), ExpenseCategory.rent),
        ],
      );

      final fluxo = fluxoDeCaixaLivre(estado, agora)!;
      expect(fluxo.operacionalCents, 400000);
      expect(fluxo.investimentoCents, 300000);
      expect(fluxo.livreCents, 100000);
      expect(fluxo.maquinasCompradas, 1);
    });

    test('a comprada noutro mês não desconta a este', () {
      final estado = OperationsState(
        onboarded: true,
        machines: [
          Machine(
            id: 'm1',
            name: 'Giratória',
            reference: 'G1',
            category: 'escavação',
            status: MachineStatus.available,
            acquiredOn: DateTime(2026, 5, 2),
            purchasePriceCents: 300000,
          ),
        ],
        receipts: [recebimento('r1', 500000, DateTime(2026, 8, 3))],
      );

      expect(fluxoDeCaixaLivre(estado, agora)!.investimentoCents, 0);
    });

    test('sem movimentos no mês devolve nada', () {
      expect(
        fluxoDeCaixaLivre(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });
  });

  group('custo de aquisição', () {
    test('sem publicidade não há custo de aquisição', () {
      final estado = OperationsState(
        onboarded: true,
        receipts: [recebimento('r1', 100000, DateTime(2026, 8, 3))],
      );

      // É angariação orgânica, não é um zero a dizer que se gastou zero e
      // veio gente — são coisas diferentes.
      expect(custoDeAquisicao(estado, agora), isNull);
    });

    test('sem clientes não se sabe quem é novo — e diz-se', () {
      // Diferente de «gastou-se e não veio ninguém»: aqui nem sequer há como
      // contar. A célula pede clientes em vez de pintar um vermelho.
      final estado = OperationsState(
        onboarded: true,
        expenses: [
          despesa(
            'd1',
            60000,
            DateTime(2026, 7, 1),
            ExpenseCategory.advertising,
          ),
        ],
      );

      expect(custoDeAquisicao(estado, agora)!.semComoContar, isTrue);
    });

    test('divide a publicidade pelos clientes que entraram', () {
      final estado = OperationsState(
        onboarded: true,
        // Os dois entraram dentro da janela dos 90 dias — e o que os conta é
        // a data em que foram registados, não a da reserva.
        customers: [
          Customer(
            id: 'c1',
            name: 'Obra Nova',
            phone: '910000000',
            createdAt: DateTime(2026, 7, 18),
          ),
          Customer(
            id: 'c2',
            name: 'Terraforte',
            phone: '910000001',
            createdAt: DateTime(2026, 7, 30),
          ),
        ],
        bookings: [
          Booking(
            id: 'b1',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 7, 20),
            endsAt: DateTime(2026, 7, 25),
            status: BookingStatus.completed,
          ),
          Booking(
            id: 'b2',
            customerId: 'c2',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 8, 1),
            endsAt: DateTime(2026, 8, 5),
            status: BookingStatus.rented,
          ),
        ],
        expenses: [
          despesa(
            'd1',
            60000,
            DateTime(2026, 7, 1),
            ExpenseCategory.advertising,
          ),
        ],
      );

      final cac = custoDeAquisicao(estado, agora)!;
      expect(cac.investidoCents, 60000);
      expect(cac.clientesNovos, 2);
      expect(cac.porClienteCents, 30000);
    });

    test(
      'gastar e não entrar ninguém não é custo infinito, é uma pergunta',
      () {
        final estado = OperationsState(
          onboarded: true,
          // Há clientes com data, portanto há como contar — mas o único que
          // existe entrou muito antes da janela: ninguém entrou nos 90 dias.
          customers: [
            Customer(
              id: 'c1',
              name: 'Obra Antiga',
              phone: '910000000',
              createdAt: DateTime(2025, 1, 3),
            ),
          ],
          bookings: [
            Booking(
              id: 'b1',
              customerId: 'c1',
              machineIds: const ['m1'],
              startsAt: DateTime(2025, 1, 5),
              endsAt: DateTime(2025, 1, 9),
              status: BookingStatus.completed,
            ),
          ],
          expenses: [
            despesa(
              'd1',
              60000,
              DateTime(2026, 7, 1),
              ExpenseCategory.advertising,
            ),
          ],
        );

        final cac = custoDeAquisicao(estado, agora)!;
        expect(cac.semComoContar, isFalse);
        expect(cac.clientesNovos, 0);
        expect(cac.porClienteCents, isNull);
      },
    );
  });

  group('receita de quem volta', () {
    test('sem recebimentos no mês devolve nada', () {
      expect(
        receitaRecorrente(const OperationsState(onboarded: true), agora),
        isNull,
      );
    });

    test('recorrente é quem já tinha reserva antes deste mês', () {
      final estado = OperationsState(
        onboarded: true,
        bookings: [
          Booking(
            id: 'b1',
            customerId: 'antigo',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 6, 1),
            endsAt: DateTime(2026, 6, 5),
            status: BookingStatus.completed,
          ),
        ],
        receipts: [
          recebimento('r1', 70000, DateTime(2026, 8, 3), cliente: 'antigo'),
          recebimento('r2', 30000, DateTime(2026, 8, 4), cliente: 'novo'),
        ],
      );

      final recorrente = receitaRecorrente(estado, agora)!;
      expect(recorrente.percent, 70);
      expect(recorrente.clientesRecorrentes, 1);
      expect(recorrente.clientesDoMes, 2);
    });

    test('quem alugou antes e só paga agora não conta como cliente novo', () {
      // O marco é a reserva e não o recebimento. Sem isto, um pagamento
      // atrasado fazia um cliente de Junho aparecer como conquista de Agosto.
      final estado = OperationsState(
        onboarded: true,
        bookings: [
          Booking(
            id: 'b1',
            customerId: 'antigo',
            machineIds: const ['m1'],
            startsAt: DateTime(2026, 6, 1),
            endsAt: DateTime(2026, 6, 5),
            status: BookingStatus.completed,
          ),
        ],
        receipts: [
          recebimento('r1', 50000, DateTime(2026, 8, 9), cliente: 'antigo'),
        ],
      );

      expect(receitaRecorrente(estado, agora)!.percent, 100);
    });
  });

  group('leads a arrefecer', () {
    Lead lead(String id, LeadStatus estado, DateTime criada) => Lead(
      id: id,
      name: id,
      phone: '910000000',
      status: estado,
      createdAt: criada,
    );

    test('só conta as paradas há mais de duas semanas', () {
      final estado = OperationsState(
        onboarded: true,
        leads: [
          lead('fria', LeadStatus.newLead, DateTime(2026, 7, 1)),
          lead('recente', LeadStatus.newLead, DateTime(2026, 8, 8)),
        ],
      );

      final frias = leadsFrias(estado, agora);
      expect(frias.frias, 1);
      expect(frias.diasDaMaisAntiga, 40);
    });

    test('quem já avançou no funil não está a arrefecer', () {
      final estado = OperationsState(
        onboarded: true,
        leads: [
          lead('proposta', LeadStatus.proposal, DateTime(2026, 6, 1)),
          lead('convertida', LeadStatus.converted, DateTime(2026, 6, 1)),
          lead('perdida', LeadStatus.lost, DateTime(2026, 6, 1)),
        ],
      );

      expect(leadsFrias(estado, agora).frias, 0);
    });

    test('sem leads frias não há data da mais antiga', () {
      expect(
        leadsFrias(
          const OperationsState(onboarded: true),
          agora,
        ).diasDaMaisAntiga,
        isNull,
      );
    });
  });
}
