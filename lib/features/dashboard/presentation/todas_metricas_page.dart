import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guidance/guidance_engine.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/historical_month.dart';
import '../../../domain/models/operations.dart';
import '../../../domain/models/workforce.dart';
import '../../operations/presentation/operational_pages.dart';

/// As 17 métricas do painel antigo, tal como estavam.
///
/// O painel passou a carrossel de 5 slides com 4 KPIs cada, mas nenhuma métrica
/// foi apagada: as que não subiram a slide vivem aqui, mais a comparação
/// homóloga e a frase da semana. É o sítio para quem quer a lista toda em vez da
/// leitura orientada — e é onde se vai buscar um número específico sem ter de
/// percorrer os slides.
class TodasMetricasPage extends ConsumerWidget {
  const TodasMetricasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final now = DateTime.now();
    final thisWeek = state.bookings
        .where(
          (b) =>
              b.startsAt.isAfter(now) &&
              b.startsAt.isBefore(now.add(const Duration(days: 7))),
        )
        .length;
    final expected = state.bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .fold(0, (sum, b) => sum + (b.expectedValueCents ?? 0));
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final receivedToday = receiptTotal(state.receipts, todayStart, now);
    final paidToday = paidExpenseTotal(state.expenses, todayStart, now);
    final receivedMonth = receiptTotal(state.receipts, monthStart, now);
    final paidMonth = paidExpenseTotal(state.expenses, monthStart, now);
    final unpaid = unpaidExpenseTotal(state.expenses);
    final monthAdvertising = state.expenses
        .where(
          (expense) =>
              !expense.archived &&
              expense.status == ExpensePaymentStatus.paid &&
              expense.category == ExpenseCategory.advertising &&
              expense.date.year == now.year &&
              expense.date.month == now.month,
        )
        .fold(0, (sum, expense) => sum + expense.amountCents);
    final monthMaintenance = state.expenses
        .where(
          (expense) =>
              !expense.archived &&
              expense.status == ExpensePaymentStatus.paid &&
              expense.category == ExpenseCategory.machineMaintenance &&
              expense.date.year == now.year &&
              expense.date.month == now.month,
        )
        .fold(0, (sum, expense) => sum + expense.amountCents);
    final monthLeads = state.leads
        .where(
          (lead) =>
              lead.createdAt.year == now.year &&
              lead.createdAt.month == now.month,
        )
        .toList();
    final homologous = state.historicalMonth(now.year - 1, now.month);
    final pending = state.bookings.fold(
      0,
      (sum, b) =>
          sum +
          bookingPendingCents(b.expectedValueCents ?? 0, b.id, state.receipts),
    );
    final collaboratorMonthlyCost = state.collaborators
        .where((c) => c.status == CollaboratorStatus.active && !c.archived)
        .fold(0, (sum, c) => sum + (monthlyCollaboratorCost(c) ?? 0));
    final fleetMonthlyCost = state.vehicles.fold(
      0,
      (sum, vehicle) => sum + monthlyFleetCost(vehicle),
    );
    final recommendations = GuidanceEngine().evaluate(
      GuidanceInput(
        bookings: state.bookings,
        machines: state.machines,
        receipts: state.receipts,
        expenses: state.expenses,
        now: now,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Todas as métricas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A lista completa, sem hierarquia. O painel de gestão mostra '
                'estas métricas agrupadas por decisão a tomar.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(
                    'Colaboradores ativos / vagas',
                    '${state.activeCollaborators} / ${state.activeCollaboratorLimit}',
                    Icons.groups_outlined,
                  ),
                  _Metric(
                    'Custo estimado de colaboradores no mês',
                    '${(collaboratorMonthlyCost / 100).toStringAsFixed(2)} €',
                    Icons.badge_outlined,
                  ),
                  if (state.hasFleet)
                    _Metric(
                      'Custo estimado mensal de frota',
                      '${(fleetMonthlyCost / 100).toStringAsFixed(2)} €',
                      Icons.local_shipping_outlined,
                    ),
                  _Metric(
                    'Recebido hoje',
                    '${(receivedToday / 100).toStringAsFixed(2)} €',
                    Icons.payments_outlined,
                  ),
                  _Metric(
                    'Despesas pagas hoje',
                    '${(paidToday / 100).toStringAsFixed(2)} €',
                    Icons.receipt_long_outlined,
                  ),
                  _Metric(
                    'Por receber',
                    '${(pending / 100).toStringAsFixed(2)} €',
                    Icons.request_quote_outlined,
                  ),
                  _Metric(
                    'Por pagar',
                    '${(unpaid / 100).toStringAsFixed(2)} €',
                    Icons.pending_actions_outlined,
                  ),
                  _Metric(
                    'Recebimentos do mês',
                    '${(receivedMonth / 100).toStringAsFixed(2)} €',
                    Icons.account_balance_wallet_outlined,
                  ),
                  _Metric(
                    'Despesas pagas do mês',
                    '${(paidMonth / 100).toStringAsFixed(2)} €',
                    Icons.money_off_outlined,
                  ),
                  _Metric(
                    'Resultado operacional simples',
                    '${(simpleOperatingResult(receivedMonth, paidMonth) / 100).toStringAsFixed(2)} €',
                    Icons.analytics_outlined,
                  ),
                  _Metric(
                    'Reservas desta semana',
                    '$thisWeek',
                    Icons.calendar_month_outlined,
                  ),
                  _Metric(
                    'Máquinas declaradas',
                    '${state.totalMachinesDeclared}',
                    Icons.inventory_2_outlined,
                  ),
                  _Metric(
                    'Máquinas identificadas',
                    '${state.registeredMachinesCount}',
                    Icons.build_outlined,
                  ),
                  _Metric(
                    'Máquinas disponíveis',
                    state.hasUnidentifiedDeclaredMachines
                        ? 'Por apurar'
                        : '${availableMachines(state, now)}',
                    Icons.check_circle_outline,
                  ),
                  _Metric(
                    'Máquinas paradas',
                    '${stoppedMachines(state)}',
                    Icons.pause_circle_outline,
                  ),
                  _Metric(
                    'Leads por contactar',
                    '${state.leads.where((l) => l.status == LeadStatus.newLead).length}',
                    Icons.phone_outlined,
                  ),
                  _Metric(
                    'Valor previsto em reservas confirmadas',
                    '${(expected / 100).toStringAsFixed(2).replaceAll('.', ',')} €',
                    Icons.request_quote_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _HomologousMonthPanel(
                now: now,
                historical: homologous,
                receivedCents: receivedMonth,
                paidExpensesCents: paidMonth,
                advertisingCents: monthAdvertising,
                maintenanceCents: monthMaintenance,
                leads: monthLeads.length,
                convertedLeads: monthLeads
                    .where((lead) => lead.status == LeadStatus.converted)
                    .length,
              ),
              const SizedBox(height: 20),
              _WeeklyDirectionPanel(
                note: weeklyManagementNote(now),
                goal: weeklyGoalFromRecommendations(recommendations),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomologousMonthPanel extends StatelessWidget {
  const _HomologousMonthPanel({
    required this.now,
    required this.historical,
    required this.receivedCents,
    required this.paidExpensesCents,
    required this.advertisingCents,
    required this.maintenanceCents,
    required this.leads,
    required this.convertedLeads,
  });
  final DateTime now;
  final HistoricalMonth? historical;
  final int receivedCents,
      paidExpensesCents,
      advertisingCents,
      maintenanceCents;
  final int leads, convertedLeads;

  @override
  Widget build(BuildContext context) {
    final previousYear = now.year - 1;
    if (historical?.revenueReceivedCents == null) {
      return Card(
        child: ListTile(
          leading: Icon(
            Icons.compare_arrows_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Comparação homóloga por preparar'),
          subtitle: Text(
            'Preenche ${monthName(now.month)} de $previousYear para comparar este mês com o mesmo mês do ano passado.',
          ),
          trailing: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoricalDataPage()),
            ),
            child: const Text('Histórico'),
          ),
        ),
      );
    }
    final last = historical!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${monthName(now.month)} ${now.year} vs. ${monthName(now.month)} $previousYear',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Comparação homóloga com dados registados.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ComparisonMetric(
                  label: 'Recebido',
                  current: receivedCents,
                  previous: last.revenueReceivedCents!,
                  currency: true,
                ),
                if (last.paidExpensesCents != null)
                  _ComparisonMetric(
                    label: 'Despesas pagas',
                    current: paidExpensesCents,
                    previous: last.paidExpensesCents!,
                    currency: true,
                  ),
                if (last.advertisingSpendCents != null)
                  _ComparisonMetric(
                    label: 'Publicidade',
                    current: advertisingCents,
                    previous: last.advertisingSpendCents!,
                    currency: true,
                  ),
                if (last.maintenanceCents != null)
                  _ComparisonMetric(
                    label: 'Manutenção',
                    current: maintenanceCents,
                    previous: last.maintenanceCents!,
                    currency: true,
                  ),
                if (last.leadsReceived != null)
                  _ComparisonMetric(
                    label: 'Leads',
                    current: leads,
                    previous: last.leadsReceived!,
                  ),
                if (last.convertedLeads != null)
                  _ComparisonMetric(
                    label: 'Leads convertidas',
                    current: convertedLeads,
                    previous: last.convertedLeads!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.current,
    required this.previous,
    this.currency = false,
  });
  final String label;
  final int current, previous;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    final difference = current - previous;
    final percentage = previous == 0 ? null : difference / previous * 100;
    final value = currency
        ? '${(current / 100).toStringAsFixed(2)} €'
        : '$current';
    final change = percentage == null
        ? '${difference >= 0 ? '+' : ''}$difference'
        : '${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(0)}%';
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            '$change vs. ano anterior',
            style: TextStyle(
              color: difference >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDirectionPanel extends StatelessWidget {
  const _WeeklyDirectionPanel({required this.note, required this.goal});
  final WeeklyManagementNote note;
  final WeeklyGoal goal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phrase = _WeeklyCard(
        icon: Icons.format_quote_rounded,
        eyebrow: 'FRASE DA SEMANA',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${note.text}”',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${note.isDirectQuote ? '—' : '— Ideia de'} ${note.author}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(note.source, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(note.context),
          ],
        ),
      );
      final goalCard = _WeeklyCard(
        icon: Icons.flag_outlined,
        eyebrow: 'OBJECTIVO DA SEMANA',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(goal.action),
            const SizedBox(height: 10),
            Text(
              'Mede: ${goal.measure}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
      if (constraints.maxWidth < 820) {
        return Column(children: [phrase, const SizedBox(height: 12), goalCard]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: phrase),
          const SizedBox(width: 12),
          Expanded(child: goalCard),
        ],
      );
    },
  );
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({
    required this.icon,
    required this.eyebrow,
    required this.child,
  });
  final IconData icon;
  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 142,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        // O cartão tem altura fixa (142) mas o rótulo é livre: rótulos longos
        // como "Colaboradores ativos / vagas" quebravam para três linhas e
        // rebentavam o cartão. spaceBetween em vez de Spacer, e limite de
        // linhas com reticências, mantêm o desenho dentro da caixa.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}
