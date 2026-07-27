import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../widgets/graficos.dart';
import '../widgets/kpi_grid_2x2.dart';
import '../widgets/slide_header.dart';

const _azul50 = Color(0xFFE6F1FB);
const _azul800 = Color(0xFF0C447C);

/// Slide 2 — Pipeline e compromissos.
///
/// Pergunta: tenho negócio à porta? Preciso de mais leads?
///
/// Os quatro cards são o funil por ordem inversa: o que já está fechado
/// (reservas), o que está no topo à espera (leads), a eficiência com que um vira
/// o outro (conversão) e o dinheiro que já está em casa por conta disso.
class PipelineSlide extends ConsumerWidget {
  const PipelineSlide({super.key, required this.agora});
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final compromissos = compromissosProximos(state, agora);
    final funil = funilProcura(state, agora, 30);
    final porContactar = leadsPorContactar(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.timeline_outlined,
          nome: 'Pipeline e compromissos',
          pergunta: 'Tenho negócio à porta? Preciso de mais leads?',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: KpiGrid2x2(
            heroi: _Confirmadas(compromissos: compromissos, agora: agora),
            cimaDireita: _LeadsPorContactar(leads: porContactar, agora: agora),
            baixoEsquerda: _Conversao(funil: funil),
            baixoDireita: const _Caucoes(),
          ),
        ),
      ],
    );
  }
}

class _Confirmadas extends StatelessWidget {
  const _Confirmadas({required this.compromissos, required this.agora});
  final CompromissosProximos compromissos;
  final DateTime agora;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Reservas confirmadas',
    hint: 'próximas 2 semanas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            KpiValor('${compromissos.reservas.length}', tamanho: 40),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                compromissos.valorPrevistoCents == 0
                    ? 'sem valor previsto'
                    : '${euros(compromissos.valorPrevistoCents)} previstos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: MiniCalendario(
              porDia: compromissos.porDia,
              inicio: DateTime(agora.year, agora.month, agora.day),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LeadsPorContactar extends ConsumerWidget {
  const _LeadsPorContactar({required this.leads, required this.agora});
  final List leads;
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maisAntiga = leads.isEmpty
        ? null
        : agora.difference(leads.first.createdAt).inDays;
    return KpiCard(
      fundo: _azul50,
      titulo: 'Leads por contactar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KpiValor('${leads.length}', cor: _azul800),
          const SizedBox(height: 4),
          Text(
            leads.isEmpty
                ? 'Nenhuma à espera'
                : 'mais antiga há ${maisAntiga == 0 ? 'menos de um dia' : '$maisAntiga dias'}',
            style: const TextStyle(fontSize: 12, color: _azul800),
          ),
          const Spacer(),
          if (leads.isNotEmpty)
            KpiBotao(
              texto: 'Contactar →',
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .goTo(AppDestination.clients),
            ),
        ],
      ),
    );
  }
}

class _Conversao extends StatelessWidget {
  const _Conversao({required this.funil});
  final FunilProcura funil;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Conversão de leads',
    hint: '30 dias',
    child: funil.taxa == null
        ? const KpiPorApurar(explicacao: 'Sem leads no período para converter.')
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiValor(percentagem(funil.taxa), tamanho: 28),
              const SizedBox(height: 2),
              KpiTendencia(
                variacao: funil.taxaPeriodoAnterior == null
                    ? null
                    : funil.taxa! - funil.taxaPeriodoAnterior!,
                sufixo: 'vs 30 dias antes',
              ),
              const SizedBox(height: 8),
              Text(
                '${funil.leads} leads · ${funil.contactadas} contactadas · '
                '${funil.convertidas} convertidas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );
}

/// Cauções não existem no modelo de dados — não há campo onde se registem.
///
/// Mostrar "0 €" seria dizer ao gestor que não tem cauções em mão, o que pode
/// ser falso. Fica declarado como por apurar até o modelo as suportar.
class _Caucoes extends StatelessWidget {
  const _Caucoes();

  @override
  Widget build(BuildContext context) => const KpiCard(
    titulo: 'Cauções em posse',
    child: KpiPorApurar(explicacao: 'As cauções ainda não se registam na app.'),
  );
}
