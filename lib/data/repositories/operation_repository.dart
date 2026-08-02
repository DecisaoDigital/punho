import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/operations.dart';
import '../../domain/models/finance.dart';
import '../../domain/models/workforce.dart';
import '../../domain/models/historical_month.dart';

abstract interface class OperationRepository {
  List<Machine> get machines;
  List<Customer> get customers;
  List<Lead> get leads;
  List<Booking> get bookings;
  List<Expense> get expenses;
  List<Receipt> get receipts;
  List<Collaborator> get collaborators;
  List<Vehicle> get vehicles;
  List<HistoricalMonth> get historicalMonths;
  OnboardingData? get onboarding;
  void saveMachine(Machine item);
  void archiveMachine(String id);
  void saveLead(Lead item);
  void saveCustomer(Customer item);
  void archiveCustomer(String id);
  void saveBooking(Booking item);
  void saveExpense(Expense item);
  void saveReceipt(Receipt item);
  void saveCollaborator(Collaborator item);
  void saveVehicle(Vehicle item);
  void archiveVehicle(String id);
  void saveHistoricalMonth(HistoricalMonth item);
  void saveOnboarding(OnboardingData value);

  /// Apaga tudo — onboarding incluído — e deixa o repositório vazio. Não repõe
  /// dados de demonstração: a app volta ao onboarding com zero registos.
  void resetAll();
}

class OnboardingData {
  const OnboardingData({
    this.ownerName,
    required this.companyName,
    required this.legalForm,
    required this.hasFleet,
    required this.collaborators,
    this.declaredVehicleCount = 0,
    required this.totalMachinesDeclared,
    required this.insertMachinesNow,
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
    this.custosFixos = const [],
  });

  final String? ownerName;
  final String companyName;
  final String legalForm;
  final bool hasFleet;
  final int collaborators;

  /// Quantos veículos o gestor declarou ter. `hasFleet` deriva daqui (`> 0`),
  /// mas guarda-se o número: sem ele, o ecrã de Definições não conseguia
  /// mostrar de volta o que o utilizador escreveu no onboarding.
  final int declaredVehicleCount;
  final int totalMachinesDeclared;
  final bool insertMachinesNow;
  final String? companyTaxId, companyPhone, companyEmail;
  final String? companyAddress, companyPostalCode, companyLocality;
  final int? revenueLastYearCents;
  final int? revenueThisYearCents;
  final int? maintenanceLastYearCents;
  final int? fixedMonthlyCostsCents;

  /// Rubricas do custo fixo mensal. Quando existem, mandam sobre o total
  /// redondo antigo — que fica só para quem já o tinha preenchido.
  final List<CustoFixo> custosFixos;

  OnboardingData copyWith({
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
    List<CustoFixo>? custosFixos,
  }) => OnboardingData(
    ownerName: ownerName ?? this.ownerName,
    companyName: companyName,
    legalForm: legalForm,
    hasFleet: hasFleet,
    collaborators: collaborators,
    declaredVehicleCount: declaredVehicleCount,
    totalMachinesDeclared: totalMachinesDeclared,
    insertMachinesNow: insertMachinesNow,
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
    custosFixos: custosFixos ?? this.custosFixos,
  );
}

class LocalDemoOperationRepository implements OperationRepository {
  final List<Machine> _machines = [
    const Machine(
      id: 'm1',
      name: 'Mini escavadora 1.8T',
      reference: 'ME-018',
      category: 'Escavação',
      status: MachineStatus.available,
      dailyRateCents: 18500,
    ),
    const Machine(
      id: 'm2',
      name: 'Plataforma elevatória',
      reference: 'PE-002',
      category: 'Elevação',
      status: MachineStatus.available,
    ),
  ];
  final List<Customer> _customers = [
    const Customer(id: 'c1', name: 'Construções Silva', phone: '912 000 000'),
  ];
  final List<Lead> _leads = [];
  final List<Booking> _bookings = [];
  final List<Expense> _expenses = [];
  final List<Receipt> _receipts = [];
  final List<Collaborator> _collaborators = [];
  final List<Vehicle> _vehicles = [];
  final List<HistoricalMonth> _historicalMonths = [];
  OnboardingData? _onboarding;
  @override
  List<Machine> get machines =>
      List.unmodifiable(_machines.map(_semEstadoParada));

  /// Projecção defensiva: uma máquina gravada como `stopped` lê-se como
  /// disponível. O estado "Parada" saiu da app na v0.0.5 e não vale a pena
  /// mostrar dados antigos num estado que já não se explica. A correcção na base
  /// acontece na próxima escrita — `saveMachine` guarda o que a UI mandar.
  static Machine _semEstadoParada(Machine machine) =>
      machine.status == MachineStatus.stopped
      ? machine.copyWith(status: MachineStatus.available)
      : machine;
  @override
  List<Customer> get customers => List.unmodifiable(_customers);
  @override
  List<Lead> get leads => List.unmodifiable(_leads);
  @override
  List<Booking> get bookings => List.unmodifiable(_bookings);
  @override
  List<Expense> get expenses => List.unmodifiable(_expenses);
  @override
  List<Receipt> get receipts => List.unmodifiable(_receipts);
  @override
  List<Collaborator> get collaborators => List.unmodifiable(_collaborators);
  @override
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  @override
  List<HistoricalMonth> get historicalMonths =>
      List.unmodifiable(_historicalMonths);
  @override
  OnboardingData? get onboarding => _onboarding;
  @override
  void saveMachine(Machine item) {
    final i = _machines.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _machines.add(item);
    } else {
      _machines[i] = item;
    }
  }

  @override
  void archiveMachine(String id) {
    final i = _machines.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _machines[i] = _machines[i].copyWith(archived: true);
    }
  }

  @override
  void saveLead(Lead item) {
    final i = _leads.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _leads.add(item);
    } else {
      _leads[i] = item;
    }
  }

  @override
  void saveCustomer(Customer item) {
    final i = _customers.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _customers.add(item);
    } else {
      _customers[i] = item;
    }
  }

  @override
  void archiveCustomer(String id) {
    final i = _customers.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _customers[i] = _customers[i].copyWith(archived: true);
    }
  }

  @override
  void saveBooking(Booking item) {
    final index = _bookings.indexWhere((booking) => booking.id == item.id);
    if (index < 0) {
      _bookings.add(item);
    } else {
      _bookings[index] = item;
    }
  }

  @override
  void saveExpense(Expense item) {
    final i = _expenses.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _expenses.add(item);
    } else {
      _expenses[i] = item;
    }
  }

  @override
  void saveReceipt(Receipt item) {
    final i = _receipts.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _receipts.add(item);
    } else {
      _receipts[i] = item;
    }
  }

  @override
  void saveCollaborator(Collaborator item) {
    final i = _collaborators.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _collaborators.add(item);
    } else {
      _collaborators[i] = item;
    }
  }

  @override
  void saveVehicle(Vehicle item) {
    final i = _vehicles.indexWhere((x) => x.id == item.id);
    if (i < 0) {
      _vehicles.add(item);
    } else {
      _vehicles[i] = item;
    }
  }

  @override
  void archiveVehicle(String id) {
    final i = _vehicles.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _vehicles[i] = _vehicles[i].copyWith(archived: true);
    }
  }

  @override
  void saveHistoricalMonth(HistoricalMonth item) {
    final index = _historicalMonths.indexWhere(
      (month) => month.year == item.year && month.month == item.month,
    );
    if (index < 0) {
      _historicalMonths.add(item);
    } else {
      _historicalMonths[index] = item;
    }
  }

  @override
  void saveOnboarding(OnboardingData value) => _onboarding = value;

  @override
  void resetAll() => _limparMemoria();

  /// Esvazia as colecções em memória, dados de demonstração incluídos. O
  /// repositório persistente chama isto ao arrancar, porque num dispositivo
  /// real as duas máquinas e o cliente de demonstração nunca são "os teus".
  void _limparMemoria() {
    _machines.clear();
    _customers.clear();
    _leads.clear();
    _bookings.clear();
    _expenses.clear();
    _receipts.clear();
    _collaborators.clear();
    _vehicles.clear();
    _historicalMonths.clear();
    _onboarding = null;
  }
}

/// Repositório local para o piloto: conserva os dados neste dispositivo sem
/// depender de ligação. A sincronização Supabase substitui-o numa fase futura.
class PersistentOperationRepository extends LocalDemoOperationRepository {
  PersistentOperationRepository._(this._preferences);

  static const _storageKey = 'punho.operations.v1';
  final SharedPreferences _preferences;
  int? _remoteRevision;
  bool _hasPendingRemoteChanges = false;

  int? get remoteRevision => _remoteRevision;
  bool get hasPendingRemoteChanges => _hasPendingRemoteChanges;

  static Future<PersistentOperationRepository> create() async {
    final repository = PersistentOperationRepository._(
      await SharedPreferences.getInstance(),
    );
    repository._restore();
    return repository;
  }

  /// Chamado a cada alteração local, com a entidade já serializada.
  ///
  /// É por aqui que a sincronização entre dispositivos sabe o que mudou. Fica
  /// como callback e não como dependência directa para o repositório não ter de
  /// conhecer o Supabase — e para os testes poderem observar sem rede.
  void Function(String entidade, String id, Map<String, Object?> payload)?
  aoRegistarOperacao;

  /// `true` enquanto se aplica uma operação vinda de outro dispositivo.
  ///
  /// Sem isto, aplicar o que chegou emitiria uma operação nova, que voltaria a
  /// ser enviada, que voltaria a chegar — um eco sem fim entre dois telemóveis.
  bool _aAplicarRemoto = false;

  void _registar(String entidade, String id, Map<String, Object?> payload) {
    if (_aAplicarRemoto) return;
    aoRegistarOperacao?.call(entidade, id, payload);
  }

  /// Põe **tudo o que já existe no aparelho** na fila de envio, como se
  /// tivesse acabado de ser escrito.
  ///
  /// Existe porque [_registar] só dispara em gravações novas. Quem já usava a
  /// app antes de haver sincronização — ou antes de entrar numa empresa — tinha
  /// máquinas, clientes e reservas no telemóvel que **nunca subiriam**: não
  /// houve gravação depois de a fila existir, portanto não havia nada a
  /// registar. O gestor via os dados no seu aparelho e mais ninguém os via, sem
  /// erro nenhum à vista.
  ///
  /// Chamado uma vez por empresa (ver `SincronizacaoEntreDispositivos`).
  /// Correr duas vezes não estraga nada: a mesma entidade chega com o mesmo
  /// conteúdo e a última a chegar ganha — mas é desperdício, daí a marca.
  int carregarTudoParaFila() {
    var enfileiradas = 0;
    void registar(String entidade, String id, Map<String, Object?> payload) {
      _registar(entidade, id, payload);
      enfileiradas++;
    }

    for (final m in _machines) {
      registar('machine', m.id, _machineToJson(m));
    }
    for (final c in _customers) {
      registar('customer', c.id, _customerToJson(c));
    }
    for (final l in _leads) {
      registar('lead', l.id, _leadToJson(l));
    }
    for (final b in _bookings) {
      registar('booking', b.id, _bookingToJson(b));
    }
    for (final d in _expenses) {
      registar('expense', d.id, _expenseToJson(d));
    }
    for (final r in _receipts) {
      registar('receipt', r.id, _receiptToJson(r));
    }
    for (final c in _collaborators) {
      registar('collaborator', c.id, _collaboratorToJson(c));
    }
    for (final v in _vehicles) {
      registar('vehicle', v.id, _vehicleToJson(v));
    }
    return enfileiradas;
  }

  /// Aplica uma alteração feita noutro dispositivo.
  ///
  /// A ordem é a do servidor (`seq`), portanto quem chega depois fica por cima:
  /// última escrita ganha, por entidade. Duas pessoas a mexer em coisas
  /// diferentes não se pisam — que era o que o instantâneo completo não sabia
  /// fazer.
  void aplicarOperacaoRemota(String entidade, Map<String, dynamic> payload) {
    _aAplicarRemoto = true;
    try {
      switch (entidade) {
        case 'machine':
          super.saveMachine(_machineFromJson(payload));
        case 'customer':
          super.saveCustomer(_customerFromJson(payload));
        case 'lead':
          super.saveLead(_leadFromJson(payload));
        case 'booking':
          super.saveBooking(_bookingFromJson(payload));
        case 'expense':
          super.saveExpense(_expenseFromJson(payload));
        case 'receipt':
          super.saveReceipt(_receiptFromJson(payload));
        case 'collaborator':
          super.saveCollaborator(_collaboratorFromJson(payload));
        case 'vehicle':
          super.saveVehicle(_vehicleFromJson(payload));
        default:
          // Entidade que esta versão ainda não conhece: ignorada de propósito.
          // Uma app antiga não pode rebentar por o servidor ter aprendido algo
          // novo.
          return;
      }
      _persist();
    } finally {
      _aAplicarRemoto = false;
    }
  }

  @override
  void saveMachine(Machine item) {
    super.saveMachine(item);
    _registar('machine', item.id, _machineToJson(item));
    _markDirty();
  }

  @override
  void archiveMachine(String id) {
    super.archiveMachine(id);
    // Arquivar é uma alteração como outra qualquer: viaja como o estado final
    // da máquina, com `archived: true`.
    final arquivada = _machines.where((m) => m.id == id).firstOrNull;
    if (arquivada != null) {
      _registar('machine', id, _machineToJson(arquivada));
    }
    _markDirty();
  }

  @override
  void saveLead(Lead item) {
    super.saveLead(item);
    _registar('lead', item.id, _leadToJson(item));
    _markDirty();
  }

  @override
  void saveCustomer(Customer item) {
    super.saveCustomer(item);
    _registar('customer', item.id, _customerToJson(item));
    _markDirty();
  }

  @override
  void archiveCustomer(String id) {
    super.archiveCustomer(id);
    // Mesmo padrão do archiveMachine: viaja como o estado final do cliente.
    final arquivado = _customers.where((c) => c.id == id).firstOrNull;
    if (arquivado != null) {
      _registar('customer', id, _customerToJson(arquivado));
    }
    _markDirty();
  }

  @override
  void saveBooking(Booking item) {
    super.saveBooking(item);
    _registar('booking', item.id, _bookingToJson(item));
    _markDirty();
  }

  @override
  void saveExpense(Expense item) {
    super.saveExpense(item);
    _registar('expense', item.id, _expenseToJson(item));
    _markDirty();
  }

  @override
  void saveReceipt(Receipt item) {
    super.saveReceipt(item);
    _registar('receipt', item.id, _receiptToJson(item));
    _markDirty();
  }

  @override
  void saveCollaborator(Collaborator item) {
    super.saveCollaborator(item);
    _registar('collaborator', item.id, _collaboratorToJson(item));
    _markDirty();
  }

  @override
  void saveVehicle(Vehicle item) {
    super.saveVehicle(item);
    _registar('vehicle', item.id, _vehicleToJson(item));
    _markDirty();
  }

  @override
  void archiveVehicle(String id) {
    super.archiveVehicle(id);
    final arquivado = _vehicles.where((v) => v.id == id).firstOrNull;
    if (arquivado != null) {
      _registar('vehicle', id, _vehicleToJson(arquivado));
    }
    _markDirty();
  }

  @override
  void saveHistoricalMonth(HistoricalMonth item) {
    super.saveHistoricalMonth(item);
    _markDirty();
  }

  @override
  void saveOnboarding(OnboardingData value) {
    super.saveOnboarding(value);
    _markDirty();
  }

  String exportOperationalPayload() => jsonEncode(_operationalPayload());

  bool importOperationalPayload(String raw, {required int revision}) {
    try {
      _applyData(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      _remoteRevision = revision;
      _hasPendingRemoteChanges = false;
      _persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  void markRemoteSynchronized(int revision) {
    _remoteRevision = revision;
    _hasPendingRemoteChanges = false;
    _persist();
  }

  void _markDirty() {
    _hasPendingRemoteChanges = true;
    _persist();
  }

  Map<String, Object?> _operationalPayload() => <String, Object?>{
    'onboarding': onboarding == null
        ? null
        : {
            'companyName': onboarding!.companyName,
            'ownerName': onboarding!.ownerName,
            'legalForm': onboarding!.legalForm,
            'hasFleet': onboarding!.hasFleet,
            'collaborators': onboarding!.collaborators,
            'declaredVehicleCount': onboarding!.declaredVehicleCount,
            'totalMachinesDeclared': onboarding!.totalMachinesDeclared,
            'insertMachinesNow': onboarding!.insertMachinesNow,
            'companyTaxId': onboarding!.companyTaxId,
            'companyPhone': onboarding!.companyPhone,
            'companyEmail': onboarding!.companyEmail,
            'companyAddress': onboarding!.companyAddress,
            'companyPostalCode': onboarding!.companyPostalCode,
            'companyLocality': onboarding!.companyLocality,
            'revenueLastYearCents': onboarding!.revenueLastYearCents,
            'revenueThisYearCents': onboarding!.revenueThisYearCents,
            'maintenanceLastYearCents': onboarding!.maintenanceLastYearCents,
            'fixedMonthlyCostsCents': onboarding!.fixedMonthlyCostsCents,
            'custosFixos': onboarding!.custosFixos
                .map((c) => c.toJson())
                .toList(),
          },
    'machines': _machines.map(_machineToJson).toList(),
    'customers': _customers.map(_customerToJson).toList(),
    'leads': _leads.map(_leadToJson).toList(),
    'bookings': _bookings.map(_bookingToJson).toList(),
    'expenses': _expenses.map(_expenseToJson).toList(),
    'receipts': _receipts.map(_receiptToJson).toList(),
    'collaborators': _collaborators.map(_collaboratorToJson).toList(),
    'vehicles': _vehicles.map(_vehicleToJson).toList(),
    'historicalMonths': _historicalMonths.map(_historicalMonthToJson).toList(),
  };

  void _persist() {
    final data = _operationalPayload();
    data['sync'] = {
      'remoteRevision': _remoteRevision,
      'hasPendingRemoteChanges': _hasPendingRemoteChanges,
    };
    _preferences.setString(_storageKey, jsonEncode(data));
  }

  @override
  void resetAll() {
    super.resetAll();
    _remoteRevision = null;
    _hasPendingRemoteChanges = false;
    _preferences.remove(_storageKey);
  }

  void _restore() {
    // Num dispositivo real a app nasce vazia. As duas máquinas e o cliente de
    // demonstração vinham por herança do LocalDemoOperationRepository e o painel
    // mostrava-os como se fossem do utilizador: "máquinas identificadas 2",
    // "máquinas paradas 1", um cliente que ninguém criou. Era a origem dos
    // números que o Cesar não reconhecia.
    _limparMemoria();
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final sync = _mapOrNull(data['sync']);
      _remoteRevision = _nullableInt(sync?['remoteRevision']);
      _hasPendingRemoteChanges = sync?['hasPendingRemoteChanges'] == true;
      _applyData(data);
    } catch (_) {
      // Uma cache antiga ou inválida não impede a app de arrancar — arranca
      // vazia, que é melhor do que arrancar com metade de um estado antigo.
      _limparMemoria();
    }
  }

  void _applyData(Map<String, dynamic> data) {
    final onboardingJson = _mapOrNull(data['onboarding']);
    if (onboardingJson != null) {
      _onboarding = OnboardingData(
        ownerName: _nullableString(onboardingJson['ownerName']),
        companyName: _string(onboardingJson, 'companyName'),
        legalForm: _string(onboardingJson, 'legalForm'),
        hasFleet: _bool(onboardingJson, 'hasFleet'),
        collaborators: _int(onboardingJson, 'collaborators'),
        // Ausente nas gravações anteriores a este campo: aí o número perde-se
        // mas o `hasFleet` guardado continua a valer.
        declaredVehicleCount: _int(onboardingJson, 'declaredVehicleCount'),
        totalMachinesDeclared: _int(onboardingJson, 'totalMachinesDeclared'),
        insertMachinesNow: _bool(onboardingJson, 'insertMachinesNow'),
        companyTaxId: _nullableString(onboardingJson['companyTaxId']),
        companyPhone: _nullableString(onboardingJson['companyPhone']),
        companyEmail: _nullableString(onboardingJson['companyEmail']),
        companyAddress: _nullableString(onboardingJson['companyAddress']),
        companyPostalCode: _nullableString(onboardingJson['companyPostalCode']),
        companyLocality: _nullableString(onboardingJson['companyLocality']),
        revenueLastYearCents: _nullableInt(
          onboardingJson['revenueLastYearCents'],
        ),
        revenueThisYearCents: _nullableInt(
          onboardingJson['revenueThisYearCents'],
        ),
        maintenanceLastYearCents: _nullableInt(
          onboardingJson['maintenanceLastYearCents'],
        ),
        fixedMonthlyCostsCents: _nullableInt(
          onboardingJson['fixedMonthlyCostsCents'],
        ),
        custosFixos: [
          for (final linha in (onboardingJson['custosFixos'] as List? ?? []))
            CustoFixo.fromJson(Map<String, dynamic>.from(linha as Map)),
        ],
      );
    }
    _replace(_machines, data['machines'], _machineFromJson);
    _replace(_customers, data['customers'], _customerFromJson);
    _replace(_leads, data['leads'], _leadFromJson);
    _replace(_bookings, data['bookings'], _bookingFromJson);
    _replace(_expenses, data['expenses'], _expenseFromJson);
    _replace(_receipts, data['receipts'], _receiptFromJson);
    _replace(_collaborators, data['collaborators'], _collaboratorFromJson);
    _replace(_vehicles, data['vehicles'], _vehicleFromJson);
    _replace(
      _historicalMonths,
      data['historicalMonths'],
      _historicalMonthFromJson,
    );
  }

  void _replace<T>(
    List<T> target,
    Object? source,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (source is! List) return;
    target
      ..clear()
      ..addAll(
        source.map((item) => parser(Map<String, dynamic>.from(item as Map))),
      );
  }

  static Map<String, Object?> _machineToJson(Machine item) => {
    'id': item.id,
    'name': item.name,
    'reference': item.reference,
    'category': item.category,
    'status': item.status.name,
    'dailyRateCents': item.dailyRateCents,
    'acquiredOn': item.acquiredOn?.toIso8601String(),
    'notes': item.notes,
    'photoPaths': item.photoPaths,
    'archived': item.archived,
  };

  static Machine _machineFromJson(Map<String, dynamic> data) => Machine(
    id: _string(data, 'id'),
    name: _string(data, 'name'),
    reference: _string(data, 'reference'),
    category: _string(data, 'category'),
    status: MachineStatus.values.byName(_string(data, 'status', 'available')),
    dailyRateCents: _nullableInt(data['dailyRateCents']),
    acquiredOn: _nullableDate(data['acquiredOn']),
    notes: _string(data, 'notes'),
    photoPaths: data['photoPaths'] is List
        ? List<String>.from(data['photoPaths'] as List)
        : const [],
    archived: _bool(data, 'archived'),
  );

  static Map<String, Object?> _historicalMonthToJson(HistoricalMonth item) => {
    'year': item.year,
    'month': item.month,
    'revenueReceivedCents': item.revenueReceivedCents,
    'paidExpensesCents': item.paidExpensesCents,
    'advertisingSpendCents': item.advertisingSpendCents,
    'leadsReceived': item.leadsReceived,
    'convertedLeads': item.convertedLeads,
    'maintenanceCents': item.maintenanceCents,
  };

  static HistoricalMonth _historicalMonthFromJson(Map<String, dynamic> data) =>
      HistoricalMonth(
        year: _int(data, 'year'),
        month: _int(data, 'month'),
        revenueReceivedCents: _nullableInt(data['revenueReceivedCents']),
        paidExpensesCents: _nullableInt(data['paidExpensesCents']),
        advertisingSpendCents: _nullableInt(data['advertisingSpendCents']),
        leadsReceived: _nullableInt(data['leadsReceived']),
        convertedLeads: _nullableInt(data['convertedLeads']),
        maintenanceCents: _nullableInt(data['maintenanceCents']),
      );

  static Map<String, Object?> _customerToJson(Customer item) => {
    'id': item.id,
    'name': item.name,
    'phone': item.phone,
    'taxId': item.taxId,
    'email': item.email,
    'address': item.address,
    'postalCode': item.postalCode,
    'locality': item.locality,
    'notes': item.notes,
    'companyId': item.companyId,
    'archived': item.archived,
  };

  static Customer _customerFromJson(Map<String, dynamic> data) => Customer(
    id: _string(data, 'id'),
    name: _string(data, 'name'),
    phone: _string(data, 'phone'),
    taxId: _nullableString(data['taxId']),
    email: _nullableString(data['email']),
    address: _nullableString(data['address']),
    postalCode: _nullableString(data['postalCode']),
    locality: _nullableString(data['locality']),
    notes: _string(data, 'notes'),
    companyId: _string(data, 'companyId', 'local-company'),
    // Ausente nas gravações anteriores a este campo: fica false, como nos
    // outros booleanos (`_bool` devolve false quando a chave não existe).
    archived: _bool(data, 'archived'),
  );

  static Map<String, Object?> _leadToJson(Lead item) => {
    'id': item.id,
    'name': item.name,
    'phone': item.phone,
    'status': item.status.name,
    'source': item.source?.name,
    'createdAt': item.createdAt.toIso8601String(),
    'summary': item.summary,
    'collaboratorResponsibleId': item.collaboratorResponsibleId,
  };

  static Lead _leadFromJson(Map<String, dynamic> data) => Lead(
    id: _string(data, 'id'),
    name: _string(data, 'name'),
    phone: _string(data, 'phone'),
    status: LeadStatus.values.byName(_string(data, 'status', 'newLead')),
    source: _nullableString(data['source']) == null
        ? null
        : LeadSource.values.byName(_string(data, 'source')),
    createdAt: DateTime.parse(_string(data, 'createdAt')),
    summary: _string(data, 'summary'),
    collaboratorResponsibleId: _nullableString(
      data['collaboratorResponsibleId'],
    ),
  );

  static Map<String, Object?> _bookingToJson(Booking item) => {
    'id': item.id,
    'customerId': item.customerId,
    'machineIds': item.machineIds,
    'startsAt': item.startsAt.toIso8601String(),
    'endsAt': item.endsAt.toIso8601String(),
    'status': item.status.name,
    'expectedValueCents': item.expectedValueCents,
    'collaboratorResponsibleId': item.collaboratorResponsibleId,
    'companyId': item.companyId,
    'customerNameSnapshot': item.customerNameSnapshot,
    'collaboratorNameSnapshot': item.collaboratorNameSnapshot,
    'notes': item.notes,
  };

  static Booking _bookingFromJson(Map<String, dynamic> data) => Booking(
    id: _string(data, 'id'),
    customerId: _string(data, 'customerId'),
    machineIds: List<String>.from(data['machineIds'] as List),
    startsAt: DateTime.parse(_string(data, 'startsAt')),
    endsAt: DateTime.parse(_string(data, 'endsAt')),
    status: BookingStatus.values.byName(_string(data, 'status', 'request')),
    expectedValueCents: _nullableInt(data['expectedValueCents']),
    collaboratorResponsibleId: _nullableString(
      data['collaboratorResponsibleId'],
    ),
    companyId: _string(data, 'companyId', 'local-company'),
    customerNameSnapshot: _string(data, 'customerNameSnapshot'),
    collaboratorNameSnapshot: _string(data, 'collaboratorNameSnapshot'),
    notes: _string(data, 'notes'),
  );

  static Map<String, Object?> _expenseToJson(Expense item) => {
    'id': item.id,
    'date': item.date.toIso8601String(),
    'amountCents': item.amountCents,
    'category': item.category.name,
    'status': item.status.name,
    'note': item.note,
    'description': item.description,
    'machineId': item.machineId,
    'vehicleId': item.vehicleId,
    'documentPath': item.documentPath,
    'recordedByCollaboratorId': item.recordedByCollaboratorId,
    'dataSource': item.dataSource.name,
    'archived': item.archived,
  };

  static Expense _expenseFromJson(Map<String, dynamic> data) => Expense(
    id: _string(data, 'id'),
    date: DateTime.parse(_string(data, 'date')),
    amountCents: _int(data, 'amountCents'),
    category: ExpenseCategory.values.byName(_string(data, 'category', 'other')),
    status: ExpensePaymentStatus.values.byName(_string(data, 'status', 'paid')),
    note: _string(data, 'note'),
    description: _string(data, 'description'),
    machineId: _nullableString(data['machineId']),
    vehicleId: _nullableString(data['vehicleId']),
    documentPath: _nullableString(data['documentPath']),
    recordedByCollaboratorId: _nullableString(data['recordedByCollaboratorId']),
    dataSource: DocumentDataSource.values.byName(
      _string(data, 'dataSource', 'manual'),
    ),
    archived: _bool(data, 'archived'),
  );

  static Map<String, Object?> _receiptToJson(Receipt item) => {
    'id': item.id,
    'date': item.date.toIso8601String(),
    'amountCents': item.amountCents,
    'customerId': item.customerId,
    'bookingId': item.bookingId,
    'method': item.method.name,
    'note': item.note,
    'recordedByCollaboratorId': item.recordedByCollaboratorId,
    'archived': item.archived,
  };

  static Receipt _receiptFromJson(Map<String, dynamic> data) => Receipt(
    id: _string(data, 'id'),
    date: DateTime.parse(_string(data, 'date')),
    amountCents: _int(data, 'amountCents'),
    customerId: _string(data, 'customerId'),
    bookingId: _nullableString(data['bookingId']),
    method: PaymentMethod.values.byName(_string(data, 'method', 'transfer')),
    note: _string(data, 'note'),
    recordedByCollaboratorId: _nullableString(data['recordedByCollaboratorId']),
    archived: _bool(data, 'archived'),
  );

  static Map<String, Object?> _collaboratorToJson(Collaborator item) => {
    'id': item.id,
    'name': item.name,
    'status': item.status.name,
    'phone': item.phone,
    'role': item.role,
    'costFrequency': item.costFrequency.name,
    'costCents': item.costCents,
    'schedule': item.schedule.map(
      (key, value) => MapEntry('$key', {
        'works': value.works,
        'start': value.start == null
            ? null
            : {'hour': value.start!.hour, 'minute': value.start!.minute},
        'end': value.end == null
            ? null
            : {'hour': value.end!.hour, 'minute': value.end!.minute},
      }),
    ),
    'notes': item.notes,
    'archived': item.archived,
    'employmentType': item.employmentType.name,
    'socialSecurityNumber': item.socialSecurityNumber,
    'taxId': item.taxId,
    'maritalStatus': item.maritalStatus.name,
    'dependents': item.dependents,
  };

  static Collaborator _collaboratorFromJson(Map<String, dynamic> data) =>
      Collaborator(
        id: _string(data, 'id'),
        name: _string(data, 'name'),
        status: CollaboratorStatus.values.byName(
          _string(data, 'status', 'active'),
        ),
        phone: _nullableString(data['phone']),
        role: _nullableString(data['role']),
        costFrequency: CostFrequency.values.byName(
          _string(data, 'costFrequency', 'monthly'),
        ),
        costCents: _nullableInt(data['costCents']),
        schedule: _scheduleFromJson(data['schedule']),
        notes: _string(data, 'notes'),
        archived: _bool(data, 'archived'),
        // Ausentes nos registos gravados antes destes campos existirem: ficam
        // com o default, que é contrato — a intenção com que foram criados.
        employmentType: EmploymentType.values.byName(
          _string(data, 'employmentType', 'contrato'),
        ),
        socialSecurityNumber: _nullableString(data['socialSecurityNumber']),
        taxId: _nullableString(data['taxId']),
        maritalStatus: MaritalStatus.values.byName(
          _string(data, 'maritalStatus', 'unmarried'),
        ),
        dependents: _nullableInt(data['dependents']) ?? 0,
      );

  static Map<int, WorkDay> _scheduleFromJson(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, rawDay) {
      final day = Map<String, dynamic>.from(rawDay as Map);
      final start = _timeFromJson(day['start']);
      final end = _timeFromJson(day['end']);
      return MapEntry(
        int.parse('$key'),
        WorkDay(works: _bool(day, 'works'), start: start, end: end),
      );
    });
  }

  static TimeOfDay? _timeFromJson(Object? value) {
    final data = _mapOrNull(value);
    if (data == null) return null;
    return TimeOfDay(_int(data, 'hour'), _int(data, 'minute'));
  }

  static Map<String, Object?> _vehicleToJson(Vehicle item) => {
    'id': item.id,
    'plate': item.plate,
    'type': item.type,
    'status': item.status.name,
    'alias': item.alias,
    'monthlyPaymentCents': item.monthlyPaymentCents,
    'insuranceCents': item.insuranceCents,
    'insuranceFrequency': item.insuranceFrequency?.name,
    'notes': item.notes,
    'archived': item.archived,
  };

  static Vehicle _vehicleFromJson(Map<String, dynamic> data) => Vehicle(
    id: _string(data, 'id'),
    plate: _string(data, 'plate'),
    type: _string(data, 'type'),
    status: VehicleStatus.values.byName(_string(data, 'status', 'active')),
    alias: _nullableString(data['alias']),
    monthlyPaymentCents: _nullableInt(data['monthlyPaymentCents']),
    insuranceCents: _nullableInt(data['insuranceCents']),
    insuranceFrequency: _nullableString(data['insuranceFrequency']) == null
        ? null
        : InsuranceFrequency.values.byName(_string(data, 'insuranceFrequency')),
    notes: _string(data, 'notes'),
    archived: _bool(data, 'archived'),
  );

  static Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;
  static String _string(
    Map<String, dynamic> data,
    String key, [
    String fallback = '',
  ]) => data[key] is String ? data[key] as String : fallback;
  static String? _nullableString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
  static int _int(Map<String, dynamic> data, String key, [int fallback = 0]) =>
      data[key] is num ? (data[key] as num).toInt() : fallback;
  static int? _nullableInt(Object? value) =>
      value is num ? value.toInt() : null;
  static bool _bool(Map<String, dynamic> data, String key) => data[key] == true;
  static DateTime? _nullableDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
