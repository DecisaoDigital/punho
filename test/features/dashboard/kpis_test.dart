import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/guidance/guidance_engine.dart';
import 'package:punho/core/finance/regime_fiscal.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/operations.dart';

import 'fixtura.dart';

void main() {
  final estado = estadoComMovimento();
  final vazio = estadoSemMovimento();

  group('Tesouraria do mês', () {
    test('soma o recebido do mês e guarda o do mês anterior', () {
      final mes = tesourariaDoMes(estado, agoraFixa);

      expect(mes.recebidoCents, 90000 + 42000);
      expect(mes.recebidoMesAnteriorCents, 110000);
      expect(mes.pagoCents, 25000 + 18000, reason: 'a não paga fica de fora');
    });

    test(
      'a série diária tem um valor por dia e põe o dinheiro no dia certo',
      () {
        final mes = tesourariaDoMes(estado, agoraFixa);

        expect(mes.serieDiariaCents, hasLength(31));
        // Recebimento de 900 € a 8 de Julho (índice 7).
        expect(mes.serieDiariaCents[7], 90000);
        expect(mes.serieDiariaCents[0], 0);
      },
    );

    test('navegar para trás mostra o mês anterior', () {
      final junho = tesourariaDoMes(estado, DateTime(2026, 6, 1));

      expect(junho.recebidoCents, 110000);
      expect(junho.serieDiariaCents, hasLength(30));
    });

    test('sem mês anterior não inventa percentagem', () {
      final maio = tesourariaDoMes(estado, DateTime(2026, 5, 1));

      expect(maio.recebidoCents, 0);
      expect(maio.variacaoVsMesAnterior, isNull);
    });

    test(
      'sem recebimentos do homólogo mas com histórico mensal preenchido, usa '
      'o histórico',
      () {
        // Antes desta correcção, tesourariaDoMes só olhava para `receipts` e
        // ignorava `historicalMonths` por completo: um gestor que preenchesse
        // Julho de 2025 à mão continuava a ver "Por apurar" no painel — o
        // histórico existia, mas ninguém ia lá buscar o número (achado 9/10).
        final comHistorico = estado.copyWith(
          historicalMonths: const [
            HistoricalMonth(year: 2025, month: 7, revenueReceivedCents: 100000),
          ],
        );

        final julho = tesourariaDoMes(comHistorico, agoraFixa);

        expect(julho.recebidoMesHomologoCents, 100000);
        expect(julho.variacaoVsHomologo, isNotNull);
        expect(julho.comparacao?.homologo, isTrue);
      },
    );

    test('recebimentos reais do homólogo ganham ao histórico preenchido', () {
      // O histórico é a rede de segurança, nunca a fonte preferida — se já há
      // recebimentos a sério para o mês, é neles que se confia.
      final comAmbos = estado.copyWith(
        receipts: [
          ...estado.receipts,
          Receipt(
            id: 'r-homologo',
            date: DateTime(2025, 7, 10),
            amountCents: 50000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
        historicalMonths: const [
          HistoricalMonth(year: 2025, month: 7, revenueReceivedCents: 100000),
        ],
      );

      final julho = tesourariaDoMes(comAmbos, agoraFixa);

      expect(julho.recebidoMesHomologoCents, 50000);
    });

    test('sem recebimentos nem histórico, continua "Por apurar"', () {
      // A regra do ficheiro: falta de dados devolve `null`, nunca um número
      // inventado — mesmo depois desta correcção.
      final julho = tesourariaDoMes(estado, agoraFixa);

      expect(julho.recebidoMesHomologoCents, 0);
      expect(julho.variacaoVsHomologo, isNull);
    });

    test('a tendência é o previsto do mês, não só o recebido de hoje', () {
      // O exemplo do gestor: o mês passado faturou 10.000 €; hoje (dia 15) só
      // entraram 1.000 €, mas há 5.000 € de reservas marcadas até ao fim do
      // mês. O previsto é 6.000 € — 40% abaixo do mês passado. A seta mostra
      // esse −40% (o gestor sabe que tem de converter mais leads), e não um
      // −90% falso que só diria "o mês agora começou". O número grande continua
      // a ser o dinheiro que entrou de verdade.
      final cenario = vazio.copyWith(
        historicalMonths: const [],
        receipts: [
          Receipt(
            id: 'r-mes-passado',
            date: DateTime(2026, 6, 10),
            amountCents: 1000000,
            customerId: 'c1',
            method: PaymentMethod.transfer,
          ),
          Receipt(
            id: 'r-este-mes',
            date: DateTime(2026, 7, 5),
            amountCents: 100000,
            customerId: 'c1',
            method: PaymentMethod.cash,
          ),
        ],
        bookings: [
          Booking(
            id: 'b-por-realizar',
            customerId: 'c1',
            machineIds: ['m1'],
            startsAt: DateTime(2026, 7, 20),
            endsAt: DateTime(2026, 7, 22),
            status: BookingStatus.confirmed,
            expectedValueCents: 500000,
          ),
        ],
      );

      final julho = tesourariaDoMes(cenario, agoraFixa);

      expect(julho.recebidoCents, 100000, reason: 'o número grande é o recebido');
      expect(julho.entradasPrevistasCents, 600000, reason: '1000 feito + 5000 marcado');
      expect(julho.variacaoVsMesAnterior, closeTo(-40, 0.001));
      expect(julho.comparacao?.variacao, closeTo(-40, 0.001));
      expect(julho.comparacao?.homologo, isFalse);
    });
  });

  group('Resultado do mês', () {
    test('é a diferença quando há movimentos', () {
      expect(resultadoMesConservador(estado, agoraFixa), 132000 - 43000);
    });

    test('é nulo sem movimentos — não é zero', () {
      // O falso zero que o painel antigo mostrava: "Resultado 0 €" lê-se como
      // equilíbrio, quando a verdade é que não há dados.
      expect(resultadoMesConservador(vazio, agoraFixa), isNull);
    });
  });

  group('Previsão do mês', () {
    // Agosto de 2026: mês anterior é Julho de 2026, homólogo é Agosto de 2025.
    final agora = DateTime(2026, 8, 15);

    test('entradas somam o já recebido e o por receber de reservas do mês', () {
      final previsto = previsaoDoMes(
        OperationsState(
          onboarded: true,
          receipts: [
            Receipt(
              id: 'r1',
              date: DateTime(2026, 8, 5),
              amountCents: 50000,
              customerId: 'c1',
              method: PaymentMethod.transfer,
            ),
          ],
          bookings: [
            Booking(
              id: 'b1',
              customerId: 'c1',
              machineIds: ['m1'],
              startsAt: DateTime(2026, 8, 10),
              endsAt: DateTime(2026, 8, 12),
              status: BookingStatus.confirmed,
              expectedValueCents: 40000,
            ),
            // Cancelada: não é um compromisso, não entra na previsão.
            Booking(
              id: 'b2',
              customerId: 'c1',
              machineIds: ['m1'],
              startsAt: DateTime(2026, 8, 20),
              endsAt: DateTime(2026, 8, 22),
              status: BookingStatus.cancelled,
              expectedValueCents: 100000,
            ),
          ],
        ),
        agora,
      );

      expect(previsto.entradasPrevistasCents, 50000 + 40000);
    });

    test('saídas são nulas sem custos fixos declarados', () {
      final previsto = previsaoDoMes(
        const OperationsState(onboarded: true),
        agora,
      );
      expect(previsto.saidasPrevistasCents, isNull);
      expect(previsto.saldoPrevistoCents, isNull);
    });

    test('saídas somam os custos fixos à média das variáveis do mês passado e '
        'do homólogo', () {
      final previsto = previsaoDoMes(
        OperationsState(
          onboarded: true,
          custosFixos: const [
            CustoFixo(
              id: 'renda',
              categoria: ExpenseCategory.rent,
              valorCents: 30000,
            ),
          ],
          expenses: [
            // Variável do mês anterior (Julho de 2026): combustível 100 €.
            Expense(
              id: 'e1',
              date: DateTime(2026, 7, 10),
              amountCents: 10000,
              category: ExpenseCategory.fuel,
              status: ExpensePaymentStatus.paid,
            ),
            // Variável do homólogo (Agosto de 2025): combustível 200 €.
            Expense(
              id: 'e2',
              date: DateTime(2025, 8, 10),
              amountCents: 20000,
              category: ExpenseCategory.fuel,
              status: ExpensePaymentStatus.paid,
            ),
            // Renda paga em Julho, mesma categoria da rubrica fixa: não
            // conta como variável, senão a renda entrava duas vezes.
            Expense(
              id: 'e3',
              date: DateTime(2026, 7, 5),
              amountCents: 30000,
              category: ExpenseCategory.rent,
              status: ExpensePaymentStatus.paid,
            ),
            // Por pagar: não é gasto real ainda, não entra na média.
            Expense(
              id: 'e4',
              date: DateTime(2026, 7, 12),
              amountCents: 90000,
              category: ExpenseCategory.fuel,
              status: ExpensePaymentStatus.unpaid,
            ),
          ],
        ),
        agora,
      );

      expect(previsto.saidasPrevistasCents, 30000 + (10000 + 20000) ~/ 2);
      expect(
        previsto.saldoPrevistoCents,
        previsto.entradasPrevistasCents - previsto.saidasPrevistasCents!,
      );
    });
  });

  group('Cobranças', () {
    test('apanha a reserva que acabou e não foi paga', () {
      final atrasadas = cobrancasPorReceber(
        estado,
        agoraFixa,
        minimoDiasAtraso: 15,
      );

      expect(atrasadas, hasLength(1));
      expect(atrasadas.single.clienteNome, 'João Pereira');
      expect(atrasadas.single.emDividaCents, 78000);
      expect(atrasadas.single.diasDeAtraso, 20);
    });

    test('reserva paga por inteiro não conta', () {
      final todas = cobrancasPorReceber(estado, agoraFixa);

      expect(todas.map((c) => c.booking.id), isNot(contains('b-paga')));
    });

    test('reserva que ainda está a decorrer não é atraso', () {
      // A futura tem valor previsto e nada recebido, mas o prazo ainda não
      // passou: aparece como por receber, com zero dias de atraso.
      final futura = cobrancasPorReceber(
        estado,
        agoraFixa,
      ).firstWhere((c) => c.booking.id == 'b-futura');

      expect(futura.diasDeAtraso, 0);
    });
  });

  group('Funil de procura', () {
    test('conta leads, tocadas e convertidas nos últimos 30 dias', () {
      final funil = funilProcura(estado, agoraFixa, 30);

      expect(funil.leads, 4);
      expect(
        funil.contactadas,
        2,
        reason: 'convertida e perdida já foram tocadas',
      );
      expect(funil.convertidas, 1);
      expect(funil.taxa, closeTo(25, 0.01));
    });

    test('sem leads no período a taxa é desconhecida, não 0%', () {
      expect(funilProcura(vazio, agoraFixa, 30).taxa, isNull);
    });

    test('leads por contactar vêm da mais antiga para a mais recente', () {
      final lista = leadsPorContactar(estado);

      expect(lista.map((l) => l.id), ['l1', 'l2']);
    });
  });

  group('Compromissos próximos', () {
    test('conta as confirmadas das próximas duas semanas com o valor', () {
      final proximos = compromissosProximos(estado, agoraFixa);

      expect(proximos.reservas.map((b) => b.id), ['b-futura']);
      expect(proximos.valorPrevistoCents, 120000);
      expect(proximos.porDia, hasLength(14));
      expect(proximos.porDia[3], 1, reason: 'começa dentro de 3 dias');
    });

    test('não conta reservas passadas', () {
      final proximos = compromissosProximos(estado, agoraFixa);
      expect(proximos.reservas.map((b) => b.id), isNot(contains('b-paga')));
    });
  });

  group('Ocupação das máquinas', () {
    test('mede dias-máquina ocupados sobre os possíveis', () {
      final ocupacao = ocupacaoMaquinasSemana(estado, agoraFixa);

      // Semana de 13 a 19 de Julho: a b-futura ocupa a m1 em 18 e 19 (2 dias)
      // de 21 dias-máquina possíveis (3 máquinas × 7 dias).
      expect(ocupacao.percent, closeTo(2 / 21 * 100, 0.01));
      expect(ocupacao.alugadas, 1);
      expect(ocupacao.emManutencao, 0, reason: 'nenhuma em manutenção');
      expect(ocupacao.disponiveis, 2, reason: 'a m3 passou a disponível');
    });

    test('sem máquinas não há percentagem', () {
      final ocupacao = ocupacaoMaquinasSemana(vazio, agoraFixa);

      expect(ocupacao.percent, isNull);
      expect(ocupacao.tendenciaVsAnterior, isNull);
    });
  });

  group('Máquinas', () {
    test('top de mais alugadas ordena por número de reservas', () {
      final top = topMaquinasMaisAlugadas(estado, 3);

      expect(top.first.maquina.id, 'm1');
      expect(top.first.alugueres, 2);
      expect(top.map((m) => m.maquina.id), ['m1', 'm2']);
    });

    test('sem alugar há mais de 7 dias distingue "nunca" de "há N dias"', () {
      final paradas = maquinasSemAluguerHaMaisDe(estado, 7, agoraFixa);

      final nunca = paradas.firstWhere((p) => p.maquina.id == 'm3');
      expect(nunca.diasSemAluguer, isNull);
      // A m2 acabou há 20 dias.
      final m2 = paradas.firstWhere((p) => p.maquina.id == 'm2');
      expect(m2.diasSemAluguer, 20);
    });

    test('máquina alugada agora não entra nas paradas', () {
      final paradas = maquinasSemAluguerHaMaisDe(estado, 7, agoraFixa);
      expect(paradas.map((p) => p.maquina.id), isNot(contains('m1')));
    });

    test('ticket médio ignora reservas sem valor', () {
      expect(ticketMedioReserva(estado), (120000 + 78000 + 90000) ~/ 3);
      expect(ticketMedioReserva(vazio), isNull);
    });
  });

  group('Custos do mês', () {
    test('soma pessoal ao custo real, frota e manutenção paga', () {
      final custos = custosMesAgregados(
        estado,
        agoraFixa,
        regime: RegimeFiscal.ldaIrc,
      );

      // 1.100 € de bruto declarado + 23,75% de TSU patronal (Decisão 12): o
      // agregado passou a somar o que sai da empresa, não o que o colaborador
      // recebe. Contar só o bruto fazia este total contradizer o KPI do slide.
      expect(custos.pessoalBrutoCents, 110000);
      expect(custos.tsuPatronalCents, 26125);
      expect(custos.custoRealPessoalCents, 136125);
      expect(custos.colaboradoresActivos, 2);
      expect(custos.custoMedioPorColaborador, 136125 ~/ 2);
      // Prestação 110 € + seguro anual 1080 €/12 = 90 €.
      expect(custos.frotaCents, 11000 + 9000);
      expect(custos.manutencaoPagaCents, 25000);
      expect(custos.outrosCustosCents, 18000, reason: 'só o combustível pago');
    });

    test('média de manutenção usa só os meses com despesas', () {
      final custos = custosMesAgregados(
        estado,
        agoraFixa,
        regime: RegimeFiscal.ldaIrc,
      );
      expect(custos.manutencaoMedia6MesesCents, (40000 + 20000) ~/ 2);
    });

    test('peso na receita é nulo sem receita', () {
      expect(
        custosMesAgregados(
          vazio,
          agoraFixa,
          regime: RegimeFiscal.ldaIrc,
        ).percentDaReceita,
        isNull,
      );
    });

    test('peso na receita compara pedaços iguais de calendário', () {
      // O custo do mês inteiro sobre a receita recebida até hoje media o dia
      // do mês, não o negócio: a 4 de Agosto, num telemóvel real, deu 2149%
      // com o card do lado a dizer "Saídas 0". Salários e frota são encargos
      // mensais e entram repartidos pelos dias já corridos.
      final custos = custosMesAgregados(
        estado,
        agoraFixa,
        regime: RegimeFiscal.ldaIrc,
      );

      expect(custos.fracaoDoMesDecorrida, closeTo(15 / 31, 0.0001));
      expect(
        custos.custoAteAgoraCents,
        ((custos.custoRealPessoalCents + custos.frotaCents) * 15 / 31).round() +
            custos.manutencaoPagaCents +
            custos.outrosCustosCents,
      );
      expect(
        custos.percentDaReceita,
        closeTo(custos.custoAteAgoraCents / 132000 * 100, 0.01),
      );
      expect(
        custos.custoAteAgoraCents,
        lessThan(custos.totalCents),
        reason: 'a meio do mês ainda não se incorreu o mês todo',
      );
    });

    test('rubricas da frota separam seguros de prestações', () {
      final rubricas = rubricasFrota(estado, agoraFixa);

      expect(rubricas.prestacoesCents, 11000);
      expect(rubricas.segurosCents, 9000);
      expect(rubricas.combustivelCents, 18000);
    });
  });

  group('Recomendação da semana', () {
    test('devolve uma, e é a mais grave', () {
      final recomendacao = recomendacaoDaSemana(estado, agoraFixa);

      expect(recomendacao, isNotNull);
      expect(recomendacao!.gravidade, GravidadeRecomendacao.urgente);
      expect(
        recomendacao.id,
        'custos-criticos',
        reason:
            'custos a comer 131% da receita é o problema real; o genérico '
            '"pending" (qualquer cêntimo por receber, sem limiar) foi '
            'substituído pelas regras específicas de dívida',
      );
    });

    test('adiada deixa de aparecer até à data', () {
      final adiada = recomendacaoDaSemana(
        estado,
        agoraFixa,
        adiadasAte: {'custos-criticos': agoraFixa.add(const Duration(days: 7))},
      );

      expect(adiada?.id, isNot('custos-criticos'));
    });

    test('sem nada a dizer devolve nulo em vez de conselho genérico', () {
      expect(recomendacaoDaSemana(vazio, agoraFixa), isNull);
    });

    test('a gravidade ordena acima da ordem do motor', () {
      // Sem receita nem dívida, só a regra de refeições (atenção) e a de
      // quarta-feira fraca (oportunidade) se aplicam — a de refeições ganha.
      final comRefeicoes = OperationsState(
        onboarded: true,
        expenses: [
          Expense(
            id: 'refeicao',
            date: agoraFixa,
            amountCents: 5000,
            category: ExpenseCategory.meals,
            status: ExpensePaymentStatus.paid,
          ),
        ],
        machines: const [
          Machine(
            id: 'm1',
            name: 'x',
            reference: 'x',
            category: 'x',
            status: MachineStatus.available,
          ),
        ],
      );

      final r = recomendacaoDaSemana(comRefeicoes, agoraFixa);
      expect(r, isNotNull);
      expect(r!.gravidade, isNot(GravidadeRecomendacao.urgente));
    });
  });

  group('Próximas reservas', () {
    test('devolve no máximo n, por ordem de início', () {
      expect(proximasReservas(estado, agoraFixa, 3).map((b) => b.id), [
        'b-futura',
      ]);
    });
  });
}
