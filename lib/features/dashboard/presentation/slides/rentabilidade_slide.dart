import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../widgets/graficos.dart';
import '../widgets/kpi_grid_2x2.dart';
import '../widgets/slide_header.dart';

/// Slide 3 — Rentabilidade das máquinas.
///
/// Pergunta: o que está a render? O que está parado sem razão?
///
/// **Máquinas**, não frota: são as que se alugam a clientes. Os veículos da
/// empresa estão no slide dos custos, porque é isso que são — custo, não receita.
class RentabilidadeSlide extends ConsumerWidget {
  const RentabilidadeSlide({super.key, required this.agora});
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final ocupacao = ocupacaoMaquinasSemana(state, agora);
    final top = topMaquinasMaisAlugadas(state, 3);
    final paradas = maquinasSemAluguerHaMaisDe(state, 7, agora);
    final ticket = ticketMedioReserva(state);
    final ticketMesPassado = ticketMedioReserva(
      state,
      desde: DateTime(agora.year, agora.month - 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.build_outlined,
          nome: 'Rentabilidade das máquinas',
          pergunta: 'O que está a render? O que está parado sem razão?',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: KpiGrid2x2(
            heroi: _Ocupacao(ocupacao: ocupacao),
            cimaDireita: _TopMaquinas(top: top),
            baixoEsquerda: _Paradas(paradas: paradas),
            baixoDireita: _Ticket(
              ticketCents: ticket,
              ticketMesPassadoCents: ticketMesPassado,
            ),
          ),
        ),
      ],
    );
  }
}

class _Ocupacao extends StatelessWidget {
  const _Ocupacao({required this.ocupacao});
  final OcupacaoSemana ocupacao;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Ocupação das máquinas',
    hint: 'esta semana',
    child: ocupacao.percent == null
        ? const KpiPorApurar(
            explicacao: 'Sem máquinas registadas não há ocupação para medir.',
          )
        : Row(
            children: [
              AnelPercentagem(percent: ocupacao.percent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KpiTendencia(
                      variacao: ocupacao.tendenciaVsAnterior,
                      sufixo: 'vs semana anterior',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${ocupacao.alugadas} alugadas · '
                      '${ocupacao.disponiveis} disponíveis · '
                      '${ocupacao.paradas} paradas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dias de máquina ocupados sobre os possíveis na semana.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}

class _TopMaquinas extends StatelessWidget {
  const _TopMaquinas({required this.top});
  final List<MaquinaAlugueres> top;

  @override
  Widget build(BuildContext context) {
    final maximo = top.isEmpty
        ? 1
        : top.map((m) => m.alugueres).reduce((a, b) => a > b ? a : b);
    return KpiCard(
      titulo: 'Mais alugadas',
      child: top.isEmpty
          ? const KpiPorApurar(explicacao: 'Ainda não há reservas registadas.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in top)
                  BarraHorizontal(
                    rotulo: item.maquina.name,
                    valor: '${item.alugueres}',
                    fraccao: item.alugueres / maximo,
                  ),
              ],
            ),
    );
  }
}

class _Paradas extends ConsumerWidget {
  const _Paradas({required this.paradas});
  final List<MaquinaSemAluguer> paradas;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KpiCard(
    titulo: 'Sem alugar há mais de 7 dias',
    corDoBordo: paradas.isEmpty ? null : const Color(0xFFE24B4A),
    rodape: paradas.isEmpty
        ? null
        : KpiBotao(
            texto: 'Ver máquinas →',
            onPressed: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.machines),
          ),
    child: paradas.isEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KpiValor('0', cor: Color(0xFF27500A), tamanho: 28),
              const SizedBox(height: 4),
              Text(
                'Todas as máquinas trabalharam na última semana.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiValor('${paradas.length}', tamanho: 28),
              const SizedBox(height: 2),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final item in paradas.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: Color(0xFFE24B4A),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${item.maquina.name} · '
                                '${item.diasSemAluguer == null ? 'nunca alugada' : 'há ${item.diasSemAluguer} dias'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
  );
}

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.ticketCents,
    required this.ticketMesPassadoCents,
  });
  final int? ticketCents, ticketMesPassadoCents;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Valor médio por reserva',
    child: ticketCents == null
        ? const KpiPorApurar(
            explicacao: 'Sem reservas com valor previsto preenchido.',
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiValor(euros(ticketCents!), tamanho: 28),
              const SizedBox(height: 4),
              KpiTendencia(
                variacao:
                    ticketMesPassadoCents == null || ticketMesPassadoCents == 0
                    ? null
                    : (ticketCents! - ticketMesPassadoCents!) /
                          ticketMesPassadoCents! *
                          100,
                sufixo: 'vs mês anterior',
              ),
            ],
          ),
  );
}
