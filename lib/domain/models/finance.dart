enum ExpenseCategory {
  rent,
  electricity,
  water,
  cleaning,
  fuel,
  vehicleInsurance,
  vehicleMaintenance,
  machineMaintenance,
  meals,
  advertising,
  salaries,
  supplies,
  other,
}

enum ExpensePaymentStatus { paid, unpaid }

enum PaymentMethod { cash, transfer, mbWay, multibanco, other }

enum DocumentDataSource { manual, qr, ocr, mixed }

sealed class LedgerMovement {
  const LedgerMovement({
    required this.id,
    required this.date,
    required this.amountCents,
    required this.note,
    this.archived = false,
  });
  final String id, note;
  final DateTime date;
  final int amountCents;
  final bool archived;
}

class Expense extends LedgerMovement {
  const Expense({
    required super.id,
    required super.date,
    required super.amountCents,
    required this.category,
    required this.status,
    super.note = '',
    this.description = '',
    this.machineId,
    this.vehicleId,
    this.documentPath,
    this.recordedByCollaboratorId,
    this.dataSource = DocumentDataSource.manual,
    super.archived = false,
  });
  final ExpenseCategory category;
  final ExpensePaymentStatus status;
  final String description;
  final String? machineId, vehicleId;
  final String? documentPath;
  final String? recordedByCollaboratorId;
  final DocumentDataSource dataSource;
}

class Receipt extends LedgerMovement {
  const Receipt({
    required super.id,
    required super.date,
    required super.amountCents,
    required this.customerId,
    required this.method,
    super.note = '',
    this.bookingId,
    this.recordedByCollaboratorId,
    super.archived = false,
  });
  final String customerId;
  final String? bookingId;
  final PaymentMethod method;
  final String? recordedByCollaboratorId;
}

enum FinancePeriod { today, week, month, custom }

bool isInPeriod(DateTime date, DateTime from, DateTime to) =>
    !date.isBefore(DateTime(from.year, from.month, from.day)) &&
    date.isBefore(DateTime(to.year, to.month, to.day + 1));
int receiptTotal(Iterable<Receipt> items, DateTime from, DateTime to) => items
    .where((x) => !x.archived && isInPeriod(x.date, from, to))
    .fold(0, (sum, x) => sum + x.amountCents);
int paidExpenseTotal(Iterable<Expense> items, DateTime from, DateTime to) =>
    items
        .where(
          (x) =>
              !x.archived &&
              x.status == ExpensePaymentStatus.paid &&
              isInPeriod(x.date, from, to),
        )
        .fold(0, (sum, x) => sum + x.amountCents);
int unpaidExpenseTotal(Iterable<Expense> items) => items
    .where((x) => !x.archived && x.status == ExpensePaymentStatus.unpaid)
    .fold(0, (sum, x) => sum + x.amountCents);
int bookingReceivedTotal(String bookingId, Iterable<Receipt> items) => items
    .where((x) => !x.archived && x.bookingId == bookingId)
    .fold(0, (sum, x) => sum + x.amountCents);
int bookingPendingCents(
  int expectedCents,
  String bookingId,
  Iterable<Receipt> receipts,
) => (expectedCents - bookingReceivedTotal(bookingId, receipts)).clamp(
  0,
  expectedCents,
);
int simpleOperatingResult(int receipts, int paidExpenses) =>
    receipts - paidExpenses;
