import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../../../../core/theme/punho_theme.dart';
import '../../../finance/presentation/finance_pages.dart';
import '../widgets/graficos.dart';
import '../widgets/kpi_grid_2x2.dart';
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
/// Os quatro cards lêem-se em conjunto: entrou (herói), falta entrar, saiu, e o
/// que sobra. A 4ª célula está isolada em [_ResultadoProvisorio] de propósito —
/// a variante "2-3 KPIs + recomendação do dia" que o Cesar quer explorar troca
/// só esse widget.
class DinheiroSlide extends ConsumerStatefulWidget {
  const DinheiroSlide({super.key, required this.agora});
  final DateTime agora;

  @override
  ConsumerState<DinheiroSlide> createState() => _DinheiroSlideState();
}

class _DinheiroSlideState extends ConsumerState<DinheiroSlide> {
  /// Mês em foco no card do "Recebido". Só este KPI navega no tempo nesta
  /// versão; os outros três mostram sempre o mês corrente, senão o slide
  /// deixava de se ler como um conjunto.
  late DateTime _mes;

  @override
  void initState() {
    super.initState();
    _mes = DateTime(widget.agora.year, widget.agora.month);
  }

  bool get _noMesActual =>
      _mes.year == widget.agora.year && _mes.month == widget.agora.month;

  void _andarMeses(int passo) =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + passo));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final mesFoco = tesourariaDoMes(state, _mes);
    final mesActual = tesourariaDoMes(state, widget.agora);
    final cobrancas = cobrancasPorReceber(state, widget.agora);
    final atrasadas = cobrancas
        .where((c) => c.diasDeAtraso > diasParaAtrasoGrave)
        .toList();
    final porReceber = cobrancas.fold(0, (soma, c) => soma + c.emDividaCents);
    final resultado = resultadoMesConservador(state, widget.agora);

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
              : KpiGrid2x2(
                  heroi: _Recebido(
                    mes: mesFoco,
                    noMesActual: _noMesActual,
                    diaDeHoje: _noMesActual ? widget.agora.day : null,
                    aoRecuar: () => _andarMeses(-1),
                    aoAvancar: _noMesActual ? null : () => _andarMeses(1),
                  ),
                  cimaDireita: _PorReceber(
                    totalCents: porReceber,
                    clientes: cobrancas.length,
                    atrasadas: atrasadas.length,
                  ),
                  baixoEsquerda: _Pago(pagoCents: mesActual.pagoCents),
                  baixoDireita: _ResultadoProvisorio(resultadoCents: resultado),
                ),
        ),
      ],
    );
  }
}

/// A partir de quantos dias um atraso passa a ser assinalado.
const diasParaAtrasoGrave = 15;

class _Recebido extends StatelessWidget {
  const _Recebido({
    required this.mes,
    required this.noMesActual,
    required this.diaDeHoje,
    required this.aoRecuar,
    required this.aoAvancar,
  });

  final TesourariaMes mes;
  final bool noMesActual;
  final int? diaDeHoje;
  final VoidCallback aoRecuar;
  final VoidCallback? aoAvancar;

  @override
  Widget build(BuildContext context) => KpiCard(
    fundo: _verde100,
    titulo: noMesActual
        ? 'Recebido este mês'
        : 'Recebido em ${mesesDoAno[mes.mes.month - 1]}',
    acaoNoTitulo: Row(
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
    ),
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
  });

  final int totalCents;
  final int clientes, atrasadas;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KpiCard(
    fundo: _amber100,
    titulo: 'Por receber',
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
  const _Pago({required this.pagoCents});
  final int pagoCents;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Pago este mês',
    child: Column(
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
    ),
  );
}

/// A 4ª célula do slide. Trocar isto por um card de recomendação é a única
/// edição necessária para experimentar a variante "2-3 KPIs + recomendação".
class _ResultadoProvisorio extends StatelessWidget {
  const _ResultadoProvisorio({required this.resultadoCents});
  final int? resultadoCents;

  @override
  Widget build(BuildContext context) => KpiCard(
    titulo: 'Resultado provisório',
    corDoBordo: PunhoTheme.orange,
    child: resultadoCents == null
        ? const KpiPorApurar(
            explicacao: 'Sem movimentos este mês ainda não há resultado.',
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiValor(
                '${resultadoCents! >= 0 ? '' : '−'}'
                '${euros(resultadoCents!.abs())}',
                cor: resultadoCents! >= 0 ? _verde800 : const Color(0xFFB3261E),
                tamanho: 28,
              ),
              const SizedBox(height: 4),
              Text(
                'Recebido − pago. Faltam as contas por pagar, portanto não é '
                'lucro.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );
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
