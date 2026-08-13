import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/kpis/atencao.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/kpis_da_cadeia.dart';
import '../../../core/operations/operations_controller.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';
import '../../dashboard/presentation/widgets/kpi_grid_2x2.dart';

/// **O ecrã de atenção** — o que está por trás de um número.
///
/// É onde a cadeia serve para alguma coisa. Um KPI mau, sozinho, é uma
/// acusação: o lucro caiu, e depois? Aqui o número tem a explicação por baixo —
/// qual das parcelas se mexeu, quanto, e para onde ir tratar disso.
///
/// **Chega-se cá tocando num KPI que tenha filhos.** Uma folha não tem nada
/// para desdobrar, e por isso continua a levar directamente ao ecrã onde se
/// age: abrir uma página que só repetisse a célula era um toque a mais para
/// chegar ao mesmo sítio.
///
/// **Deitado é o que manda** (o gestor trabalha com o telemóvel deitado), mas
/// em pé tem de funcionar: por isso é uma lista que rola, e não uma grelha com
/// medidas fixas.
class CadeiaDoKpiPage extends ConsumerWidget {
  const CadeiaDoKpiPage({super.key, required this.kpiId, this.agora});

  final String kpiId;

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  static Future<void> abrir(
    BuildContext context, {
    required String kpiId,
    DateTime? agora,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CadeiaDoKpiPage(kpiId: kpiId, agora: agora),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpi = kpiPorId(kpiId);
    final estado = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    final tt = Theme.of(context).textTheme;

    if (kpi == null) {
      // Um id que esta versão da app não conhece — painel arrumado numa app
      // mais nova. Diz-se, em vez de mostrar um ecrã vazio.
      return Scaffold(
        appBar: AppBar(title: const Text('Indicador')),
        body: const Center(
          child: Text('Este indicador não existe nesta versão.'),
        ),
      );
    }

    final filhos = filhosDe(kpi.id);
    final destino = kpi.destino;

    return Scaffold(
      appBar: AppBar(title: Text(kpi.titulo)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: MargensDoCanvas.lateral,
            vertical: MargensDoCanvas.vertical,
          ),
          children: [
            _Migalhas(kpiId: kpi.id, agora: agora),
            const SizedBox(height: 12),
            // A célula da grelha 2×2 conta com a altura que a grelha lhe dá;
            // solta numa lista pede altura infinita e rebenta o layout. A
            // deitada é a que serve uma linha da largura toda — e a altura é a
            // medida, `AlturaDoKpi.deitado`, não um número inventado aqui.
            SizedBox(
              height: AlturaDoKpi.deitado,
              child: kpi.celula(estado, now).deitada(),
            ),
            const SizedBox(height: 16),
            _Comparacao(kpiId: kpi.id, estado: estado, now: now),
            if (kpi.id == 'lucro-mes')
              _Explicacao(estado: estado, now: now, agora: agora),
            if (filhos.isNotEmpty) ...[
              Text('O que está por trás deste número', style: tt.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Toca num deles para descer mais um degrau.',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 10),
              for (final filho in filhos) ...[
                _Degrau(kpi: filho, estado: estado, now: now, agora: agora),
                const SizedBox(height: 8),
              ],
            ],
            if (destino != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  // Fecha a pilha da cadeia antes de mudar de secção: quem foi
                  // agir não quer voltar a três ecrãs de explicação.
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  ref.read(navigationProvider.notifier).goTo(destino);
                },
                icon: Icon(destino.icon),
                label: Text('Ir a ${destino.label}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// De onde é que este número vem: `Caixa › Lucro do mês › Vendas do mês`.
///
/// Quem desce três degraus tem de poder ver o caminho sem carregar em «voltar»
/// às cegas — e tem de poder saltar directamente para qualquer degrau acima.
class _Migalhas extends StatelessWidget {
  const _Migalhas({required this.kpiId, required this.agora});

  final String kpiId;
  final DateTime? agora;

  @override
  Widget build(BuildContext context) {
    final acima = caminhoAteARaiz(kpiId).skip(1).toList().reversed.toList();
    if (acima.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final k in acima) ...[
          InkWell(
            onTap: () =>
                CadeiaDoKpiPage.abrir(context, kpiId: k.id, agora: agora),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                k.titulo,
                style: tt.bodySmall?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Text(' › ', style: tt.bodySmall),
        ],
      ],
    );
  }
}

/// Os três meses lado a lado: este, o passado, e o mesmo do ano passado.
///
/// Pedido do César (13 Ago 2026): *«na realidade eu ali gostava de ver o lucro
/// do mês anterior»*. A célula só cabe com **um** termo de comparação — e
/// escolhe o homólogo, que num negócio com estações é o que diz mais. Só que
/// assim o mês passado, que é o que ele tem fresco na cabeça, não aparecia em
/// lado nenhum. Aqui há espaço para os três, e ver os três juntos é o que
/// distingue uma queda sazonal de uma queda a sério.
///
/// Um mês sem uma única linha escreve-se «sem registos» — não 0 €, que era
/// dizer que o mês correu mal quando o que houve foi não haver mês.
class _Comparacao extends StatelessWidget {
  const _Comparacao({
    required this.kpiId,
    required this.estado,
    required this.now,
  });

  final String kpiId;
  final OperationsState estado;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = comparadoDoKpi(kpiId, estado, now);
    if (m == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;

    Widget linha(String rotulo, int? cents, {bool destaque = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: tt.bodySmall)),
          Text(
            cents == null ? 'sem registos' : '${_euros(cents)} €',
            style: destaque
                ? tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                : tt.bodySmall,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          linha('Este mês', m.valorCents, destaque: true),
          linha('Mês passado', m.mesAnteriorCents),
          linha('Mesmo mês do ano passado', m.homologoCents),
        ],
      ),
    );
  }
}

/// Euros inteiros, com o menos tipográfico quando o mês deu prejuízo.
String _euros(int cents) {
  final valor = (cents / 100).round();
  return valor < 0 ? '− ${valor.abs()}' : '$valor';
}

/// A frase que nomeia o culpado, com as parcelas por baixo.
class _Explicacao extends StatelessWidget {
  const _Explicacao({
    required this.estado,
    required this.now,
    required this.agora,
  });

  final OperationsState estado;
  final DateTime now;
  final DateTime? agora;

  @override
  Widget build(BuildContext context) {
    final atencao = atencaoDoLucro(estado, now);
    if (atencao == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fraseDaAtencao(atencao), style: tt.bodyMedium),
              const SizedBox(height: 10),
              for (final p in atencao.parcelas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      // O sinal é o do **efeito no lucro**, não o da parcela:
                      // uma estrutura que sobe leva seta para baixo, porque foi
                      // isso que fez ao lucro. Sem esta orientação, três setas
                      // para cima podiam ser duas boas notícias e uma má.
                      Text(p.ajudou ? '▲' : '▼'),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.nome, style: tt.bodySmall)),
                      Text(
                        '${p.efeitoCents >= 0 ? '+' : '−'} '
                        '${(p.efeitoCents.abs() / 100).round()} €',
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um filho da cadeia: a célula dele, tocável, a descer mais um degrau.
class _Degrau extends StatelessWidget {
  const _Degrau({
    required this.kpi,
    required this.estado,
    required this.now,
    required this.agora,
  });

  final KpiDefinicao kpi;
  final OperationsState estado;
  final DateTime now;
  final DateTime? agora;

  @override
  Widget build(BuildContext context) {
    final canto = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: canto,
      child: InkWell(
        borderRadius: canto,
        onTap: () =>
            CadeiaDoKpiPage.abrir(context, kpiId: kpi.id, agora: agora),
        child: SizedBox(
          height: AlturaDoKpi.deitado,
          child: kpi.celula(estado, now).deitada(),
        ),
      ),
    );
  }
}
