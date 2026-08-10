import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/operations/operations_controller.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';

/// **Tendência do mês** — a futurologia do crescimento, sempre face ao mês
/// passado.
///
/// Não é a mesma leitura de "Dinheiros que entraram": esse mostra o dinheiro que
/// **entrou** e mede-se contra o **homólogo** (o mesmo mês do ano passado), que é
/// a comparação sazonal. Este é de **crescimento** — momentum mês-a-mês — e por
/// isso compara **sempre com o mês anterior**, nunca com o homólogo.
///
/// A conta vive no catálogo ([kpiTendencia]): é a mesma fonte que a bancada e o
/// painel usam. Este widget é só o invólucro que a lê do estado.
class CartaoTendencia extends ConsumerWidget {
  const CartaoTendencia({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      kpiTendencia(ref.watch(operationsProvider), agora ?? DateTime.now());
}
