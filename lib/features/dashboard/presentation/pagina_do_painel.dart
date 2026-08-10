import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import 'kpi_catalogo.dart';
import 'widgets/grelha_de_kpis.dart';

/// **Um ecrã do painel: até quatro KPIs, na ordem em que o gestor os pôs.**
///
/// Antes eram três slides escritos à mão — Síntese, Operacional, Procura —,
/// cada um com as suas quatro células fixas. Diziam a mesma coisa a todas as
/// empresas, e à maior parte delas diziam "aguarda" quatro vezes. Aqui a
/// página não sabe que KPIs são: recebe ids, vai buscá-los ao [catalogoKpis] e
/// arruma-os na mesma grelha de sempre.
///
/// Existe como widget próprio, e público, para os testes poderem afirmar sobre
/// as células sem terem de montar o painel inteiro e navegar até à página
/// certa.
class PaginaDoPainel extends ConsumerWidget {
  const PaginaDoPainel({super.key, required this.ids, this.agora});

  /// Os ids do catálogo a mostrar, por ordem. Mais de quatro não cabem na
  /// grelha — quem pagina é o painel.
  final List<String> ids;

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    return GrelhaDeKpis(
      celulas: [
        for (final id in ids)
          if (kpiPorId(id) case final kpi?)
            AbrirDestinoDoKpi(
              destino: kpi.destino,
              child: kpi.celula(estado, now),
            ),
      ],
    );
  }
}

/// Torna uma célula tocável e leva ao destino operacional correspondente.
///
/// É o padrão editorial da Decisão 7 — cada leitura tem de ter caminho para o
/// sítio onde se age sobre ela. Sem destino, devolve a célula tal como está:
/// um `InkWell` que não vai a lado nenhum é uma promessa por cumprir.
class AbrirDestinoDoKpi extends ConsumerWidget {
  const AbrirDestinoDoKpi({
    super.key,
    required this.destino,
    required this.child,
  });

  final AppDestination? destino;
  final Widget child;

  static final _canto = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destino = this.destino;
    if (destino == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: _canto,
      child: InkWell(
        borderRadius: _canto,
        onTap: () => ref.read(navigationProvider.notifier).goTo(destino),
        child: child,
      ),
    );
  }
}
