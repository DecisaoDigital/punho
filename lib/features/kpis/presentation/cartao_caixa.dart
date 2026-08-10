import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/kpis/apreciacao.dart';
import '../../../core/operations/caixa.dart';
import '../../../core/operations/operations_controller.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';
import '../../dashboard/presentation/widgets/kpi_grid_2x2.dart';

/// **Caixa** — o que entrou menos o que saiu, do dia 1 até hoje.
///
/// O número grande é só deste mês. A conta vive no catálogo ([kpiCaixa]): é a
/// mesma fonte que a bancada e o painel usam. Este widget é o invólucro que a lê
/// do estado.
class CartaoCaixa extends ConsumerWidget {
  const CartaoCaixa({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      kpiCaixa(ref.watch(operationsProvider), agora ?? DateTime.now());
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
    semTermo:
        'É o teu primeiro mês com registos — ainda não há com que '
        'comparar.',
  );
}
