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

/// Rótulo da categoria, em português e num sítio só.
String expenseCategoryLabel(ExpenseCategory categoria) => switch (categoria) {
  ExpenseCategory.rent => 'Renda',
  ExpenseCategory.electricity => 'Electricidade',
  ExpenseCategory.water => 'Água',
  ExpenseCategory.cleaning => 'Limpeza',
  ExpenseCategory.fuel => 'Combustível',
  ExpenseCategory.vehicleInsurance => 'Seguro de viatura',
  ExpenseCategory.vehicleMaintenance => 'Manutenção de viatura',
  ExpenseCategory.machineMaintenance => 'Manutenção de máquina',
  ExpenseCategory.meals => 'Refeições',
  ExpenseCategory.advertising => 'Publicidade',
  ExpenseCategory.salaries => 'Salários',
  ExpenseCategory.supplies => 'Consumíveis',
  ExpenseCategory.other => 'Outros',
};

/// Uma rubrica de custo fixo mensal — renda, electricidade, seguro, o que for.
///
/// Existia só um número redondo (`fixedMonthlyCostsCents`) para tudo. Um total
/// sem rubricas não se revê nem se corrige: o gestor não se lembra do que lá
/// meteu, e quando a renda sobe não sabe que parte do número mudar. Pior ainda
/// para o painel — "custos fixos" sem detalhe não diz onde apertar.
///
/// Reutiliza a [ExpenseCategory] de propósito, para que um custo fixo e uma
/// despesa avulsa da mesma natureza falem a mesma língua.
class CustoFixo {
  const CustoFixo({
    required this.id,
    required this.categoria,
    required this.valorCents,
    this.descricao = '',
  });

  final String id;
  final ExpenseCategory categoria;
  final int valorCents;

  /// Livre, para distinguir duas rubricas da mesma categoria ("Renda do
  /// armazém" e "Renda do escritório").
  final String descricao;

  String get rotulo => descricao.trim().isEmpty
      ? expenseCategoryLabel(categoria)
      : descricao.trim();

  CustoFixo copyWith({
    ExpenseCategory? categoria,
    int? valorCents,
    String? descricao,
  }) => CustoFixo(
    id: id,
    categoria: categoria ?? this.categoria,
    valorCents: valorCents ?? this.valorCents,
    descricao: descricao ?? this.descricao,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria': categoria.name,
    'valorCents': valorCents,
    'descricao': descricao,
  };

  factory CustoFixo.fromJson(Map<String, dynamic> json) => CustoFixo(
    id: json['id'] as String? ?? '',
    // Uma categoria que esta versão não conheça não pode rebentar a leitura de
    // todo o estado operacional.
    categoria:
        ExpenseCategory.values
            .where((c) => c.name == json['categoria'])
            .firstOrNull ??
        ExpenseCategory.other,
    valorCents: (json['valorCents'] as num?)?.toInt() ?? 0,
    descricao: json['descricao'] as String? ?? '',
  );
}

/// Soma das rubricas. `null` quando não há nenhuma — zero diria "não tens
/// custos fixos", que é diferente de "ainda não os declaraste".
int? totalDeCustosFixos(List<CustoFixo> rubricas) => rubricas.isEmpty
    ? null
    : rubricas.fold<int>(0, (soma, c) => soma + c.valorCents);

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
