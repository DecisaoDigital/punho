import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/finance/regime_fiscal.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';

import 'fixtura.dart';

/// As quatro células da Síntese — o painel novo pagina por ids, não por slide.
const _idsDaSintese = [
  'entradas-mes',
  'utilizacao-rentabilidade',
  'encontro-contas',
  'recomendacao-dia',
];

/// Teste de canalização: o dinheiro declarado num ecrã tem de sair no outro.
///
/// **Porque existe.** A 4 de Agosto de 2026, num telemóvel real, o painel dizia
/// "Saídas 0" a uma empresa com viaturas a pagar prestação. Não era um erro de
/// conta — era um cano que não estava ligado: `Saídas` lia só as despesas
/// lançadas à mão, e uma prestação não se lança à mão, declara-se uma vez na
/// ficha do veículo. Tudo o que estivesse declarado e não lançado ficava
/// invisível, por muito que saísse mesmo da conta.
///
/// **O que este ficheiro protege**, e que um teste de unidade a `custosMes...`
/// não protegeria: o percurso inteiro, do modelo ao pixel. Cada teste começa
/// num campo que o gestor preenche e acaba no texto que ele lê. Se alguém
/// acrescentar um encargo novo e se esquecer de o ligar ao painel, é aqui que
/// parte.
void main() {
  // O cenário do achado: hoje é dia 4, e há prestações que já saíram nos dias 2
  // e 3. A hora não é redonda de propósito — `now.day` não pode depender dela.
  final quatroDeAgosto = DateTime(2026, 8, 4, 16, 20);

  Vehicle carrinha({
    required String id,
    required String matricula,
    required int prestacaoCents,
    int? dia,
  }) => Vehicle(
    id: id,
    plate: matricula,
    type: 'Comercial',
    status: VehicleStatus.active,
    monthlyPaymentCents: prestacaoCents,
    paymentDayOfMonth: dia,
  );

  // 350,00 € a 2 de Agosto e 425,50 € a 3 de Agosto: 775,50 € que saíram da
  // conta antes do dia 4.
  final duasPrestacoesJaPagas = [
    carrinha(id: 'v1', matricula: 'AA-01-BB', prestacaoCents: 35000, dia: 2),
    carrinha(id: 'v2', matricula: 'CC-02-DD', prestacaoCents: 42550, dia: 3),
  ];

  OperationsState estadoCom({
    List<Vehicle> veiculos = const [],
    List<CustoFixo> custosFixos = const [],
    List<Expense> despesas = const [],
    List<Receipt> recebimentos = const [],
  }) => OperationsState(
    onboarded: true,
    companyName: 'Alugueres Norte',
    vehicles: veiculos,
    custosFixos: custosFixos,
    expenses: despesas,
    receipts: recebimentos,
  );

  group('prestações com data', () {
    test('duas prestações vencidas a 2 e a 3 já são saída no dia 4', () {
      final mes = tesourariaDoMes(
        estadoCom(veiculos: duasPrestacoesJaPagas),
        quatroDeAgosto,
      );

      expect(mes.encargosFixosVencidosCents, 77550);
      expect(mes.saidasCents, 77550);
      // Nenhuma despesa lançada à mão: era exactamente por isto que o painel
      // dizia zero.
      expect(mes.pagoCents, 0);
    });

    test('uma prestação do dia 28 ainda não saiu no dia 4', () {
      final mes = tesourariaDoMes(
        estadoCom(
          veiculos: [
            ...duasPrestacoesJaPagas,
            carrinha(
              id: 'v3',
              matricula: 'EE-03-FF',
              prestacaoCents: 60000,
              dia: 28,
            ),
          ],
        ),
        quatroDeAgosto,
      );

      // A do dia 28 fica de fora. Contá-la seria dizer ao gestor que já saiu
      // dinheiro que ainda está na conta dele.
      expect(mes.saidasCents, 77550);
    });

    test('prestação sem dia declarado não conta como saída', () {
      final mes = tesourariaDoMes(
        estadoCom(
          veiculos: [
            carrinha(id: 'v9', matricula: 'ZZ-99-ZZ', prestacaoCents: 50000),
          ],
        ),
        quatroDeAgosto,
      );

      // Sem data não há como saber se já saiu. O custo continua a contar no
      // mês, repartido pelos dias — mas não se afirma que saiu da conta.
      expect(mes.saidasCents, 0);
    });

    test('viatura arquivada ou inactiva não paga prestação nenhuma', () {
      final mes = tesourariaDoMes(
        estadoCom(
          veiculos: [
            carrinha(
              id: 'v1',
              matricula: 'AA-01-BB',
              prestacaoCents: 35000,
              dia: 2,
            ).copyWith(archived: true),
            carrinha(
              id: 'v2',
              matricula: 'CC-02-DD',
              prestacaoCents: 42550,
              dia: 3,
            ).copyWith(status: VehicleStatus.inactive),
          ],
        ),
        quatroDeAgosto,
      );

      expect(mes.saidasCents, 0);
    });
  });

  group('rubricas de custo fixo com data', () {
    test('a renda vencida a 1 conta como saída no dia 4', () {
      final mes = tesourariaDoMes(
        estadoCom(
          custosFixos: const [
            CustoFixo(
              id: 'cf1',
              categoria: ExpenseCategory.rent,
              valorCents: 80000,
              diaDoMes: 1,
            ),
            // Sem dia: fica de fora das saídas, como as prestações sem data.
            CustoFixo(
              id: 'cf2',
              categoria: ExpenseCategory.electricity,
              valorCents: 15000,
            ),
          ],
        ),
        quatroDeAgosto,
      );

      expect(mes.saidasCents, 80000);
    });

    test(
      'uma rubrica com data não conta duas vezes quando também é lançada',
      () {
        // O risco de duplicação é real: o gestor declara a renda como rubrica
        // fixa e, no mês seguinte, lança-a outra vez como despesa. Manda a fonte
        // declarada — a mesma regra que já valia para os salários.
        final mes = tesourariaDoMes(
          estadoCom(
            custosFixos: const [
              CustoFixo(
                id: 'cf1',
                categoria: ExpenseCategory.rent,
                valorCents: 80000,
                diaDoMes: 1,
              ),
            ],
            despesas: [
              Expense(
                id: 'd1',
                date: DateTime(2026, 8, 1),
                amountCents: 80000,
                category: ExpenseCategory.rent,
                status: ExpensePaymentStatus.paid,
              ),
            ],
          ),
          quatroDeAgosto,
        );

        expect(mes.saidasCents, 80000);
      },
    );

    test('despesa de categoria sem rubrica declarada continua a contar', () {
      final mes = tesourariaDoMes(
        estadoCom(
          despesas: [
            Expense(
              id: 'd1',
              date: DateTime(2026, 8, 2),
              amountCents: 4500,
              category: ExpenseCategory.fuel,
              status: ExpensePaymentStatus.paid,
            ),
          ],
        ),
        quatroDeAgosto,
      );

      expect(mes.saidasCents, 4500);
    });
  });

  group('o dia certo, no mês certo', () {
    test('mês por vir não tem encargo nenhum vencido', () {
      expect(encargoJaVenceu(2, DateTime(2026, 9), quatroDeAgosto), isFalse);
    });

    test('mês fechado venceu tudo, seja qual for o dia', () {
      expect(encargoJaVenceu(28, DateTime(2026, 7), quatroDeAgosto), isTrue);
    });

    test('o encargo de hoje já conta hoje', () {
      // Um débito de dia 4 lido ao fim da tarde do dia 4 já saiu. Empurrá-lo
      // para amanhã fazia o painel contradizer o extracto bancário.
      expect(encargoJaVenceu(4, DateTime(2026, 8), quatroDeAgosto), isTrue);
    });

    test('dia impossível vale o mesmo que dia nenhum', () {
      // Vindo do servidor ou de um campo de texto, 0 e 32 não são datas.
      expect(diaDoMesValido(0), isNull);
      expect(diaDoMesValido(32), isNull);
      expect(diaDoMesValido(31), 31);
    });
  });

  group('o custo do mês repartido', () {
    test('a prestação datada não entra repartida, entra no dia', () {
      final custos = custosMesAgregados(
        estadoCom(veiculos: duasPrestacoesJaPagas),
        quatroDeAgosto,
        regime: RegimeFiscal.ldaIrc,
      );

      // O mês inteiro custa as duas prestações; a 4 de Agosto já saíram as
      // duas, e não 4/31 delas.
      expect(custos.prestacoesComDataCents, 77550);
      expect(custos.prestacoesVencidasCents, 77550);
      expect(custos.custoAteAgoraCents, 77550);
      expect(custos.totalCents, 77550);
    });

    test('a prestação por vencer não pesa antes do dia', () {
      final custos = custosMesAgregados(
        estadoCom(
          veiculos: [
            carrinha(
              id: 'v3',
              matricula: 'EE-03-FF',
              prestacaoCents: 60000,
              dia: 28,
            ),
          ],
        ),
        quatroDeAgosto,
        regime: RegimeFiscal.ldaIrc,
      );

      expect(custos.totalCents, 60000);
      expect(custos.custoAteAgoraCents, 0);
    });
  });

  testWidgets('o painel mostra a prestação que já saiu, e não "Saídas 0"', (
    tester,
  ) async {
    final container = containerCom(
      estadoCom(
        veiculos: duasPrestacoesJaPagas,
        recebimentos: [
          Receipt(
            id: 'r1',
            date: DateTime(2026, 8, 3),
            amountCents: 120000,
            customerId: 'c1',
            method: PaymentMethod.transfer,
          ),
        ],
      ),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: _idsDaSintese, agora: quatroDeAgosto),
    );

    // 1200 € entraram, 775,50 € saíram: saldo + 425 €. Antes desta ligação o
    // card dizia "Saídas 0" e um saldo de + 1200 €, que é dinheiro que o gestor
    // já não tem.
    expect(find.textContaining('Saídas 776'), findsOneWidget);
    expect(find.textContaining('Saídas 0'), findsNothing);
    expect(find.textContaining('+ 425', findRichText: true), findsOneWidget);
  });

  testWidgets('só com prestações pagas, o mês já tem movimentos', (
    tester,
  ) async {
    // Sem recebimento nenhum, mas com dinheiro a sair: "Sem movimentos este
    // mês" seria falso — saíram 775,50 €.
    final container = containerCom(estadoCom(veiculos: duasPrestacoesJaPagas));

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: _idsDaSintese, agora: quatroDeAgosto),
    );

    expect(find.text('Sem movimentos este mês'), findsNothing);
    expect(find.textContaining('Saídas 776'), findsOneWidget);
  });
}
