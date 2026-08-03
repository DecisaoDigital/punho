import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../widgets/celula_semaforo.dart';
import '../widgets/grelha_de_kpis.dart';
import '../widgets/slide_header.dart';

/// Slide 3 · Alavanca — Procura e Vendas.
///
/// Pergunta: **que alavanca puxo?** Aquisição de clientes · pipeline ·
/// conversão · ticket médio.
///
/// **Estrutura editorial fixa** que se repete nos slides-alavanca seguintes:
/// cabeçalho + 3-4 KPIs + recomendação canónica + CTA para destino operacional.
///
/// Ligado a dados: não há aqui número escrito à mão. O que não se consegue
/// apurar diz o que falta para o poder apurar.
class ProcuraSlide extends ConsumerWidget {
  const ProcuraSlide({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  static const _janelaDias = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    final funil = funilProcura(estado, now, _janelaDias);
    final porContactar = leadsPorContactar(estado);
    final frias = porContactar
        .where((l) => _dia(now).difference(_dia(l.createdAt)).inDays > 5)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.trending_up_outlined,
          nome: 'Procura e vendas · Alavanca',
          pergunta:
              'Que alavanca puxo? Aquisição · pipeline · conversão · ticket.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: GrelhaDeKpis(
                  celulas: [
                    _clientesNovos(estado, now),
                    _pipeline(porContactar.length, frias),
                    _ticketMedio(estado, now),
                    _conversao(funil),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _CardRecomendacao(
                  funil: funil,
                  leadsFrias: frias,
                  porContactar: porContactar.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _clientesNovos(OperationsState estado, DateTime now) {
    final novos = clientesNovos(estado, now, dias: _janelaDias);
    if (novos == null) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: 'Clientes novos (30d)',
        texto: 'Ainda sem clientes',
        subtexto: 'Contam pela primeira reserva',
      );
    }
    return CelulaSemaforo(
      nivel: novos == 0 ? NivelSemaforo.laranja : NivelSemaforo.verde,
      rotulo: 'Clientes novos (30d)',
      valor: '$novos',
      unidade: novos == 1 ? 'cliente' : 'clientes',
      subtexto: 'Contados pela data da primeira reserva',
      valorEmDestaque: novos > 0,
    );
  }

  Widget _pipeline(int porContactar, int frias) => CelulaSemaforo(
    nivel: frias > 0
        ? NivelSemaforo.vermelho
        : porContactar > 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Leads em pipeline',
    valor: '$porContactar',
    unidade: porContactar == 1 ? 'por contactar' : 'por contactar',
    subtexto: frias > 0
        ? '$frias sem contacto há mais de 5 dias'
        : porContactar == 0
        ? 'Nenhuma lead à espera'
        : 'Todas contactadas nos últimos 5 dias',
  );

  Widget _ticketMedio(OperationsState estado, DateTime now) {
    final ticket = ticketMedioReserva(
      estado,
      desde: _dia(now).subtract(const Duration(days: _janelaDias)),
    );
    if (ticket == null) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: 'Ticket médio (30d)',
        texto: 'Sem reservas com valor',
        subtexto: 'Põe valor nas reservas',
      );
    }
    // Referência: o histórico todo. Sem ela o número não diz se está a subir ou
    // a descer, e um valor isolado não é uma alavanca.
    final historico = ticketMedioReserva(estado);
    final diferenca = historico == null ? null : ticket - historico;
    return CelulaSemaforo(
      nivel: diferenca != null && diferenca < 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Ticket médio (30d)',
      valor: '${(ticket / 100).round()}',
      unidade: '€',
      subtexto: diferenca == null || diferenca == 0
          ? 'Em linha com o histórico'
          : '${diferenca > 0 ? '▲' : '▼'} ${(diferenca.abs() / 100).round()} € '
                'vs média histórica',
      valorEmDestaque: true,
    );
  }

  Widget _conversao(FunilProcura funil) {
    final taxa = funil.taxa;
    if (taxa == null) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: 'Conversão lead → cliente',
        texto: 'Sem leads em 30 dias',
        subtexto: 'Regista quem te procura',
      );
    }
    final anterior = funil.taxaPeriodoAnterior;
    final delta = anterior == null ? null : taxa - anterior;
    return CelulaSemaforo(
      nivel: taxa >= 40
          ? NivelSemaforo.verde
          : taxa >= 20
          ? NivelSemaforo.laranja
          : NivelSemaforo.vermelho,
      rotulo: 'Conversão lead → cliente',
      valor: '${taxa.round()}',
      unidade: '% · ${funil.convertidas} de ${funil.leads}',
      subtexto: delta == null
          ? 'Sem período anterior para comparar'
          : '${delta >= 0 ? '▲' : '▼'} ${delta.abs().round()}pp '
                'vs 30 dias anteriores',
    );
  }
}

DateTime _dia(DateTime data) => DateTime(data.year, data.month, data.day);

/// A recomendação canónica da alavanca: evidência → leitura → acção.
///
/// Só aparece quando o sinal pede. Sem sinal, o cartão diz que não há nada a
/// puxar — em vez de inventar conselho genérico, que é o que faz um gestor
/// deixar de ler recomendações.
class _CardRecomendacao extends ConsumerWidget {
  const _CardRecomendacao({
    required this.funil,
    required this.leadsFrias,
    required this.porContactar,
  });

  final FunilProcura funil;
  final int leadsFrias;
  final int porContactar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final texto = _texto();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.55),
            cs.primaryContainer.withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOMENDAÇÃO CANÓNICA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.clients),
            // `Flexible` com reticências: num telemóvel deitado este cartão
            // tem 40% de 873 dp e o rótulo inteiro não cabe — transbordava 161
            // px pela direita. Encolher o texto é preferível a encolher o
            // alvo de toque.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    porContactar == 0
                        ? 'Abrir Clientes'
                        : 'Abrir Leads ($porContactar)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _texto() {
    if (leadsFrias > 0) {
      return 'Tens $leadsFrias lead${leadsFrias == 1 ? '' : 's'} sem contacto '
          'há mais de 5 dias. Antes de gastar em publicidade, liga a quem já '
          'te procurou — é procura que já pagaste e ainda não trabalhaste.';
    }
    final taxa = funil.taxa;
    if (taxa != null && taxa < 20 && funil.leads >= 3) {
      return 'Chegaram ${funil.leads} leads em 30 dias e fecharam '
          '${funil.convertidas}. O problema não parece ser falta de procura, '
          'é o que acontece depois do primeiro contacto.';
    }
    if (funil.leads == 0) {
      return 'Não entrou nenhuma lead nos últimos 30 dias. Sem procura a '
          'registar, nenhuma das outras leituras desta alavanca tem base.';
    }
    return 'Nada a puxar nesta alavanca hoje. As leads estão contactadas e a '
        'conversão não está a cair.';
  }
}
