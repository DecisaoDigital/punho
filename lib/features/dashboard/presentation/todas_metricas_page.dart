import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guidance/guidance_engine.dart';
import '../../../core/finance/regime_fiscal.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/finance.dart';
import '../../operations/presentation/operational_pages.dart';
import '../../tarefas/data/tarefas_service.dart';
import 'widgets/kpi_grid_2x2.dart';

/// A lista completa, para consulta.
///
/// O painel de gestão mostra 20 números escolhidos e agrupados por decisão; esta
/// página mostra **tudo**, por secções, para quando o gestor quer um valor
/// específico e não uma leitura orientada. Sóbria de propósito: sem gráficos,
/// sem cores dramáticas, sem carrossel. Título à esquerda, valor à direita.
///
/// Todos os valores vêm dos KPIs puros de `core/operations/kpis.dart` — nenhuma
/// conta é refeita aqui. Antes desta reescrita a página recalculava tudo com
/// código próprio, e duas contas para o mesmo número acabam sempre a divergir.
class TodasMetricasPage extends ConsumerWidget {
  const TodasMetricasPage({super.key, this.agora});

  /// Injectável para os testes e capturas. Em produção é `DateTime.now()`.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    final mes = tesourariaDoMes(state, now);
    final cobrancas = cobrancasPorReceber(state, now);
    final atrasadas = cobrancas
        .where((c) => c.diasDeAtraso > diasParaCobrancaUrgente)
        .toList();
    final compromissos = compromissosProximos(state, now);
    final funil = funilProcura(state, now, 30);
    final ocupacao = ocupacaoMaquinasSemana(state, now);
    final semAlugar = maquinasSemAluguerHaMaisDe(state, 7, now);
    final top = topMaquinasMaisAlugadas(state, 3);
    final custos = custosMesAgregados(state, now);
    final rubricas = rubricasFrota(state, now);
    // As três parcelas vêm a `null` quando a forma jurídica não é modelada, e
    // aí as linhas desaparecem em vez de mostrarem 0 € — é o `_Linha.opcional`
    // a fazer o seu trabalho.
    final pessoal = custoRealComPessoalMes(
      state,
      regime: regimeDaFormaJuridica(state.legalForm),
    );
    final recomendacao = recomendacaoDaSemana(state, now);
    final tarefas = ref.watch(tarefasProvider);
    final homologa = state.historicalMonth(now.year - 1, now.month);
    final hoje = DateTime(now.year, now.month, now.day);
    final nota = weeklyManagementNote(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Todas as métricas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text(
              'Os mesmos números do painel, sem hierarquia e por secções. O '
              'painel mostra-os agrupados por decisão a tomar.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),

            _Seccao(
              titulo: 'Dinheiro',
              linhas: [
                _Linha('Recebido este mês', euros(mes.recebidoCents)),
                _Linha(
                  'Recebido no mês anterior',
                  euros(mes.recebidoMesAnteriorCents),
                  sub: mes.variacaoVsMesAnterior == null
                      ? 'Sem termo de comparação'
                      : '${mes.variacaoVsMesAnterior! >= 0 ? '+' : ''}'
                            '${mes.variacaoVsMesAnterior!.toStringAsFixed(0)}% este mês',
                ),
                _Linha(
                  'Recebido hoje',
                  euros(receiptTotal(state.receipts, hoje, now)),
                ),
                _Linha('Pago este mês', euros(mes.pagoCents)),
                _Linha(
                  'Despesas pagas hoje',
                  euros(paidExpenseTotal(state.expenses, hoje, now)),
                ),
                _Linha(
                  'Por pagar',
                  euros(unpaidExpenseTotal(state.expenses)),
                  sub: 'Despesas registadas e ainda não liquidadas',
                ),
                _Linha(
                  'Por receber',
                  euros(cobrancas.fold(0, (s, c) => s + c.emDividaCents)),
                  sub: '${cobrancas.length} reservas · ${atrasadas.length} com '
                      'mais de $diasParaCobrancaUrgente dias',
                ),
                _Linha.opcional(
                  'Resultado provisório (recebido − pago)',
                  resultadoMesConservador(state, now),
                  formatar: euros,
                  sub: 'Faltam as contas por pagar, portanto não é lucro',
                ),
              ],
            ),

            _Seccao(
              titulo: 'Pipeline',
              linhas: [
                _Linha(
                  'Reservas confirmadas nas próximas 2 semanas',
                  '${compromissos.reservas.length}',
                ),
                _Linha(
                  'Valor previsto em reservas confirmadas',
                  euros(compromissos.valorPrevistoCents),
                ),
                _Linha(
                  'Leads por contactar',
                  '${leadsPorContactar(state).length}',
                ),
                _Linha('Leads dos últimos 30 dias', '${funil.leads}'),
                _Linha('Leads contactadas', '${funil.contactadas}'),
                _Linha('Leads convertidas', '${funil.convertidas}'),
                _Linha.opcional(
                  'Conversão a 30 dias',
                  funil.taxa,
                  formatar: (v) => '${v.toStringAsFixed(0)}%',
                ),
              ],
            ),

            _Seccao(
              titulo: 'Máquinas',
              linhas: [
                _Linha(
                  'Máquinas declaradas',
                  '${state.totalMachinesDeclared}',
                ),
                _Linha(
                  'Máquinas identificadas',
                  '${state.registeredMachinesCount}',
                ),
                _Linha(
                  'Máquinas disponíveis',
                  state.hasUnidentifiedDeclaredMachines
                      ? 'Por apurar'
                      : '${availableMachines(state, now)}',
                ),
                _Linha.opcional(
                  'Ocupação desta semana',
                  ocupacao.percent,
                  formatar: (v) => '${v.toStringAsFixed(0)}%',
                  sub: '${ocupacao.alugadas} alugadas · '
                      '${ocupacao.disponiveis} disponíveis',
                ),
                _Linha(
                  'Sem alugar há mais de 7 dias',
                  '${semAlugar.length}',
                  sub: semAlugar.isEmpty
                      ? null
                      : semAlugar
                            .take(3)
                            .map((m) => m.maquina.name)
                            .join(' · '),
                ),
                _Linha(
                  'Máquina mais alugada',
                  top.isEmpty ? 'Por apurar' : top.first.maquina.name,
                  sub: top.isEmpty
                      ? null
                      : '${top.first.alugueres} reservas',
                ),
                _Linha.opcional(
                  'Valor médio por reserva',
                  ticketMedioReserva(state),
                  formatar: euros,
                ),
              ],
            ),

            _Seccao(
              titulo: 'Custos',
              linhas: [
                _Linha(
                  'Colaboradores ativos / vagas',
                  '${state.activeCollaborators} / ${state.activeCollaboratorLimit}',
                ),
                // `if` e não `_Linha.opcional`: aqui `null` significa "não se
                // aplica a este regime", e a Decisão 1 manda esconder o que não
                // se aplica. "Por apurar" leria-se como "falta preencher", e
                // não há nada que o gestor possa preencher para isto aparecer.
                if (pessoal.total != null) ...[
                  _Linha('Bruto pago', euros(pessoal.bruto!)),
                  _Linha(
                    'TSU patronal (contratados)',
                    euros(pessoal.tsuPatronal!),
                    sub: '23,75% sobre o bruto de quem tem contrato. Em '
                        'recibos verdes não se aplica. Estimativa.',
                  ),
                  _Linha(
                    'Custo real com pessoal',
                    euros(pessoal.total!),
                    sub: 'Bruto mais a carga social da entidade patronal — o '
                        'que sai mesmo da empresa.',
                  ),
                ],
                _Linha.opcional(
                  'Custo médio por colaborador',
                  custos.custoMedioPorColaborador,
                  formatar: euros,
                ),
                if (state.hasFleet)
                  _Linha(
                    'Custo estimado mensal de frota',
                    euros(custos.frotaCents),
                    sub: 'Seguros ${euros(rubricas.segurosCents)} · '
                        'Prestações ${euros(rubricas.prestacoesCents)} · '
                        'Combustível ${euros(rubricas.combustivelCents)}',
                  ),
                _Linha(
                  'Manutenção paga este mês',
                  euros(custos.manutencaoPagaCents),
                  sub: custos.manutencaoMedia6MesesCents == null
                      ? 'Sem histórico para comparar'
                      : 'Média dos 6 meses anteriores: '
                            '${euros(custos.manutencaoMedia6MesesCents!)}',
                ),
                _Linha(
                  'Outros custos operacionais pagos',
                  euros(custos.outrosCustosCents),
                ),
                _Linha('Total de custos do mês', euros(custos.totalCents)),
                _Linha.opcional(
                  'Custos sobre a receita',
                  custos.percentDaReceita,
                  formatar: (v) => '${v.toStringAsFixed(0)}%',
                ),
                _Linha.opcional(
                  'Custos fixos mensais declarados',
                  custos.custosFixosDeclaradosCents,
                  formatar: euros,
                ),
              ],
            ),

            _Seccao(
              titulo: 'Semana',
              linhas: [
                _Linha(
                  'Recomendação da semana',
                  recomendacao == null ? 'Por apurar' : recomendacao.title,
                  sub: recomendacao?.lever.label,
                ),
                _Linha('Tarefas pendentes', '${tarefas.length}'),
                _Linha(
                  'Cobranças com mais de $diasParaCobrancaUrgente dias',
                  '${atrasadas.length}',
                  sub: atrasadas.isEmpty
                      ? null
                      : '${euros(atrasadas.fold(0, (s, c) => s + c.emDividaCents))} '
                            'em atraso',
                ),
                _Linha(
                  'Próximas reservas',
                  '${proximasReservas(state, now, 3).length}',
                  sub: proximasReservas(state, now, 3)
                      .map((b) => nomeDoCliente(state, b))
                      .join(' · '),
                ),
              ],
            ),

            _Seccao(
              titulo: 'Comparação com mês homólogo',
              linhas: homologa?.revenueReceivedCents == null
                  ? const []
                  : [
                      _Linha(
                        'Recebido no mesmo mês do ano passado',
                        euros(homologa!.revenueReceivedCents!),
                        sub: 'Este mês: '
                            '${euros(mes.recebidoCents)}',
                      ),
                      if (homologa.paidExpensesCents != null)
                        _Linha(
                          'Despesas pagas no ano passado',
                          euros(homologa.paidExpensesCents!),
                        ),
                      if (homologa.maintenanceCents != null)
                        _Linha(
                          'Manutenção no ano passado',
                          euros(homologa.maintenanceCents!),
                        ),
                      if (homologa.leadsReceived != null)
                        _Linha(
                          'Leads no ano passado',
                          '${homologa.leadsReceived}',
                        ),
                      if (homologa.convertedLeads != null)
                        _Linha(
                          'Leads convertidas no ano passado',
                          '${homologa.convertedLeads}',
                        ),
                    ],
              vazio: 'Histórico do ano passado por preencher.',
              acaoDoVazio: _AccaoHistorico(),
            ),

            _Seccao(
              titulo: 'Frase da semana',
              linhas: [
                _Linha(nota.author, '', sub: '“${nota.text}”'),
                _Linha(nota.source, '', sub: nota.context),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Uma métrica: título à esquerda, valor à direita, sub-linha opcional.
class _Linha {
  const _Linha(this.titulo, this.valor, {this.sub, this.porApurar = false});

  /// Métrica que pode não existir: `null` mostra "Por apurar" em cinza, nunca um
  /// zero inventado.
  static _Linha opcional<T>(
    String titulo,
    T? valor, {
    required String Function(T) formatar,
    String? sub,
  }) => valor == null
      ? _Linha(titulo, 'Por apurar', sub: sub, porApurar: true)
      : _Linha(titulo, formatar(valor), sub: sub);

  final String titulo, valor;
  final String? sub;
  final bool porApurar;
}

class _Seccao extends StatelessWidget {
  const _Seccao({
    required this.titulo,
    required this.linhas,
    this.vazio,
    this.acaoDoVazio,
  });

  final String titulo;
  final List<_Linha> linhas;

  /// Mostrado quando a secção não tem linhas — em vez de um título solto.
  final String? vazio;
  final Widget? acaoDoVazio;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        if (linhas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vazio ?? 'Sem dados.',
                    style: const TextStyle(color: Color(0xFF9AA5AC)),
                  ),
                ),
                if (acaoDoVazio != null) acaoDoVazio!,
              ],
            ),
          )
        else
          for (final linha in linhas) _LinhaMetrica(linha: linha),
      ],
    ),
  );
}

class _LinhaMetrica extends StatelessWidget {
  const _LinhaMetrica({required this.linha});
  final _Linha linha;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEFF1F3))),
    ),
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(linha.titulo, style: const TextStyle(fontSize: 14)),
              if (linha.sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    linha.sub!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          linha.valor,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: linha.porApurar ? const Color(0xFF9AA5AC) : null,
          ),
        ),
      ],
    ),
  );
}

class _AccaoHistorico extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HistoricalDataPage()),
    ),
    child: const Text('Preencher'),
  );
}
