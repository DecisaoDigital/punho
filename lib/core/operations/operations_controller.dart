import '../sync/supabase_operational_sync.dart';
import '../sync/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/operation_repository.dart';
import '../../domain/models/operations.dart';
import '../../domain/models/finance.dart';
import '../../domain/models/workforce.dart';

final operationRepositoryProvider = Provider<OperationRepository>(
  (ref) => LocalDemoOperationRepository(),
);
final operationsProvider =
    NotifierProvider<OperationsController, OperationsState>(
      OperationsController.new,
    );

class OperationsState {
  const OperationsState({
    this.onboarded = false,
    this.companyName = '',
    this.legalForm = '',
    this.hasFleet = true,
    this.declaredCollaboratorCount = 0,
    this.totalMachinesDeclared = 0,
    this.insertMachinesNow = false,
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
  final String companyName, legalForm;
  final int declaredCollaboratorCount, totalMachinesDeclared;
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
  OperationsState copyWith({
    bool? onboarded,
    String? companyName,
    String? legalForm,
    bool? hasFleet,
    int? declaredCollaboratorCount,
    int? totalMachinesDeclared,
    bool? insertMachinesNow,
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
    companyName: companyName ?? this.companyName,
    legalForm: legalForm ?? this.legalForm,
    hasFleet: hasFleet ?? this.hasFleet,
    declaredCollaboratorCount:
        declaredCollaboratorCount ?? this.declaredCollaboratorCount,
    totalMachinesDeclared: totalMachinesDeclared ?? this.totalMachinesDeclared,
    insertMachinesNow: insertMachinesNow ?? this.insertMachinesNow,
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
      companyName: onboarding?.companyName ?? '',
      legalForm: onboarding?.legalForm ?? '',
      hasFleet: onboarding?.hasFleet ?? true,
      declaredCollaboratorCount: onboarding?.collaborators ?? 0,
      totalMachinesDeclared: onboarding?.totalMachinesDeclared ?? 0,
      insertMachinesNow: onboarding?.insertMachinesNow ?? false,
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
  );
  void completeOnboarding({
    required String companyName,
    required String legalForm,
    required bool hasFleet,
    required int collaborators,
    required int totalMachinesDeclared,
    required bool insertMachinesNow,
  }) {
    _repo.saveOnboarding(
      OnboardingData(
        companyName: companyName,
        legalForm: legalForm,
        hasFleet: hasFleet,
        collaborators: collaborators,
        totalMachinesDeclared: totalMachinesDeclared,
        insertMachinesNow: insertMachinesNow,
      ),
    );
    state = _fromRepo().copyWith(
      onboarded: true,
      companyName: companyName,
      legalForm: legalForm,
      hasFleet: hasFleet,
      declaredCollaboratorCount: collaborators,
      totalMachinesDeclared: totalMachinesDeclared,
      insertMachinesNow: insertMachinesNow,
    );
  }

  void saveMachine(Machine item) {
    _repo.saveMachine(item);
    state = _fromRepo();
  }

  void archiveMachine(String id) {
    _repo.archiveMachine(id);
    state = _fromRepo();
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

  Customer convertLead(Lead lead) {
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
            return BookingConflict(
              state.machines.firstWhere((m) => m.id == id),
              booking,
            );
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
    final registeredMachineIds = state.machines
        .where((machine) => !machine.archived)
        .map((machine) => machine.id)
        .toSet();
    if (booking.machineIds.any((id) => !registeredMachineIds.contains(id))) {
      throw ArgumentError('Uma reserva só pode usar máquinas identificadas.');
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
    state = _fromRepo();
    return null;
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
          m.status == MachineStatus.available &&
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
int stoppedMachines(OperationsState state) => state.machines
    .where((m) => !m.archived && m.status == MachineStatus.stopped)
    .length;
