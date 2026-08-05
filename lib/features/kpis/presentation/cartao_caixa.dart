import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/kpis/apreciacao.dart';
import '../../../core/operations/caixa.dart';
import '../../../core/operations/operations_controller.dart';
import '../../dashboard/presentation/widgets/celula_semaforo.dart';
import '../../dashboard/presentation/widgets/kpi_grid_2x2.dart';

/// **Caixa** — o que entrou menos o que saiu, do dia 1 até hoje.
///
/// O número grande é só deste mês. O acumulado de trás vive no canto superior
/// direito, em corpo pequeno: está lá para quem o procura e não altera a
/// leitura de quem só quer saber como corre o mês. Somá-lo ao valor grande
/// esconderia um mês mau debaixo de uma almofada antiga.
class CartaoCaixa extends ConsumerWidget {
  const CartaoCaixa({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = this.agora ?? DateTime.now();
    final caixa = caixaDoMes(ref.watch(operationsProvider), agora);
    final apreciacao = apreciacaoDaCaixa(ref, agora);
    final saldo = caixa.saldoCents;
    final positivo = saldo >= 0;
    final periodo = '1 a ${caixa.ate.day} de ${_meses[caixa.mes.month - 1]}';

    if (caixa.semMovimentos) {
      // Um "0 €" aqui diria "não facturaste". A verdade é outra: ainda não há
      // nada registado este mês — e `aguarda` é exactamente a cor disso, a
      // que existe para não pintar de laranja quem só ainda não começou.
      return CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: 'Caixa · $periodo',
        texto: 'Sem movimentos este mês',
        subtexto: 'Regista uma entrada ou uma saída e o número aparece.',
      );
    }

    return CelulaSemaforo(
      // A regra de apreciação é que pinta o semáforo: a cor e a frase dizem a
      // mesma coisa, e não podiam sair de sítios diferentes.
      nivel: !positivo
          ? NivelSemaforo.vermelho
          : switch (apreciacao.tom) {
              TomDaApreciacao.abaixo => NivelSemaforo.laranja,
              TomDaApreciacao.semTermo => NivelSemaforo.aguarda,
              _ => NivelSemaforo.verde,
            },
      rotulo: 'Caixa · $periodo',
      valor: '${positivo ? '+' : '−'} ${euros(saldo.abs())}',
      valorEmDestaque: true,
      subtexto: apreciacao.frase,
    );
  }
}

/// **A regra de apreciação da Caixa.** O que faz de um saldo uma boa ou má
/// notícia é o costume da própria empresa: 1 240 € é bom num mês em que a média
/// dá 800 e é mau num em que dá 3 000.
///
/// Não há aqui média de sector nenhuma — não a temos, e inventá-la seria pior
/// do que não dizer nada. A referência é o próprio negócio, no mesmo ponto do
/// mês. Ver [mediaDosMesesAnteriores].
ApreciacaoDoKpi apreciacaoDaCaixa(WidgetRef ref, DateTime agora) {
  final state = ref.watch(operationsProvider);
  return apreciar(
    valor: caixaDoMes(state, agora).saldoCents,
    referencia: mediaDosMesesAnteriores(state, agora),
    nomeDaReferencia: 'a tua média',
    formatar: (cents) => euros(cents.round()),
    semTermo: 'É o teu primeiro mês com registos — ainda não há com que '
        'comparar.',
  );
}
