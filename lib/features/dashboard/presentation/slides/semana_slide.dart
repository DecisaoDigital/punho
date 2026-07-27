import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/guidance/guidance_engine.dart';
import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../../../tarefas/data/tarefas_service.dart';
import '../../../tarefas/domain/tarefa.dart';
import '../../recomendacao_providers.dart';
import '../widgets/kpi_grid_2x2.dart';
import '../widgets/slide_header.dart';

/// Slide 5 — A minha semana.
///
/// Pergunta: o que faço hoje/esta semana?
///
/// É o slide da acção: uma recomendação (uma, não uma pilha), o que está
/// marcado, o que está pendente e o que há a cobrar.
class SemanaSlide extends ConsumerWidget {
  const SemanaSlide({super.key, required this.agora});
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final adiadas = ref.watch(recomendacoesAdiadasProvider);
    final recomendacao = recomendacaoDaSemana(
      state,
      agora,
      adiadasAte: adiadas,
    );
    final tarefas = ref.watch(tarefasProvider);
    final cobrancas = cobrancasPorReceber(
      state,
      agora,
      minimoDiasAtraso: diasParaCobrancaUrgente,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.emoji_objects_outlined,
          nome: 'A minha semana',
          pergunta: 'O que faço hoje e esta semana?',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: KpiGrid2x2(
            heroi: _Recomendacao(recomendacao: recomendacao, agora: agora),
            cimaDireita: _ProximasReservas(
              reservas: proximasReservas(state, agora, 3),
              state: state,
            ),
            baixoEsquerda: _Tarefas(tarefas: tarefas),
            baixoDireita: _Cobrancas(cobrancas: cobrancas),
          ),
        ),
      ],
    );
  }
}

/// Cor do bordo por gravidade. Verde é convite, laranja é aviso, vermelho é
/// risco a acontecer agora.
Color corDaGravidade(GravidadeRecomendacao? gravidade) => switch (gravidade) {
  GravidadeRecomendacao.oportunidade => const Color(0xFF639922),
  GravidadeRecomendacao.atencao => const Color(0xFFE0A32B),
  GravidadeRecomendacao.urgente => const Color(0xFFE24B4A),
  null => const Color(0xFF9AA5AC),
};

class _Recomendacao extends ConsumerWidget {
  const _Recomendacao({required this.recomendacao, required this.agora});
  final Recommendation? recomendacao;
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = recomendacao;
    if (r == null) {
      return const KpiCard(
        titulo: 'Recomendação da semana',
        child: KpiPorApurar(
          explicacao:
              'Nada a assinalar esta semana. Quando os números disserem algo, '
              'aparece aqui.',
        ),
      );
    }
    return KpiCard(
      titulo: 'Recomendação da semana',
      corDoBordo: corDaGravidade(r.gravidade),
      rodape: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => ref
                  .read(recomendacoesAdiadasProvider.notifier)
                  .adiar(r.id, agora),
              child: const Text('Adiar 7 dias'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => ref
                  .read(recomendacoesAdiadasProvider.notifier)
                  .concluir(r.id, agora),
              child: const Text('Feito'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Alavanca: ${r.lever.label}'),
                labelStyle: const TextStyle(fontSize: 11),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: corDaGravidade(
                  r.gravidade,
                ).withValues(alpha: 0.16),
                side: BorderSide.none,
                label: Text(switch (r.gravidade) {
                  GravidadeRecomendacao.oportunidade => 'Oportunidade',
                  GravidadeRecomendacao.atencao => 'Atenção',
                  GravidadeRecomendacao.urgente => 'Urgente',
                }),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.explanation,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sugestão: ${r.impact}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximasReservas extends StatelessWidget {
  const _ProximasReservas({required this.reservas, required this.state});
  final List reservas;
  final OperationsState state;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Próximas reservas',
    child: reservas.isEmpty
        ? const KpiPorApurar(
            explicacao: 'Sem reservas marcadas para os próximos dias.',
          )
        : ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final reserva in reservas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${nomeDoCliente(state, reserva)} · '
                          '${_maquinasDaReserva(state, reserva)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${reserva.startsAt.day}/${reserva.startsAt.month}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

String _maquinasDaReserva(OperationsState state, dynamic reserva) {
  final nomes = <String>[];
  for (final id in reserva.machineIds as List<String>) {
    for (final maquina in state.machines) {
      if (maquina.id == id) nomes.add(maquina.name);
    }
  }
  return nomes.isEmpty ? 'sem máquina' : nomes.join(', ');
}

class _Tarefas extends ConsumerWidget {
  const _Tarefas({required this.tarefas});
  final List<Tarefa> tarefas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgentes = tarefas
        .where((t) => t.severidade == SeveridadeTarefa.urgente)
        .length;
    return KpiCard(
      titulo: 'Tarefas pendentes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KpiValor(
            '${tarefas.length}',
            tamanho: 28,
            cor: urgentes > 0 ? const Color(0xFFE24B4A) : null,
          ),
          const SizedBox(height: 4),
          Text(
            urgentes == 0
                ? (tarefas.isEmpty ? 'Nada por fazer' : 'Nenhuma urgente')
                : '$urgentes ${urgentes == 1 ? 'urgente' : 'urgentes'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          KpiBotao(
            texto: 'Abrir Tarefas →',
            onPressed: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.tasks),
          ),
        ],
      ),
    );
  }
}

class _Cobrancas extends ConsumerWidget {
  const _Cobrancas({required this.cobrancas});
  final List<CobrancaEmAtraso> cobrancas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = cobrancas.fold(0, (soma, c) => soma + c.emDividaCents);
    return KpiCard(
      titulo: 'Cobranças com atraso',
      hint: '> $diasParaCobrancaUrgente dias',
      corDoBordo: cobrancas.isEmpty ? null : const Color(0xFFE24B4A),
      child: cobrancas.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KpiValor('0', cor: Color(0xFF27500A), tamanho: 28),
                const SizedBox(height: 4),
                Text(
                  'Ninguém em atraso. ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KpiValor(
                  '${cobrancas.length}',
                  tamanho: 28,
                  cor: const Color(0xFFE24B4A),
                ),
                const SizedBox(height: 2),
                Text(
                  '${euros(total)} · mais antiga há ${cobrancas.first.diasDeAtraso} dias',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                KpiBotao(
                  texto: 'Cobrar →',
                  onPressed: () => ref
                      .read(navigationProvider.notifier)
                      .goTo(AppDestination.clients),
                ),
              ],
            ),
    );
  }
}
