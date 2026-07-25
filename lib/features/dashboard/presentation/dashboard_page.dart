import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/workforce.dart';
import '../../../core/guidance/guidance_engine.dart';
import '../../finance/presentation/finance_pages.dart';
import '../../updates/presentation/update_banner.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
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
    final incompleteCollaborators = state.collaborators.any(
      (c) =>
          c.status == CollaboratorStatus.active &&
          (monthlyCollaboratorCost(c) == null ||
              hourlyCollaboratorCost(c) == null),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestão',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Olá, ${state.companyName}.'),
            const SizedBox(height: 12),
            const PunhoUpdateBanner(),
            const SizedBox(height: 24),
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
                  Icons.precision_manufacturing_outlined,
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
            const SizedBox(height: 20),
            if (recommendations.isNotEmpty) ...[
              Text(
                'Próximo passo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${recommendations.first.title}\n${recommendations.first.explanation}\nAção sugerida: ${recommendations.first.action}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterExpensePage(),
                    ),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Registar despesa'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterReceiptPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Registar recebimento'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinanceListPage(
                        title: 'Despesas',
                        expenses: true,
                      ),
                    ),
                  ),
                  child: const Text('Despesas'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinanceListPage(
                        title: 'Recebimentos',
                        expenses: false,
                      ),
                    ),
                  ),
                  child: const Text('Recebimentos'),
                ),
                if (SupabaseConfig.enabled)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final status = await ref
                          .read(operationsProvider.notifier)
                          .synchronizeRemote();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_syncMessage(status.name))),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar'),
                  ),
              ],
            ),
            if (pending > 0) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tens ${(pending / 100).toStringAsFixed(2)} € por receber em reservas. Confirma os pagamentos e cria novas leads para reforçar as próximas semanas.',
                  ),
                ),
              ),
            ],
            if (incompleteCollaborators)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Existem colaboradores sem custo ou horário completo.',
                    ),
                  ),
                ),
              ),
            if (state.hasFleet && state.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Frota declarada, mas ainda sem veículos identificados.',
                    ),
                  ),
                ),
              ),
            if (state.hasUnidentifiedDeclaredMachines) ...[
              const SizedBox(height: 24),
              _IdentificationNotice(state: state),
            ],
            if (state.inventoryIdentifiedAboveEstimate)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Inventário identificado superior ao estimado.'),
              ),
          ],
        ),
      ),
    );
  }
}

String _syncMessage(String status) => switch (status) {
  'synchronized' => 'Dados sincronizados com segurança.',
  'pendingChanges' =>
    'Sem ligação. As alterações ficam guardadas neste dispositivo.',
  'requiresReview' =>
    'Existe uma alteração remota por rever antes de sincronizar.',
  _ => 'A sincronização está em curso.',
};

class _IdentificationNotice extends ConsumerWidget {
  const _IdentificationNotice({required this.state});
  final OperationsState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Indicou que tem ${state.totalMachinesDeclared} máquinas, mas ainda não identificou ${state.machinesStillToIdentify}. Registe-as para conhecer a disponibilidade real.',
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.machines),
            child: const Text('Identificar máquinas'),
          ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
