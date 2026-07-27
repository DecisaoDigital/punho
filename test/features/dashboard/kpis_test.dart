import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/guidance/guidance_engine.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
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

    test('a série diária tem um valor por dia e põe o dinheiro no dia certo', () {
      final mes = tesourariaDoMes(estado, agoraFixa);

      expect(mes.serieDiariaCents, hasLength(31));
      // Recebimento de 900 € a 8 de Julho (índice 7).
      expect(mes.serieDiariaCents[7], 90000);
      expect(mes.serieDiariaCents[0], 0);
    });

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
      expect(funil.contactadas, 2, reason: 'convertida e perdida já foram tocadas');
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
    test('soma equipa declarada, frota e manutenção paga', () {
      final custos = custosMesAgregados(estado, agoraFixa);

      expect(custos.colaboradoresCents, 110000);
      expect(custos.colaboradoresActivos, 2);
      expect(custos.custoMedioPorColaborador, 55000);
      // Prestação 110 € + seguro anual 1080 €/12 = 90 €.
      expect(custos.frotaCents, 11000 + 9000);
      expect(custos.manutencaoPagaCents, 25000);
      expect(custos.outrosCustosCents, 18000, reason: 'só o combustível pago');
    });

    test('média de manutenção usa só os meses com despesas', () {
      final custos = custosMesAgregados(estado, agoraFixa);
      expect(custos.manutencaoMedia6MesesCents, (40000 + 20000) ~/ 2);
    });

    test('peso na receita é nulo sem receita', () {
      expect(custosMesAgregados(vazio, agoraFixa).percentDaReceita, isNull);
    });

    test('peso na receita compara custos com o que entrou', () {
      final custos = custosMesAgregados(estado, agoraFixa);
      expect(
        custos.percentDaReceita,
        closeTo(custos.totalCents / 132000 * 100, 0.01),
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
      expect(recomendacao.id, 'pending', reason: 'dinheiro por receber manda');
    });

    test('adiada deixa de aparecer até à data', () {
      final adiada = recomendacaoDaSemana(
        estado,
        agoraFixa,
        adiadasAte: {'pending': agoraFixa.add(const Duration(days: 7))},
      );

      expect(adiada?.id, isNot('pending'));
    });

    test('sem nada a dizer devolve nulo em vez de conselho genérico', () {
      expect(recomendacaoDaSemana(vazio, agoraFixa), isNull);
    });

    test('a gravidade ordena acima da ordem do motor', () {
      // Motor devolve pending (urgente) primeiro; com ela adiada sobra a de
      // refeições (atenção) e não a inversa.
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
