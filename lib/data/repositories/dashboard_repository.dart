import '../../domain/models/dashboard_summary.dart';

abstract interface class DashboardRepository {
  DashboardSummary getSummary();
}

class LocalDemoDashboardRepository implements DashboardRepository {
  const LocalDemoDashboardRepository();

  @override
  DashboardSummary getSummary() => const DashboardSummary(
    receivedThisWeekCents: 248750,
    pendingCents: 63900,
    bookingsThisWeek: 18,
    idleMachines: 2,
    monthlyExpensesCents: 82740,
  );
}
