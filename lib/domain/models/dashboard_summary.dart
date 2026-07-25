/// Todos os montantes são guardados em cêntimos para evitar imprecisão decimal.
class DashboardSummary {
  const DashboardSummary({
    required this.receivedThisWeekCents,
    required this.pendingCents,
    required this.bookingsThisWeek,
    required this.idleMachines,
    required this.monthlyExpensesCents,
  });

  final int receivedThisWeekCents;
  final int pendingCents;
  final int bookingsThisWeek;
  final int idleMachines;
  final int monthlyExpensesCents;
}
