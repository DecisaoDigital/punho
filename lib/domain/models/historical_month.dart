/// Resumo de um mês anterior antes de existir importação automática.
class HistoricalMonth {
  const HistoricalMonth({
    required this.year,
    required this.month,
    this.revenueReceivedCents,
    this.paidExpensesCents,
    this.advertisingSpendCents,
    this.leadsReceived,
    this.convertedLeads,
    this.maintenanceCents,
  }) : assert(month >= 1 && month <= 12);

  final int year, month;
  final int? revenueReceivedCents, paidExpensesCents, advertisingSpendCents;
  final int? leadsReceived, convertedLeads, maintenanceCents;

  bool get hasAnyData => [
    revenueReceivedCents,
    paidExpensesCents,
    advertisingSpendCents,
    leadsReceived,
    convertedLeads,
    maintenanceCents,
  ].any((value) => value != null);
}
