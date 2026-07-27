import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../../../finance/presentation/finance_pages.dart';
import '../../kpis/recomendacao_do_dia.dart';
import '../todas_metricas_page.dart';
import '../widgets/graficos.dart';
import '../widgets/kpi_grid_2x2.dart';
import '../widgets/recomendacao_card.dart';
import '../widgets/slide_header.dart';

const _verde100 = Color(0xFFEAF3DE);
const _verde800 = Color(0xFF27500A);
const _amber100 = Color(0xFFFAEEDA);
const _amber800 = Color(0xFF854F0B);

const mesesDoAno = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Slide 1 — Dinheiro do mês.
///
/// Pergunta: estou a facturar o esperado? Preciso de cobrar?
///
/// Três KPIs de dinheiro — entrou, falta entrar, saiu — e uma acção sugerida
/// para hoje. A quarta célula era o "Resultado provisório" (recebido − pago),
/// que repetia dois números já visíveis acima e não dizia o que fazer; deu
/// lugar à [RecomendacaoDoDiaCard].
class DinheiroSlide extends ConsumerStatefulWidget {
  const DinheiroSlide({super.key, required this.agora, this.aoIrParaSlide});

  final DateTime agora;

  /// Salta para outro slide do carrossel (0-based). É o painel que o fornece —
  /// as CTA da recomendação levam ao slide dos custos e ao do pipeline.
  final void Function(int)? aoIrParaSlide;

  @override
  ConsumerState<DinheiroSlide> createState() => _DinheiroSlideState();
}

class _DinheiroSlideState extends ConsumerState<DinheiroSlide> {
  /// Mês em foco, **partilhado** pelos três KPIs de dinheiro: recuar no
  /// "Recebido" e deixar o "Pago" no mês actual dava duas verdades no mesmo
  /// ecrã. A recomendação do dia fica sempre no mês actual — recomendar sobre
  /// um mês passado não faz sentido.
  late final ValueNotifier<DateTime> _mes;

  @override
  void initState() {
    super.initState();
    _mes = ValueNotifier(DateTime(widget.agora.year, widget.agora.month));
  }

  @override
  void dispose() {
    _mes.dispose();
    super.dispose();
  }

  bool _eMesActual(DateTime mes) =>
      mes.year == widget.agora.year && mes.month == widget.agora.month;

  void _andarMeses(int passo) =>
      _mes.value = DateTime(_mes.value.year, _mes.value.month + passo);

  /// Antes do primeiro registo não há nada para trás: as setas param aí em vez
  /// de deixarem o gestor a passear por meses vazios.
  bool _temAlgoAntesDe(DateTime mes) {
    final limite = DateTime(mes.year, mes.month);
    return ref
        .read(operationsProvider)
        .receipts
        .any((r) => r.date.isBefore(limite)) ||
        ref.read(operationsProvider).expenses.any((e) => e.date.isBefore(limite));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final mesActual = tesourariaDoMes(state, widget.agora);
    final cobrancas = cobrancasPorReceber(state, widget.agora);
    final atrasadas = cobrancas
        .where((c) => c.diasDeAtraso > diasParaAtrasoGrave)
        .toList();
    final porReceber = cobrancas.fold(0, (soma, c) => soma + c.emDividaCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.wallet_outlined,
          nome: 'Dinheiro do mês',
          pergunta: 'Estou a facturar o esperado? Preciso de cobrar?',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: mesActual.semMovimentos && porReceber == 0
              ? const _SemMovimentos()
              : ValueListenableBuilder<DateTime>(
                  valueListenable: _mes,
                  builder: (context, mes, _) {
                    final foco = tesourariaDoMes(state, mes);
                    final noMesActual = _eMesActual(mes);
                    final setas = _SetasDeMes(
                      aoRecuar: _temAlgoAntesDe(mes)
                          ? () => _andarMeses(-1)
                          : null,
                      aoAvancar: noMesActual ? null : () => _andarMeses(1),
                    );
                    return KpiGrid2x2(
                      heroi: _Recebido(
                        mes: foco,
                        noMesActual: noMesActual,
                        diaDeHoje: noMesActual ? widget.agora.day : null,
                        setas: setas,
                      ),
                      cimaDireita: _PorReceber(
                        totalCents: porReceber,
                        clientes: cobrancas.length,
                        atrasadas: atrasadas.length,
                        noMesActual: noMesActual,
                      ),
                      baixoEsquerda: _Pago(
                        mes: mes,
                        pagoCents: foco.pagoCents,
                        noMesActual: noMesActual,
                        setas: setas,
                        // Zero despesas pagas num mês é verdade; zero despesas
                        // registadas de sempre é falta de dados, e um "0,00 €"
                        // ali diria ao gestor que não tem custos.
                        temDespesas: state.expenses.any((e) => !e.archived),
                      ),
                      baixoDireita: _RecomendacaoDoDia(
                        agora: widget.agora,
                        aoIrParaSlide: widget.aoIrParaSlide,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A partir de quantos dias um atraso passa a ser assinalado.
const diasParaAtrasoGrave = 15;

/// As setas de mês. O mesmo par em dois cards, com o mesmo estado por trás.
class _SetasDeMes extends StatelessWidget {
  const _SetasDeMes({required this.aoRecuar, required this.aoAvancar});
  final VoidCallback? aoRecuar, aoAvancar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: aoRecuar,
        icon: const Icon(Icons.chevron_left, size: 20),
        tooltip: 'Mês anterior',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
      IconButton(
        onPressed: aoAvancar,
        icon: const Icon(Icons.chevron_right, size: 20),
        tooltip: 'Mês seguinte',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    ],
  );
}

class _Recebido extends StatelessWidget {
  const _Recebido({
    required this.mes,
    required this.noMesActual,
    required this.diaDeHoje,
    required this.setas,
  });

  final TesourariaMes mes;
  final bool noMesActual;
  final int? diaDeHoje;
  final Widget setas;

  @override
  Widget build(BuildContext context) => KpiCard(
    fundo: _verde100,
    titulo: noMesActual
        ? 'Recebido este mês'
        : 'Recebido em ${mesesDoAno[mes.mes.month - 1]}',
    acaoNoTitulo: setas,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KpiValor(euros(mes.recebidoCents), cor: _verde800, tamanho: 40),
        const SizedBox(height: 4),
        KpiTendencia(
          variacao: mes.variacaoVsMesAnterior,
          sufixo: 'vs mês anterior',
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SparklineDiaria(
            valores: mes.serieDiariaCents,
            destacarIndice: diaDeHoje == null ? null : diaDeHoje! - 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Por dia, ao longo do mês',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _PorReceber extends ConsumerWidget {
  const _PorReceber({
    required this.totalCents,
    required this.clientes,
    required this.atrasadas,
    required this.noMesActual,
  });

  final int totalCents;
  final int clientes, atrasadas;
  final bool noMesActual;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KpiCard(
    fundo: _amber100,
    titulo: 'Por receber',
    // Sem setas de propósito: a dívida é uma fotografia de agora e o modelo não
    // guarda como ela estava no fim de cada mês. Ver o doc da v0.0.5.
    hint: noMesActual ? null : 'só o mês actual',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KpiValor(euros(totalCents), cor: _amber800),
        const SizedBox(height: 4),
        Text(
          clientes == 0
              ? 'Nada em dívida'
              : '$clientes ${clientes == 1 ? 'reserva' : 'reservas'}'
                    '${atrasadas == 0 ? '' : ' · $atrasadas há > $diasParaAtrasoGrave dias'}',
          style: const TextStyle(fontSize: 12, color: _amber800),
        ),
        const Spacer(),
        if (clientes > 0)
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

class _Pago extends StatelessWidget {
  const _Pago({
    required this.mes,
    required this.pagoCents,
    required this.noMesActual,
    required this.setas,
    required this.temDespesas,
  });

  final DateTime mes;
  final int pagoCents;
  final bool noMesActual;
  final Widget setas;

  /// Se a empresa já registou alguma despesa. Sem nenhuma, o zero não é um
  /// zero — é falta de dados.
  final bool temDespesas;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: noMesActual
        ? 'Pago este mês'
        : 'Pago em ${mesesDoAno[mes.month - 1]}',
    acaoNoTitulo: setas,
    child: temDespesas
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiValor(euros(pagoCents), tamanho: 28),
              const SizedBox(height: 4),
              Text(
                'Salários · seguros · manutenção · outras despesas pagas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          )
        : const KpiPorApurar(
            explicacao: 'Ainda não registaste nenhuma despesa.',
          ),
  );
}

/// A quarta célula: o que fazer hoje.
class _RecomendacaoDoDia extends ConsumerWidget {
  const _RecomendacaoDoDia({required this.agora, required this.aoIrParaSlide});
  final DateTime agora;
  final void Function(int)? aoIrParaSlide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugestao = recomendacaoDoDia(ref.watch(operationsProvider), agora);
    return RecomendacaoCard(
      titulo: 'Recomendação do dia',
      gravidade: sugestao?.gravidade,
      vazio: 'Sem sugestão para hoje',
      texto: sugestao?.texto,
      cta: sugestao?.cta,
      aoTocarNaCta: sugestao == null
          ? null
          : () => _seguir(context, ref, sugestao.accao),
    );
  }

  void _seguir(BuildContext context, WidgetRef ref, AccaoDoDia accao) {
    switch (accao) {
      case AccaoDoDia.fichaCliente:
        // Não existe ecrã de ficha individual de cliente; leva-se à área.
        ref.read(navigationProvider.notifier).goTo(AppDestination.clients);
      case AccaoDoDia.slideCustos:
        aoIrParaSlide?.call(3);
      case AccaoDoDia.slidePipeline:
        aoIrParaSlide?.call(1);
      case AccaoDoDia.todasAsMetricas:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TodasMetricasPage()),
        );
    }
  }
}

class _SemMovimentos extends StatelessWidget {
  const _SemMovimentos();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 44,
          color: Color(0xFF6B6A64),
        ),
        const SizedBox(height: 12),
        Text(
          'Ainda sem movimentos este mês',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Regista o primeiro recebimento para o painel ter o que dizer.',
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (context) => FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RegisterReceiptPage(),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Registar recebimento'),
          ),
        ),
      ],
    ),
  );
}
