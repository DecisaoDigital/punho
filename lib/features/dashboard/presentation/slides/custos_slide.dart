import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/finance/regime_fiscal.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../todas_metricas_page.dart';
import '../widgets/graficos.dart';
import '../widgets/kpi_grid_2x2.dart';
import '../widgets/slide_header.dart';

/// Slide 4 — Custos operacionais.
///
/// Pergunta: estou dentro do orçamento? Onde posso cortar?
///
/// Os três primeiros cards são as rubricas que mexem mais (equipa, veículos,
/// manutenção) e o quarto é o juízo sobre elas: quanto da receita é que os
/// custos comem. É esse que diz se há problema.
class CustosSlide extends ConsumerWidget {
  const CustosSlide({super.key, required this.agora});
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final custos = custosMesAgregados(state, agora);
    final temFrota =
        state.hasFleet && state.vehicles.where((v) => !v.archived).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.savings_outlined,
          nome: 'Custos operacionais',
          pergunta: 'Estou dentro do orçamento? Onde posso cortar?',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: KpiGrid2x2(
            heroi: _Colaboradores(
              custos: custos,
              pessoal: custoRealComPessoalMes(
                state,
                regime: regimeDaFormaJuridica(state.legalForm),
              ),
            ),
            cimaDireita: temFrota
                ? _Frota(custos: custos, rubricas: rubricasFrota(state, agora))
                : _OutrosCustos(custos: custos),
            baixoEsquerda: _Manutencao(custos: custos),
            baixoDireita: _PesoDosCustos(custos: custos),
          ),
        ),
      ],
    );
  }
}

class _Colaboradores extends StatelessWidget {
  const _Colaboradores({required this.custos, required this.pessoal});
  final CustosMes custos;

  /// Bruto e TSU patronal, já à luz do regime fiscal da empresa. Vem a `null`
  /// quando o regime não é modelado.
  final ({int? bruto, int? tsuPatronal, int? total}) pessoal;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final total = pessoal.total;
    final tsu = pessoal.tsuPatronal;
    return KpiCard(
      // "Custo real" e não "Custo da equipa": o número grande passou a incluir
      // a TSU patronal, que não aparece em vencimento nenhum. Sem o "real" o
      // gestor lia o valor antigo com o mesmo nome e um número maior.
      titulo: 'Custo real com pessoal',
      hint: 'por mês',
      child: switch ((custos.colaboradoresActivos, total)) {
        (0, _) => const KpiPorApurar(
          explicacao: 'Sem colaboradores activos registados.',
        ),
        // Regime não modelado: não se mostra 0 €, diz-se que não se sabe.
        (_, null) => const KpiPorApurar(
          explicacao:
              'A forma jurídica da empresa não permite estimar a carga '
              'social. Indica-a nas Definições da Empresa.',
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KpiValor(euros(total!), tamanho: 40),
            const SizedBox(height: 6),
            Text(
              'Bruto pago: ${euros(pessoal.bruto!)}'
              '${tsu == null || tsu == 0 ? '' : ' · TSU patronal: ${euros(tsu)}'}',
              style: textos.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${custos.colaboradoresActivos} '
              '${custos.colaboradoresActivos == 1 ? 'colaborador activo' : 'colaboradores activos'}',
              style: textos.bodySmall,
            ),
            const Spacer(),
            Text(
              tsu == null || tsu == 0
                  ? 'Valor declarado nas fichas da equipa, não o que já foi pago.'
                  : 'Inclui a carga social da entidade patronal, que não '
                        'aparece no vencimento. Estimativa.',
              style: textos.bodySmall,
            ),
          ],
        ),
      },
    );
  }
}

class _Frota extends StatelessWidget {
  const _Frota({required this.custos, required this.rubricas});
  final CustosMes custos;
  final RubricasFrota rubricas;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Custo da frota',
    hint: 'por mês',
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KpiValor(euros(custos.frotaCents), tamanho: 26),
        const SizedBox(height: 6),
        Text(
          'Seguros ${euros(rubricas.segurosCents)} · '
          'Prestações ${euros(rubricas.prestacoesCents)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Combustível ${euros(rubricas.combustivelCents)} · '
          'Aluguer ${euros(rubricas.alugueresCents)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

/// Sem veículos, o card não fica vazio: passa a mostrar o resto dos custos
/// pagos no mês, que é a informação equivalente para quem não tem frota.
class _OutrosCustos extends StatelessWidget {
  const _OutrosCustos({required this.custos});
  final CustosMes custos;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Outros custos operacionais',
    hint: 'pagos este mês',
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KpiValor(euros(custos.outrosCustosCents), tamanho: 26),
        const SizedBox(height: 6),
        Text(
          custos.custosFixosDeclaradosCents == null
              ? 'Custos fixos mensais por declarar nas Definições.'
              : 'Declarou ${euros(custos.custosFixosDeclaradosCents!)} de custos fixos por mês.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _Manutencao extends StatelessWidget {
  const _Manutencao({required this.custos});
  final CustosMes custos;

  @override
  Widget build(BuildContext context) {
    final media = custos.manutencaoMedia6MesesCents;
    return KpiCard(
      titulo: 'Manutenção paga',
      hint: 'este mês',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KpiValor(euros(custos.manutencaoPagaCents), tamanho: 26),
          const SizedBox(height: 4),
          if (media == null || media == 0)
            Text(
              'Sem histórico suficiente para comparar.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            KpiTendencia(
              variacao: (custos.manutencaoPagaCents - media) / media * 100,
              sufixo: 'vs média de 6 meses',
              maisEMelhor: false,
            ),
        ],
      ),
    );
  }
}

/// O KPI-resumo do slide: peso dos custos na receita.
class _PesoDosCustos extends StatelessWidget {
  const _PesoDosCustos({required this.custos});
  final CustosMes custos;

  @override
  Widget build(BuildContext context) {
    final percent = custos.percentDaReceita;
    final cor = percent == null
        ? const Color(0xFF6B6A64)
        : percent < 60
        ? const Color(0xFF639922)
        : percent <= 80
        ? const Color(0xFFE0A32B)
        : const Color(0xFFE24B4A);
    return KpiCard(
      titulo: 'Custos sobre a receita',
      corDoBordo: cor,
      rodape: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TodasMetricasPage()),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Ver todas as métricas →'),
        ),
      ),
      child: percent == null
          ? const KpiPorApurar(
              explicacao:
                  'Sem receita este mês não há proporção para calcular.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KpiValor(percentagem(percent), cor: cor, tamanho: 28),
                const SizedBox(height: 6),
                BarraHorizontal(
                  rotulo: 'Custos ${euros(custos.totalCents)}',
                  valor: 'Receita ${euros(custos.receitaMesCents)}',
                  fraccao: percent / 100,
                  cor: cor,
                ),
                Text(
                  percent < 60
                      ? 'Dentro do razoável.'
                      : percent <= 80
                      ? 'Aperta. Vale a pena olhar às rubricas maiores.'
                      : 'Os custos estão a comer quase tudo o que entra.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
