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
    this.diaDoMes,
  });

  final String id;
  final ExpenseCategory categoria;
  final int valorCents;

  /// Dia do mês em que a rubrica sai da conta — 1 a 31, ou `null` enquanto não
  /// for declarado.
  ///
  /// Um custo fixo sem data é um número que paira: sabe-se que vai sair, não se
  /// sabe se já saiu. Com o dia, uma renda vencida a 2 conta como saída no dia
  /// 4 e o painel deixa de dizer "Saídas 0" a uma empresa que já pagou a renda.
  /// Sem ele, a rubrica distribui-se pelos dias do mês, que é o mais honesto
  /// que se consegue dizer sem saber a data.
  final int? diaDoMes;

  /// Livre, para distinguir duas rubricas da mesma categoria ("Renda do
  /// armazém" e "Renda do escritório").
  final String descricao;

  String get rotulo => descricao.trim().isEmpty
      ? expenseCategoryLabel(categoria)
      : descricao.trim();

  /// `diaDoMes` usa o sentinela [_naoMexerNoDia] para distinguir **não mexer**
  /// de **apagar a data**, tal como o `Vehicle.copyWith`.
  CustoFixo copyWith({
    ExpenseCategory? categoria,
    int? valorCents,
    String? descricao,
    Object? diaDoMes = _naoMexerNoDia,
  }) => CustoFixo(
    id: id,
    categoria: categoria ?? this.categoria,
    valorCents: valorCents ?? this.valorCents,
    descricao: descricao ?? this.descricao,
    diaDoMes: diaDoMes == _naoMexerNoDia ? this.diaDoMes : diaDoMes as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria': categoria.name,
    'valorCents': valorCents,
    'descricao': descricao,
    'diaDoMes': diaDoMes,
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
    diaDoMes: diaDoMesValido((json['diaDoMes'] as num?)?.toInt()),
  );
}

/// Sentinela de "este parâmetro não foi passado", para o [CustoFixo.copyWith].
const Object _naoMexerNoDia = Object();

/// Um dia do mês só serve se couber num mês. Fora de 1..31 vale o mesmo que não
/// ter data: o encargo passa a distribuir-se pelos dias, em vez de vencer num
/// dia que não existe. Vale para o que vem do servidor tanto como para o que
/// vem de um campo de texto.
int? diaDoMesValido(int? dia) =>
    dia == null || dia < 1 || dia > 31 ? null : dia;

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
