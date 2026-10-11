import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/kpis/meta_do_mes.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';

/// **Metas** — a pergunta do trimestre.
///
/// Pedido do César (11 Out 2026): a cada trimestre o empresário responde a
/// *quanto prevê que a empresa cresça* nos três meses seguintes, face aos
/// mesmos meses do ano passado. Com a resposta, o painel passa a ter uma «Meta
/// do mês» para cada um deles. A app sugere a média a que a empresa já cresce,
/// mas quem decide é o empresário — é o exercício de gestão que se quer
/// ensinar.
class AbaMetas extends ConsumerWidget {
  const AbaMetas({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final hoje = agora ?? DateTime.now();
    final tt = Theme.of(context).textTheme;
    final sugestao = crescimentoSugerido(estado, hoje);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Quanto prevês crescer?', style: tt.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Em cada trimestre, diz quanto prevês que a empresa cresça face aos '
          'mesmos meses do ano passado. O painel passa a perseguir essa meta, '
          'mês a mês.',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 16),
        _Trimestre(data: hoje, sugestao: sugestao, hoje: hoje),
        const SizedBox(height: 16),
        _Trimestre(
          data: trimestreSeguinte(hoje),
          sugestao: sugestao,
          hoje: hoje,
        ),
      ],
    );
  }
}

class _Trimestre extends ConsumerStatefulWidget {
  const _Trimestre({
    required this.data,
    required this.sugestao,
    required this.hoje,
  });

  final DateTime data;
  final double? sugestao;
  final DateTime hoje;

  @override
  ConsumerState<_Trimestre> createState() => _TrimestreState();
}

class _TrimestreState extends ConsumerState<_Trimestre> {
  late int _pontos = _inicial();

  String get _chave => chaveDoTrimestre(widget.data);

  int _inicial() {
    final guardada = ref.read(operationsProvider).metasDeCrescimento[_chave];
    final base = guardada ?? widget.sugestao ?? 0.1;
    return (base * 100).round().clamp(-50, 100);
  }

  bool get _guardada =>
      ref.read(operationsProvider).metasDeCrescimento[_chave] != null;

  bool get _porGravar {
    final g = ref.read(operationsProvider).metasDeCrescimento[_chave];
    return g == null || (g * 100).round() != _pontos;
  }

  void _guardar() {
    final atuais = ref.read(operationsProvider).metasDeCrescimento;
    ref
        .read(operationsProvider.notifier)
        .updateCompanySettings(
          metasDeCrescimento: {...atuais, _chave: _pontos / 100},
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meta do ${nomeDoTrimestre(widget.data)} guardada.'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(operationsProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final primeiroMes = DateTime(
      widget.data.year,
      (widget.data.month - 1) ~/ 3 * 3 + 1,
    );
    final factor = 1 + _pontos / 100;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nomeDoTrimestre(widget.data), style: tt.titleSmall),
            const SizedBox(height: 4),
            if (widget.sugestao != null)
              Text(
                'Sugestão: ${_sinal((widget.sugestao! * 100).round())}%, o '
                'crescimento médio que a empresa já teve.',
                style: tt.bodySmall,
              ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _pontos.toDouble(),
                    min: -50,
                    max: 100,
                    divisions: 150,
                    label: '${_sinal(_pontos)}%',
                    onChanged: (v) => setState(() => _pontos = v.round()),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${_sinal(_pontos)}%',
                    textAlign: TextAlign.end,
                    style: tt.titleLarge,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 3; i++)
                  _MesDaMeta(
                    mes: DateTime(primeiroMes.year, primeiroMes.month + i),
                    factor: factor,
                    estado: estado,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _porGravar ? _guardar : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(_guardada ? 'Atualizar meta' : 'Guardar meta'),
                ),
                if (!_guardada) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Por responder',
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MesDaMeta extends StatelessWidget {
  const _MesDaMeta({
    required this.mes,
    required this.factor,
    required this.estado,
  });

  final DateTime mes;
  final double factor;
  final OperationsState estado;

  static const _nomes = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final base = recebidoNoMes(estado, DateTime(mes.year - 1, mes.month));
    return Text(
      base <= 0
          ? '${_nomes[mes.month - 1]}: sem ${_nomes[mes.month - 1]} do ano passado'
          : '${_nomes[mes.month - 1]}: ${(base * factor / 100).round()} €',
      style: tt.bodyMedium,
    );
  }
}

String _sinal(int n) => n >= 0 ? '+$n' : '−${n.abs()}';
