import '../sync/supabase_operational_sync.dart';
import '../sync/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/operation_repository.dart';
import '../../domain/models/operations.dart';
import '../../domain/models/finance.dart';
import '../../domain/models/workforce.dart';
import '../../domain/models/historical_month.dart';

final operationRepositoryProvider = Provider<OperationRepository>(
  (ref) => LocalDemoOperationRepository(),
);
final operationsProvider =
    NotifierProvider<OperationsController, OperationsState>(
      OperationsController.new,
    );

const minimumBookingDuration = Duration(hours: 12);

/// Valor a escrever num campo opcional.
///
/// Existe para distinguir **não mexer** (não passar o parâmetro) de **apagar**
/// (`Campo(null)`). Um `String?` sozinho não sabe dizer as duas coisas: é o
/// mesmo defeito registado no P2-5 da auditoria v0.0.3, em que limpar a diária
/// de uma máquina não a limpava. Aqui isso importa porque o utilizador tem de
/// poder apagar o NIF ou uma facturação que escreveu errada.
class Campo<T> {
  const Campo(this.valor);
  final T? valor;

  /// Aplica o campo a um valor actual: sem campo nenhum, fica como está.
  static T? aplicar<T>(Campo<T>? campo, T? actual) =>
      campo == null ? actual : campo.valor;
}

class OperationsState {
  const OperationsState({
    this.onboarded = false,
    this.ownerName,
    this.companyName = '',
    this.legalForm = '',
    this.hasFleet = true,
    this.declaredCollaboratorCount = 0,
    this.declaredVehicleCount = 0,
    this.totalMachinesDeclared = 0,
    this.insertMachinesNow = false,
    this.companyTaxId,
    this.companyPhone,
    this.companyEmail,
    this.companyAddress,
    this.companyPostalCode,
    this.companyLocality,
    this.revenueLastYearCents,
    this.revenueThisYearCents,
    this.maintenanceLastYearCents,
    this.fixedMonthlyCostsCents,
    this.historicalMonths = const [],
    this.machines = const [],
    this.customers = const [],
    this.leads = const [],
    this.bookings = const [],
    this.expenses = const [],
    this.receipts = const [],
    this.collaborators = const [],
    this.vehicles = const [],
    this.activeCollaboratorLimit = 3,
  });
  final bool onboarded, hasFleet;
  final String? ownerName;
  final String companyName, legalForm;
  final int declaredCollaboratorCount, totalMachinesDeclared;

  /// Veículos declarados pelo gestor. `hasFleet` é isto `> 0` — guarda-se o
  /// número para o ecrã de Definições poder mostrar de volta o que ele escreveu.
  final int declaredVehicleCount;
  int get registeredMachinesCount =>
      machines.where((machine) => !machine.archived).length;
  int get machinesStillToIdentify =>
      (totalMachinesDeclared - registeredMachinesCount).clamp(
        0,
        totalMachinesDeclared,
      );
  bool get hasUnidentifiedDeclaredMachines => machinesStillToIdentify > 0;
  bool get inventoryIdentifiedAboveEstimate =>
      registeredMachinesCount > totalMachinesDeclared;
  final bool insertMachinesNow;
  final String? companyTaxId, companyPhone, companyEmail;
  final String? companyAddress, companyPostalCode, companyLocality;
  final int? revenueLastYearCents, revenueThisYearCents;
  final int? maintenanceLastYearCents, fixedMonthlyCostsCents;
  final List<HistoricalMonth> historicalMonths;
  final List<Machine> machines;
  final List<Customer> customers;
  final List<Lead> leads;
  final List<Booking> bookings;
  final List<Expense> expenses;
  final List<Receipt> receipts;
  final List<Collaborator> collaborators;
  final List<Vehicle> vehicles;
  final int activeCollaboratorLimit;
  int get activeCollaborators => collaborators
      .where((x) => !x.archived && x.status == CollaboratorStatus.active)
      .length;
  List<String> get initialDataTasks => [
    if (companyTaxId == null) 'Indicar o NIF da empresa',
    if (ownerName == null) 'Indicar o nome do responsável pela empresa',
    if (companyPhone == null) 'Indicar o contacto da empresa',
    if (companyAddress == null ||
        companyPostalCode == null ||
        companyLocality == null)
      'Completar a morada da empresa',
    if (revenueLastYearCents == null) 'Indicar a faturação do ano passado',
    if (revenueThisYearCents == null) 'Indicar a faturação deste ano até hoje',
    if (maintenanceLastYearCents == null)
      'Estimar a manutenção paga no ano passado',
    if (fixedMonthlyCostsCents == null) 'Indicar os custos fixos mensais',
    if (!hasFullRevenueHistoryFor(DateTime.now().year - 1))
      'Preencher o histórico mensal do ano passado',
  ];
  bool hasFullRevenueHistoryFor(int year) =>
      List<int>.generate(12, (index) => index + 1).every(
        (month) => historicalMonth(year, month)?.revenueReceivedCents != null,
      );
  HistoricalMonth? historicalMonth(int year, int month) {
    for (final item in historicalMonths) {
      if (item.year == year && item.month == month) return item;
    }
    return null;
  }

  OperationsState copyWith({
    bool? onboarded,
    String? ownerName,
    String? companyName,
    String? legalForm,
    bool? hasFleet,
    int? declaredCollaboratorCount,
    int? declaredVehicleCount,
    int? totalMachinesDeclared,
    bool? insertMachinesNow,
    String? companyTaxId,
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyPostalCode,
    String? companyLocality,
    int? revenueLastYearCents,
    int? revenueThisYearCents,
    int? maintenanceLastYearCents,
    int? fixedMonthlyCostsCents,
    List<HistoricalMonth>? historicalMonths,
    List<Machine>? machines,
    List<Customer>? customers,
    List<Lead>? leads,
    List<Booking>? bookings,
    List<Expense>? expenses,
    List<Receipt>? receipts,
    List<Collaborator>? collaborators,
    List<Vehicle>? vehicles,
    int? activeCollaboratorLimit,
  }) => OperationsState(
    onboarded: onboarded ?? this.onboarded,
    ownerName: ownerName ?? this.ownerName,
    companyName: companyName ?? this.companyName,
    legalForm: legalForm ?? this.legalForm,
    hasFleet: hasFleet ?? this.hasFleet,
    declaredCollaboratorCount:
        declaredCollaboratorCount ?? this.declaredCollaboratorCount,
    declaredVehicleCount: declaredVehicleCount ?? this.declaredVehicleCount,
    totalMachinesDeclared: totalMachinesDeclared ?? this.totalMachinesDeclared,
    insertMachinesNow: insertMachinesNow ?? this.insertMachinesNow,
    companyTaxId: companyTaxId ?? this.companyTaxId,
    companyPhone: companyPhone ?? this.companyPhone,
    companyEmail: companyEmail ?? this.companyEmail,
    companyAddress: companyAddress ?? this.companyAddress,
    companyPostalCode: companyPostalCode ?? this.companyPostalCode,
    companyLocality: companyLocality ?? this.companyLocality,
    revenueLastYearCents: revenueLastYearCents ?? this.revenueLastYearCents,
    revenueThisYearCents: revenueThisYearCents ?? this.revenueThisYearCents,
    maintenanceLastYearCents:
        maintenanceLastYearCents ?? this.maintenanceLastYearCents,
    fixedMonthlyCostsCents:
        fixedMonthlyCostsCents ?? this.fixedMonthlyCostsCents,
    historicalMonths: historicalMonths ?? this.historicalMonths,
    machines: machines ?? this.machines,
    customers: customers ?? this.customers,
    leads: leads ?? this.leads,
    bookings: bookings ?? this.bookings,
    expenses: expenses ?? this.expenses,
    receipts: receipts ?? this.receipts,
    collaborators: collaborators ?? this.collaborators,
    vehicles: vehicles ?? this.vehicles,
    activeCollaboratorLimit:
        activeCollaboratorLimit ?? this.activeCollaboratorLimit,
  );
}

class OperationsController extends Notifier<OperationsState> {
  OperationRepository get _repo => ref.read(operationRepositoryProvider);
  @override
  OperationsState build() {
    final onboarding = _repo.onboarding;
    return OperationsState(
      onboarded: onboarding != null,
      ownerName: onboarding?.ownerName,
      companyName: onboarding?.companyName ?? '',
      legalForm: onboarding?.legalForm ?? '',
      hasFleet: onboarding?.hasFleet ?? true,
      declaredCollaboratorCount: onboarding?.collaborators ?? 0,
      declaredVehicleCount: onboarding?.declaredVehicleCount ?? 0,
      totalMachinesDeclared: onboarding?.totalMachinesDeclared ?? 0,
      insertMachinesNow: onboarding?.insertMachinesNow ?? false,
      companyTaxId: onboarding?.companyTaxId,
      companyPhone: onboarding?.companyPhone,
      companyEmail: onboarding?.companyEmail,
      companyAddress: onboarding?.companyAddress,
      companyPostalCode: onboarding?.companyPostalCode,
      companyLocality: onboarding?.companyLocality,
      revenueLastYearCents: onboarding?.revenueLastYearCents,
      revenueThisYearCents: onboarding?.revenueThisYearCents,
      maintenanceLastYearCents: onboarding?.maintenanceLastYearCents,
      fixedMonthlyCostsCents: onboarding?.fixedMonthlyCostsCents,
      historicalMonths: _repo.historicalMonths,
      machines: _repo.machines,
      customers: _repo.customers,
      leads: _repo.leads,
      bookings: _repo.bookings,
      expenses: _repo.expenses,
      receipts: _repo.receipts,
      collaborators: _repo.collaborators,
      vehicles: _repo.vehicles,
    );
  }

  OperationsState _fromRepo() => state.copyWith(
    machines: _repo.machines,
    customers: _repo.customers,
    leads: _repo.leads,
    bookings: _repo.bookings,
    expenses: _repo.expenses,
    receipts: _repo.receipts,
    collaborators: _repo.collaborators,
    vehicles: _repo.vehicles,
    historicalMonths: _repo.historicalMonths,
  );
  void completeOnboarding({
    String? ownerName,
    required String companyName,
    required String legalForm,
    required bool hasFleet,
    required int collaborators,
    /// Quantos veículos o gestor declarou. Opcional para não quebrar quem já
    /// chama isto só com `hasFleet`; quando vem, é a partir dele que o ecrã de
    /// Definições mostra o número de volta.
    int declaredVehicleCount = 0,
    required int totalMachinesDeclared,
    required bool insertMachinesNow,
    String? companyTaxId,
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyPostalCode,
    String? companyLocality,
    int? revenueLastYearCents,
    int? revenueThisYearCents,
    int? maintenanceLastYearCents,
    int? fixedMonthlyCostsCents,
  }) {
    _repo.saveOnboarding(
      OnboardingData(
        ownerName: ownerName,
        companyName: companyName,
        legalForm: legalForm,
        hasFleet: hasFleet,
        collaborators: collaborators,
        declaredVehicleCount: declaredVehicleCount,
        totalMachinesDeclared: totalMachinesDeclared,
        insertMachinesNow: insertMachinesNow,
        companyTaxId: companyTaxId,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        companyAddress: companyAddress,
        companyPostalCode: companyPostalCode,
        companyLocality: companyLocality,
        revenueLastYearCents: revenueLastYearCents,
        revenueThisYearCents: revenueThisYearCents,
        maintenanceLastYearCents: maintenanceLastYearCents,
        fixedMonthlyCostsCents: fixedMonthlyCostsCents,
      ),
    );
    state = _fromRepo().copyWith(
      onboarded: true,
      ownerName: ownerName,
      companyName: companyName,
      legalForm: legalForm,
      hasFleet: hasFleet,
      declaredCollaboratorCount: collaborators,
      declaredVehicleCount: declaredVehicleCount,
      totalMachinesDeclared: totalMachinesDeclared,
      insertMachinesNow: insertMachinesNow,
      companyTaxId: companyTaxId,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyAddress: companyAddress,
      companyPostalCode: companyPostalCode,
      companyLocality: companyLocality,
      revenueLastYearCents: revenueLastYearCents,
      revenueThisYearCents: revenueThisYearCents,
      maintenanceLastYearCents: maintenanceLastYearCents,
      fixedMonthlyCostsCents: fixedMonthlyCostsCents,
    );
  }

  /// Edita os dados da empresa depois do onboarding — é o que o ecrã de
  /// Definições grava.
  ///
  /// Separado do [completeOnboarding] de propósito: aquele define o onboarding
  /// do zero e marca a app como configurada, este só altera o que recebe. Um
  /// parâmetro omitido fica como está; um [Campo] com `null` apaga o valor.
  ///
  /// Não faz nada se ainda não houver onboarding: sem ele não há empresa para
  /// editar, e inventar uma aqui saltava o fluxo de arranque.
  void updateCompanySettings({
    Campo<String>? ownerName,
    String? companyName,
    String? legalForm,
    int? collaborators,
    int? vehicles,
    int? totalMachinesDeclared,
    Campo<String>? companyTaxId,
    Campo<String>? companyPhone,
    Campo<String>? companyEmail,
    Campo<String>? companyAddress,
    Campo<String>? companyPostalCode,
    Campo<String>? companyLocality,
    Campo<int>? revenueLastYearCents,
    Campo<int>? revenueThisYearCents,
    Campo<int>? maintenanceLastYearCents,
    Campo<int>? fixedMonthlyCostsCents,
  }) {
    final actual = _repo.onboarding;
    if (actual == null) return;
    // Construído campo a campo em vez de por `copyWith`: o copyWith usa
    // `?? this`, portanto nunca conseguiria apagar um valor.
    final veiculos = vehicles ?? actual.declaredVehicleCount;
    final novo = OnboardingData(
      ownerName: Campo.aplicar(ownerName, actual.ownerName),
      companyName: companyName?.trim().isNotEmpty == true
          ? companyName!.trim()
          : actual.companyName,
      legalForm: legalForm ?? actual.legalForm,
      // A frota deriva do número: pôr veículos a zero faz desaparecer a área de
      // Frota da navegação, e um veículo faz voltar.
      hasFleet: veiculos > 0,
      collaborators: collaborators ?? actual.collaborators,
      declaredVehicleCount: veiculos,
      totalMachinesDeclared: totalMachinesDeclared ?? actual.totalMachinesDeclared,
      insertMachinesNow: actual.insertMachinesNow,
      companyTaxId: Campo.aplicar(companyTaxId, actual.companyTaxId),
      companyPhone: Campo.aplicar(companyPhone, actual.companyPhone),
      companyEmail: Campo.aplicar(companyEmail, actual.companyEmail),
      companyAddress: Campo.aplicar(companyAddress, actual.companyAddress),
      companyPostalCode: Campo.aplicar(
        companyPostalCode,
        actual.companyPostalCode,
      ),
      companyLocality: Campo.aplicar(companyLocality, actual.companyLocality),
      revenueLastYearCents: Campo.aplicar(
        revenueLastYearCents,
        actual.revenueLastYearCents,
      ),
      revenueThisYearCents: Campo.aplicar(
        revenueThisYearCents,
        actual.revenueThisYearCents,
      ),
      maintenanceLastYearCents: Campo.aplicar(
        maintenanceLastYearCents,
        actual.maintenanceLastYearCents,
      ),
      fixedMonthlyCostsCents: Campo.aplicar(
        fixedMonthlyCostsCents,
        actual.fixedMonthlyCostsCents,
      ),
    );
    _repo.saveOnboarding(novo);
    state = _comDadosDaEmpresa(novo);
  }

  /// Reflecte no state um [OnboardingData] inteiro. Não passa por `copyWith`
  /// porque também aqui é preciso poder pôr campos de volta a `null`.
  OperationsState _comDadosDaEmpresa(OnboardingData dados) => OperationsState(
    onboarded: true,
    ownerName: dados.ownerName,
    companyName: dados.companyName,
    legalForm: dados.legalForm,
    hasFleet: dados.hasFleet,
    declaredCollaboratorCount: dados.collaborators,
    declaredVehicleCount: dados.declaredVehicleCount,
    totalMachinesDeclared: dados.totalMachinesDeclared,
    insertMachinesNow: dados.insertMachinesNow,
    companyTaxId: dados.companyTaxId,
    companyPhone: dados.companyPhone,
    companyEmail: dados.companyEmail,
    companyAddress: dados.companyAddress,
    companyPostalCode: dados.companyPostalCode,
    companyLocality: dados.companyLocality,
    revenueLastYearCents: dados.revenueLastYearCents,
    revenueThisYearCents: dados.revenueThisYearCents,
    maintenanceLastYearCents: dados.maintenanceLastYearCents,
    fixedMonthlyCostsCents: dados.fixedMonthlyCostsCents,
    historicalMonths: state.historicalMonths,
    machines: state.machines,
    customers: state.customers,
    leads: state.leads,
    bookings: state.bookings,
    expenses: state.expenses,
    receipts: state.receipts,
    collaborators: state.collaborators,
    vehicles: state.vehicles,
    activeCollaboratorLimit: state.activeCollaboratorLimit,
  );

  /// Apaga tudo o que está neste dispositivo e volta ao onboarding.
  ///
  /// Existe por causa dos dados de demonstração: instalações anteriores a esta
  /// versão já gravaram as duas máquinas e o cliente de demonstração no
  /// armazenamento local, e nascer vazio só resolve para quem instala de novo.
  /// Sem isto, quem já tem a app instalada continuava com números que não são
  /// dele.
  void resetAll() {
    _repo.resetAll();
    state = const OperationsState();
  }

  void updateInitialData({
    String? ownerName,
    String? companyTaxId,
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyPostalCode,
    String? companyLocality,
    int? revenueLastYearCents,
    int? revenueThisYearCents,
    int? maintenanceLastYearCents,
    int? fixedMonthlyCostsCents,
  }) {
    final onboarding = _repo.onboarding;
    if (onboarding == null) return;
    final updated = onboarding.copyWith(
      ownerName: ownerName,
      companyTaxId: companyTaxId,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyAddress: companyAddress,
      companyPostalCode: companyPostalCode,
      companyLocality: companyLocality,
      revenueLastYearCents: revenueLastYearCents,
      revenueThisYearCents: revenueThisYearCents,
      maintenanceLastYearCents: maintenanceLastYearCents,
      fixedMonthlyCostsCents: fixedMonthlyCostsCents,
    );
    _repo.saveOnboarding(updated);
    state = state.copyWith(
      ownerName: updated.ownerName,
      companyTaxId: updated.companyTaxId,
      companyPhone: updated.companyPhone,
      companyEmail: updated.companyEmail,
      companyAddress: updated.companyAddress,
      companyPostalCode: updated.companyPostalCode,
      companyLocality: updated.companyLocality,
      revenueLastYearCents: updated.revenueLastYearCents,
      revenueThisYearCents: updated.revenueThisYearCents,
      maintenanceLastYearCents: updated.maintenanceLastYearCents,
      fixedMonthlyCostsCents: updated.fixedMonthlyCostsCents,
    );
  }

  void saveHistoricalMonth(HistoricalMonth item) {
    _repo.saveHistoricalMonth(item);
    state = _fromRepo();
  }

  void saveMachine(Machine item) {
    _repo.saveMachine(item);
    state = _fromRepo();
  }

  void archiveMachine(String id) {
    _repo.archiveMachine(id);
    state = _fromRepo();
  }

  /// Desfaz o arquivo — é o "Anular" dos 6 segundos depois de eliminar.
  ///
  /// Idempotente e sem memória de quando a máquina foi arquivada: restaurar uma
  /// que estava arquivada há dias é aceitável e não vale a complexidade de
  /// distinguir os dois casos.
  void unarchiveMachine(String id) {
    for (final machine in _repo.machines) {
      if (machine.id != id) continue;
      _repo.saveMachine(machine.copyWith(archived: false));
      break;
    }
    state = _fromRepo();
  }

  bool updateMachineStatus(String id, MachineStatus status) {
    final machine = _repo.machines.where((item) => item.id == id).firstOrNull;
    if (machine == null || machine.archived) return false;
    final now = DateTime.now();
    final hasActiveRental = state.bookings.any(
      (booking) =>
          booking.machineIds.contains(id) &&
          (booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.rented) &&
          !now.isBefore(booking.startsAt) &&
          now.isBefore(booking.endsAt),
    );
    if (status == MachineStatus.available && hasActiveRental) return false;
    _repo.saveMachine(machine.copyWith(status: status));
    // Não se chama _syncMachineCycle aqui de propósito: ele recalcula o estado
    // a partir das reservas e anulava logo a escolha manual — pôr uma máquina
    // com reserva futura em "disponível" não tinha efeito nenhum visível. O
    // ciclo automático só corre quando é uma reserva a mudar.
    state = _fromRepo();
    return true;
  }

  void addLead(Lead item) {
    _repo.saveLead(item);
    state = _fromRepo();
  }

  void addCustomer(Customer item) {
    final duplicate = state.customers.any(
      (customer) =>
          customer.companyId == item.companyId &&
          ((item.phone.isNotEmpty && customer.phone == item.phone) ||
              (item.taxId != null &&
                  item.taxId!.isNotEmpty &&
                  customer.taxId == item.taxId)),
    );
    if (duplicate) {
      throw StateError(
        'Já existe um cliente com o mesmo telemóvel ou NIF na empresa.',
      );
    }
    _repo.saveCustomer(item);
    state = _fromRepo();
  }

  void saveExpense(Expense item) {
    if (item.amountCents <= 0) {
      throw ArgumentError('O valor deve ser superior a zero.');
    }
    _repo.saveExpense(item);
    state = _fromRepo();
  }

  void saveReceipt(Receipt item) {
    if (item.amountCents <= 0) {
      throw ArgumentError('O valor deve ser superior a zero.');
    }
    _repo.saveReceipt(item);
    state = _fromRepo();
  }

  void saveCollaborator(Collaborator item) {
    final existing = state.collaborators
        .where(
          (x) =>
              x.id != item.id &&
              !x.archived &&
              x.status == CollaboratorStatus.active,
        )
        .length;
    if (item.status == CollaboratorStatus.active &&
        existing >= state.activeCollaboratorLimit) {
      throw StateError(
        'A empresa atingiu o limite de colaboradores ativos. Aumente as vagas contratadas no controlo da subscrição.',
      );
    }
    _repo.saveCollaborator(item);
    state = _fromRepo();
  }

  void saveVehicle(Vehicle item) {
    _repo.saveVehicle(item);
    state = _fromRepo();
  }

  /// Converte uma lead em cliente.
  ///
  /// Passa pelas mesmas regras de duplicados que a criação manual: antes disto
  /// a conversão escrevia directamente no repositório e criava clientes
  /// repetidos com o mesmo telemóvel. É idempotente — converter a mesma lead
  /// duas vezes (dois toques seguidos no botão) devolve o cliente já criado em
  /// vez de duplicar.
  Customer convertLead(Lead lead) {
    final jaConvertida = state.leads
        .where((item) => item.id == lead.id)
        .any((item) => item.status == LeadStatus.converted);
    final existente = state.customers
        .where(
          (customer) =>
              lead.phone.isNotEmpty && customer.phone == lead.phone,
        )
        .firstOrNull;
    if (jaConvertida && existente != null) return existente;
    if (existente != null) {
      _repo.saveLead(lead.copyWith(status: LeadStatus.converted));
      state = _fromRepo();
      throw StateError(
        'Já existe um cliente com o telemóvel desta lead: ${existente.name}.',
      );
    }
    final customer = Customer(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: lead.name,
      phone: lead.phone,
      notes: lead.summary,
    );
    _repo.saveCustomer(customer);
    _repo.saveLead(lead.copyWith(status: LeadStatus.converted));
    state = _fromRepo();
    return customer;
  }

  BookingConflict? conflictFor({
    required List<String> machineIds,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    for (final booking in state.bookings.where(
      (b) =>
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.rented,
    )) {
      if (startsAt.isBefore(booking.endsAt) &&
          endsAt.isAfter(booking.startsAt)) {
        for (final id in machineIds) {
          if (booking.machineIds.contains(id)) {
            // `firstWhere` sem `orElse` rebentava quando uma reserva antiga
            // ainda apontava para uma máquina que já não existe no estado.
            final machine = state.machines
                .where((m) => m.id == id)
                .firstOrNull;
            if (machine == null) continue;
            return BookingConflict(machine, booking);
          }
        }
      }
    }
    return null;
  }

  bool machineAvailable(String id, DateTime start, DateTime end) {
    final m = state.machines.firstWhere((x) => x.id == id);
    return !m.archived &&
        m.status != MachineStatus.maintenance &&
        m.status != MachineStatus.rented &&
        conflictFor(machineIds: [id], startsAt: start, endsAt: end) == null;
  }

  BookingConflict? addBooking(Booking booking) {
    if (booking.endsAt.difference(booking.startsAt) < minimumBookingDuration) {
      throw ArgumentError('A reserva mínima é de meio dia.');
    }
    final registeredMachineIds = state.machines
        .where((machine) => !machine.archived)
        .map((machine) => machine.id)
        .toSet();
    if (booking.machineIds.any((id) => !registeredMachineIds.contains(id))) {
      throw ArgumentError('Uma reserva só pode usar máquinas identificadas.');
    }
    // Uma máquina em manutenção ou parada não pode ser reservada: o
    // _syncMachineCycle nunca lhe mexe no estado, pelo que ficava com uma
    // reserva confirmada e ao mesmo tempo marcada como indisponível.
    final indisponiveis = state.machines.where(
      (machine) =>
          booking.machineIds.contains(machine.id) &&
          machine.status == MachineStatus.maintenance,
    );
    if (indisponiveis.isNotEmpty) {
      throw ArgumentError(
        '${indisponiveis.first.name} está '
        '${machineStatusLabel(indisponiveis.first.status).toLowerCase()} '
        'e não pode ser reservada.',
      );
    }
    final conflict = conflictFor(
      machineIds: booking.machineIds,
      startsAt: booking.startsAt,
      endsAt: booking.endsAt,
    );
    if (conflict != null) return conflict;
    final customer = state.customers.firstWhere(
      (customer) => customer.id == booking.customerId,
    );
    final collaboratorName = switch (booking.collaboratorResponsibleId) {
      'collab-a' => 'Colaborador A',
      'collab-b' => 'Colaborador B',
      final id? => () {
        final matches = state.collaborators.where(
          (collaborator) => collaborator.id == id,
        );
        return matches.isEmpty ? 'Colaborador' : matches.first.name;
      }(),
      null => 'Gestor',
    };
    _repo.saveBooking(
      Booking(
        id: booking.id,
        customerId: booking.customerId,
        machineIds: booking.machineIds,
        startsAt: booking.startsAt,
        endsAt: booking.endsAt,
        status: booking.status,
        expectedValueCents: booking.expectedValueCents,
        notes: booking.notes,
        collaboratorResponsibleId: booking.collaboratorResponsibleId,
        companyId: booking.companyId,
        customerNameSnapshot: booking.customerNameSnapshot.isEmpty
            ? customer.name
            : booking.customerNameSnapshot,
        collaboratorNameSnapshot: booking.collaboratorNameSnapshot.isEmpty
            ? collaboratorName
            : booking.collaboratorNameSnapshot,
      ),
    );
    _syncMachineCycle(booking.machineIds);
    state = _fromRepo();
    return null;
  }

  BookingConflict? updateBookingStatus(String bookingId, BookingStatus status) {
    final current = state.bookings.firstWhere(
      (booking) => booking.id == bookingId,
    );
    final activatesMachine =
        status == BookingStatus.confirmed || status == BookingStatus.rented;
    if (activatesMachine) {
      final conflict = conflictFor(
        machineIds: current.machineIds,
        startsAt: current.startsAt,
        endsAt: current.endsAt,
      );
      if (conflict != null && conflict.booking.id != current.id) {
        return conflict;
      }
    }
    _repo.saveBooking(current.copyWith(status: status));
    _syncMachineCycle(current.machineIds);
    state = _fromRepo();
    return null;
  }

  void _syncMachineCycle(Iterable<String> machineIds) {
    final now = DateTime.now();
    for (final id in machineIds) {
      final machineMatches = _repo.machines.where(
        (machine) => machine.id == id && !machine.archived,
      );
      if (machineMatches.isEmpty) continue;
      final machine = machineMatches.first;
      // Uma decisão explícita de manutenção nunca é anulada por uma reserva.
      if (machine.status == MachineStatus.maintenance) continue;
      final related = _repo.bookings.where(
        (booking) =>
            booking.machineIds.contains(id) &&
            (booking.status == BookingStatus.confirmed ||
                booking.status == BookingStatus.rented),
      );
      final hasRentedNow = related.any(
        (booking) =>
            booking.status == BookingStatus.rented &&
            !now.isBefore(booking.startsAt) &&
            now.isBefore(booking.endsAt),
      );
      final hasReserved = related.any(
        (booking) =>
            booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.rented,
      );
      final next = hasRentedNow
          ? MachineStatus.rented
          : hasReserved
          ? MachineStatus.reserved
          : MachineStatus.available;
      if (machine.status != next) {
        _repo.saveMachine(machine.copyWith(status: next));
      }
    }
  }

  Future<SyncStatus> synchronizeRemote() async {
    if (_repo is! PersistentOperationRepository) {
      return SyncStatus.synchronized;
    }
    final result = await SupabaseOperationalSync(
      _repo as PersistentOperationRepository,
    ).synchronize();
    if (result == SyncStatus.synchronized) state = _fromRepo();
    return result;
  }
}

int availableMachines(OperationsState state, DateTime now) => state.machines
    .where(
      (m) =>
          state.machines.isNotEmpty &&
          !m.archived &&
          (m.status == MachineStatus.available ||
              m.status == MachineStatus.reserved) &&
          state.bookings
              .where(
                (b) =>
                    (b.status == BookingStatus.confirmed ||
                        b.status == BookingStatus.rented) &&
                    b.machineIds.contains(m.id) &&
                    now.isAfter(b.startsAt) &&
                    now.isBefore(b.endsAt),
              )
              .isEmpty,
    )
    .length;
/// Máquinas que não estão a trabalhar nem prometidas a ninguém.
///
/// Media o estado `stopped` até à v0.0.5; esse estado deixou de existir para o
/// utilizador, e o que interessa saber é quantas estão paradas **de facto** —
/// nem alugadas, nem reservadas, nem em manutenção.
int stoppedMachines(OperationsState state) => state.machines
    .where(
      (m) =>
          !m.archived &&
          m.status != MachineStatus.rented &&
          m.status != MachineStatus.reserved &&
          m.status != MachineStatus.maintenance,
    )
    .length;
