import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/arranjo_do_painel.dart';
import '../../domain/models/conflito_pendente.dart';
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

  /// Que KPIs o gestor pôs no painel, e por que ordem. Vazio até ele escolher.
  ArranjoDoPainel get painel;
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
  void savePainel(ArranjoDoPainel value);

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
  ArranjoDoPainel _painel = ArranjoDoPainel.vazio;
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
  ArranjoDoPainel get painel => _painel;
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
  void savePainel(ArranjoDoPainel value) => _painel = value;

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
    _painel = ArranjoDoPainel.vazio;
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

  /// Este aparelho arrumou o painel e ainda não o entregou ao servidor.
  ///
  /// Marca à parte do [_hasPendingRemoteChanges] porque **é outro canal**. O
  /// painel tem tabela própria (`punho_painel`) e sobe por
  /// `SincronizacaoDoPainel`; o instantâneo leva a ficha da empresa e mais
  /// nada. Enquanto partilharam canal, arrumar o painel fazia subir a ficha
  /// inteira e avançar a revisão — e a regra "o servidor manda" mandava os
  /// outros aparelhos deitar fora o que tivessem por subir, por causa de uma
  /// caixa marcada.
  bool _painelPorSubir = false;

  /// Quando é que este aparelho arrumou o painel.
  ///
  /// Vai no `p_updated_at` de `punho_painel_gravar`, que só aceita a escrita se
  /// for **igual ou mais recente** do que a que lá está. É o relógio de quem
  /// arrumou, não o do momento em que a rede apareceu: um telemóvel que esteve
  /// a manhã toda sem sinal não pode chegar às duas da tarde e desfazer o que
  /// outra pessoa arrumou ao meio-dia. Era exactamente essa a avaria que o
  /// instantâneo tinha, e não se traz para aqui.
  DateTime? _painelArrumadoEm;

  int? get remoteRevision => _remoteRevision;
  bool get hasPendingRemoteChanges => _hasPendingRemoteChanges;

  /// Há arrumação do painel à espera de chegar a `punho_painel`.
  bool get painelPorSubir => _painelPorSubir;

  /// O carimbo a mandar na próxima subida do painel. Ver [_painelArrumadoEm].
  DateTime? get painelArrumadoEm => _painelArrumadoEm;

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
  /// Chamado uma vez por empresa (ver `SincronizacaoOperacionalPorOperacoes`).
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

  /// Avisado quando uma reserva vinda de outro aparelho colide com uma local.
  ///
  /// Callback e não uma dependência directa do registo de conflitos: o
  /// repositório trata de guardar coisas, e não tem de saber o que se faz com
  /// uma disputa — quem decide isso é a camada de cima.
  void Function(ConflitoPendente)? aoDetectarConflito;

  /// Duas reservas activas na mesma máquina, ao mesmo tempo, não podem estar
  /// as duas certas.
  ///
  /// O caso real: dois colaboradores sem rede, cada um a prometer a mesma
  /// giratória a um cliente diferente. Quando as duas chegam ao servidor, a
  /// regra de "quem chega depois fica por cima" resolvia isto em silêncio — e
  /// alguém ia ao estaleiro buscar uma máquina que já lá não estava.
  ///
  /// Aqui não se escolhe vencedor: regista-se a disputa para uma pessoa
  /// decidir. Uma máquina prometida a dois clientes é um problema de negócio,
  /// não de dados, e nenhuma regra automática o resolve bem.
  void _detectarConflitoDeReserva(Booking recebida) {
    final avisar = aoDetectarConflito;
    if (avisar == null || !_ocupaMaquina(recebida.status)) return;
    for (final local in bookings) {
      // Mesma reserva editada noutro aparelho não é conflito, é a mesma coisa
      // mais recente.
      if (local.id == recebida.id) continue;
      if (!_ocupaMaquina(local.status)) continue;
      final partilhadas = local.machineIds.toSet().intersection(
        recebida.machineIds.toSet(),
      );
      if (partilhadas.isEmpty || !_sobrepoemNoTempo(local, recebida)) continue;
      avisar(
        ConflitoPendente.reservaMaquina(
          reservaId1: local.id,
          reservaId2: recebida.id,
          machineIdsPartilhados: partilhadas.toList()..sort(),
          envolvidos: [
            for (final reserva in [local, recebida])
              if (reserva.collaboratorResponsibleId != null)
                reserva.collaboratorResponsibleId!,
          ],
          criadoEm: DateTime.now(),
        ),
      );
    }
  }

  /// Só estados que prendem mesmo a máquina. Um pedido ou uma proposta ainda
  /// não a tiram de circulação, e marcar isso como conflito seria ensinar o
  /// gestor a ignorar avisos.
  static bool _ocupaMaquina(BookingStatus estado) =>
      estado == BookingStatus.confirmed || estado == BookingStatus.rented;

  /// Fim exclusivo dos dois lados: quem entrega no dia em que o outro recolhe
  /// não está em conflito.
  static bool _sobrepoemNoTempo(Booking a, Booking b) =>
      a.startsAt.isBefore(b.endsAt) && b.startsAt.isBefore(a.endsAt);

  /// Aplica uma alteração feita noutro dispositivo.
  ///
  /// A ordem é a do servidor (`seq`), portanto quem chega depois fica por cima:
  /// última escrita ganha, por entidade. Duas pessoas a mexer em coisas
  /// diferentes não se pisam — que era o que o instantâneo completo não sabia
  /// fazer.
  ///
  /// **Excepção: reservas.** Aí "quem chega depois ganha" não serve, e o
  /// conflito é assinalado antes de a gravação acontecer.
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
          final recebida = _bookingFromJson(payload);
          // Antes de gravar por cima: a reserva que chega pode colidir com uma
          // que já cá está. Depois de `saveBooking` já não dá para saber —
          // ficam as duas no estado, cada uma a dizer que tem a máquina.
          _detectarConflitoDeReserva(recebida);
          super.saveBooking(recebida);
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
    _persist();
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
    _persist();
  }

  @override
  void saveLead(Lead item) {
    super.saveLead(item);
    _registar('lead', item.id, _leadToJson(item));
    _persist();
  }

  @override
  void saveCustomer(Customer item) {
    super.saveCustomer(item);
    _registar('customer', item.id, _customerToJson(item));
    _persist();
  }

  @override
  void archiveCustomer(String id) {
    super.archiveCustomer(id);
    // Mesmo padrão do archiveMachine: viaja como o estado final do cliente.
    final arquivado = _customers.where((c) => c.id == id).firstOrNull;
    if (arquivado != null) {
      _registar('customer', id, _customerToJson(arquivado));
    }
    _persist();
  }

  @override
  void saveBooking(Booking item) {
    super.saveBooking(item);
    _registar('booking', item.id, _bookingToJson(item));
    _persist();
  }

  @override
  void saveExpense(Expense item) {
    super.saveExpense(item);
    _registar('expense', item.id, _expenseToJson(item));
    _persist();
  }

  @override
  void saveReceipt(Receipt item) {
    super.saveReceipt(item);
    _registar('receipt', item.id, _receiptToJson(item));
    _persist();
  }

  @override
  void saveCollaborator(Collaborator item) {
    super.saveCollaborator(item);
    _registar('collaborator', item.id, _collaboratorToJson(item));
    _persist();
  }

  @override
  void saveVehicle(Vehicle item) {
    super.saveVehicle(item);
    _registar('vehicle', item.id, _vehicleToJson(item));
    _persist();
  }

  @override
  void archiveVehicle(String id) {
    super.archiveVehicle(id);
    final arquivado = _vehicles.where((v) => v.id == id).firstOrNull;
    if (arquivado != null) {
      _registar('vehicle', id, _vehicleToJson(arquivado));
    }
    _persist();
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

  /// O painel sobe pela **sua** tabela, `punho_painel`. Não pela fila de
  /// operações, e já não pelo instantâneo.
  ///
  /// Nem a fila nem o instantâneo lhe serviam. A fila serve o que duas pessoas
  /// mexem ao mesmo tempo, e obrigava a inventar uma entidade nova para
  /// resolver uma disputa que não existe. O instantâneo era o vizinho do lado —
  /// e cobrava caro por o alojar: marcar uma caixa punha a ficha inteira por
  /// subir, a revisão avançava, e nos outros telemóveis a regra "o servidor
  /// manda" deitava fora a ficha que tivessem por entregar.
  ///
  /// Aqui não se chama [_markDirty]: o instantâneo não tem nada com isto.
  /// Grava-se em disco — que é onde o painel vive entre arranques — e marca-se
  /// para o canal dele. Ver `SincronizacaoDoPainel`.
  @override
  void savePainel(ArranjoDoPainel value) {
    super.savePainel(value);
    _painelPorSubir = true;
    _painelArrumadoEm = DateTime.now().toUtc();
    _persist();
  }

  /// O painel tal como está em `punho_painel`. **Não marca nada por subir**:
  /// isto é o que chegou de lá, não o que este aparelho tem para dizer.
  ///
  /// Devolve se alterou alguma coisa, para quem chama só reconstruir o ecrã
  /// quando há motivo.
  bool aplicarPainelDoServidor(ArranjoDoPainel valor) {
    if (painel == valor) return false;
    _painel = valor;
    _persist();
    return true;
  }

  /// A arrumação chegou a `punho_painel` — ou perdeu para uma mais recente que
  /// já lá estava, o que dá no mesmo: em nenhum dos casos continua à espera.
  void marcarPainelSincronizado() {
    _painelPorSubir = false;
    _painelArrumadoEm = null;
    _persist();
  }

  /// O que sobe ao servidor pelo canal do instantâneo: **só a ficha da
  /// empresa**. Ver [_payloadDaFicha].
  String exportarFichaDaEmpresa() => jsonEncode(_payloadDaFicha());

  /// Traz do servidor o instantâneo do que é **da empresa** — e só isso.
  ///
  /// **Porque é que isto não traz tudo.** Há **três** canais a sincronizar esta
  /// app, e durante um tempo dois deles julgaram-se donos das mesmas coisas:
  ///
  /// * o das **operações** (`punho_operacoes`), uma linha por alteração, com a
  ///   ordem do servidor a decidir quem ganha. É ele que carrega máquinas,
  ///   clientes, leads, reservas, despesas, recebimentos, colaboradores e
  ///   veículos — as coisas que duas pessoas mexem ao mesmo tempo;
  /// * este, o do **instantâneo** (`punho_estado_operacional`), que sobe e
  ///   desce o estado inteiro com uma revisão. Serve o que só o gestor edita e
  ///   não cabe em operações: o onboarding, os custos fixos, o histórico mensal;
  /// * o do **painel** (`punho_painel`), com guarda de ordem por carimbo. Saiu
  ///   daqui na Fase 3: à boleia deste, marcar uma caixa fazia subir a ficha
  ///   inteira e avançar a revisão para toda a gente.
  ///
  /// Enquanto este importou o payload completo, era ele quem mandava — e mandava
  /// com dados velhos. A 4 de Agosto de 2026, num Redmi: fechar um trabalho
  /// gravava, subia à fila de operações, chegava ao servidor — e segundos depois
  /// o trabalho estava outra vez "em curso", porque este canal tinha voltado a
  /// escrever por cima com um instantâneo da revisão 1, onde ele ainda estava
  /// alugado. Não havia erro nenhum: a app dizia uma coisa, o servidor dizia
  /// outra, e quem trabalhava perdia o trabalho em silêncio.
  ///
  /// Cada coisa tem um dono. Este canal deixou de opinar sobre o que não é dele.
  bool importarFichaDaEmpresa(String raw, {required int revision}) {
    try {
      _applyData(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
        apenasDadosDaEmpresa: true,
        ignorarPainel: true,
      );
      _remoteRevision = revision;
      // **Zero, e não "o que o painel tivesse".**
      //
      // Isto foi, durante uma semana, `_hasPendingRemoteChanges =
      // _painelPorSubir` — e ao lado ia um bloco a repor à mão o painel que a
      // importação tinha acabado de apagar. Existiam os dois porque o painel
      // viajava neste canal e a regra dele ("o servidor manda") era larga de
      // mais para uma preferência que se muda com um toque.
      //
      // O painel saiu para a tabela dele. Este canal leva a ficha da empresa,
      // e sobre a ficha a regra continua a ser a certa: velho perde, sem
      // ressalvas e sem nada por subir do outro lado.
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

  /// Marca que há **ficha da empresa** por subir ao instantâneo.
  ///
  /// Só o onboarding, os custos fixos e o histórico mensal passam por aqui —
  /// é o que este canal possui. As entidades (máquinas, clientes, reservas,
  /// despesas, recebimentos, colaboradores, veículos) gravam com [_persist] e
  /// sobem pela fila de operações, que é o dono delas.
  ///
  /// Marcavam todas, e isso tinha um preço que não se via: gravar uma máquina
  /// punha o instantâneo por subir, o instantâneo subia e a revisão avançava
  /// no servidor. Nos outros telemóveis a revisão deixava de bater certo, e a
  /// regra "o servidor manda" mandava-os deitar fora a ficha que tivessem por
  /// subir — perdida por causa de trabalho que nada tinha a ver com ela.
  void _markDirty() {
    _hasPendingRemoteChanges = true;
    _persist();
  }

  /// **O que este aparelho grava em disco.** Tudo: a ficha, as entidades e o
  /// painel.
  ///
  /// Não confundir com [_payloadDaFicha], que é o que *sobe ao servidor*. Eram
  /// o mesmo método, e é daí que vem a avaria que a Fase 3 fechou: as entidades
  /// tinham de estar aqui — senão a app perdia tudo ao fechar — e por estarem
  /// aqui subiam também, sem ninguém as ter posto a subir de propósito.
  Map<String, Object?> _payloadLocal() => <String, Object?>{
    ..._payloadDaFicha(),
    'machines': _machines.map(_machineToJson).toList(),
    'customers': _customers.map(_customerToJson).toList(),
    'leads': _leads.map(_leadToJson).toList(),
    'bookings': _bookings.map(_bookingToJson).toList(),
    'expenses': _expenses.map(_expenseToJson).toList(),
    'receipts': _receipts.map(_receiptToJson).toList(),
    'collaborators': _collaborators.map(_collaboratorToJson).toList(),
    'vehicles': _vehicles.map(_vehicleToJson).toList(),
    // O painel grava-se aqui, mas sobe por `punho_painel` — não pelo
    // instantâneo. Ver [SincronizacaoDoPainel].
    'painel': painel.toJson(),
  };

  /// **O que sobe ao servidor pelo instantâneo — e só isto.**
  ///
  /// A ficha da empresa: o onboarding (com os custos fixos) e o histórico
  /// mensal. Coisas que só o gestor edita, num sítio só, raramente.
  ///
  /// As entidades saíram daqui na Fase 3. Subiam à boleia, ninguém as lia de
  /// volta — a app ignora-as na descida desde 4 de Agosto — e no servidor um
  /// gatilho projectava-as para as tabelas com `now()`, sem guarda de ordem.
  /// Bastava o gestor gravar os custos fixos com a cópia local atrasada para
  /// uma reserva que o operador acabara de entregar voltar atrás. Sem erro,
  /// sem aviso.
  ///
  /// O painel também saiu: passou a ter tabela própria. Compor um painel são
  /// cinco a dez gestos, e cada um fazia subir o estado inteiro da empresa.
  ///
  /// **Se estiveres a pensar acrescentar uma entidade aqui, não é aqui.** É no
  /// registo de operações, que é quem tem ordem do servidor e resolve empates.
  /// Há um teste que falha se isto voltar a crescer:
  /// `test/core/sync/fronteira_dos_canais_test.dart`.
  Map<String, Object?> _payloadDaFicha() => <String, Object?>{
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
    'historicalMonths': _historicalMonths.map(_historicalMonthToJson).toList(),
  };

  /// Se este aparelho pode guardar dados da empresa entre arranques.
  ///
  /// Falso no telemóvel do operador. Ver [naoGuardarNoAparelho].
  bool _guardaNoAparelho = true;

  /// Falso a partir do momento em que o servidor disse que este aparelho é de
  /// operador. Serve de porteiro a quem só tem que fazer no telemóvel do
  /// gestor — o painel, por exemplo, que a RLS de `punho_painel` só deixa lá
  /// chegar quem é gestor.
  bool get guardaNoAparelho => _guardaNoAparelho;

  /// **Neste aparelho não fica nada da empresa.**
  ///
  /// Regra do Cesar para o operador: a única coisa gravada no telemóvel dele é
  /// **a identificação dele** — quem ele é, a sua sessão —, e essa também está
  /// no servidor.
  ///
  /// A inscrição da empresa é outra coisa e não se confunde com isto: o
  /// `machine_id` de `licencas` identifica o *terminal* perante a licença da
  /// empresa, não identifica o operador. Clientes, máquinas, reservas e
  /// recebimentos aparecem-lhe porque o servidor lhos manda, e desaparecem
  /// quando a app fecha.
  ///
  /// Isto não estava a acontecer: a `CollaboratorShell` usa o mesmo
  /// repositório que a shell do gestor, e o repositório gravava tudo a toda a
  /// gente. Um telemóvel de operador perdido ou revendido levava consigo a
  /// carteira de clientes da empresa, legível sem sessão nenhuma.
  ///
  /// Apaga já o que lá esteja — não basta parar de escrever, porque o que foi
  /// gravado antes desta chamada continuava lá.
  ///
  /// Não limpa a memória: o que está a ser mostrado veio do servidor e é dele
  /// que continua a vir. No arranque seguinte não há nada para ler, e é o
  /// servidor que volta a encher o ecrã.
  void naoGuardarNoAparelho() {
    _guardaNoAparelho = false;
    _preferences.remove(_storageKey);
  }

  void _persist() {
    if (!_guardaNoAparelho) return;
    final data = _payloadLocal();
    data['sync'] = {
      'remoteRevision': _remoteRevision,
      'hasPendingRemoteChanges': _hasPendingRemoteChanges,
      // Gravadas, e não só em memória: arrumar o painel e fechar a app antes de
      // haver rede é o caso normal, não a excepção. E o carimbo tem de ir com
      // ela — é ele que decide a disputa lá no servidor, e reconstruí-lo no
      // arranque seguinte dava-lhe a hora errada, a do arranque.
      'painelPorSubir': _painelPorSubir,
      'painelArrumadoEm': _painelArrumadoEm?.toIso8601String(),
    };
    _preferences.setString(_storageKey, jsonEncode(data));
  }

  @override
  void resetAll() {
    super.resetAll();
    _remoteRevision = null;
    _hasPendingRemoteChanges = false;
    _painelPorSubir = false;
    _painelArrumadoEm = null;
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
      _painelPorSubir = sync?['painelPorSubir'] == true;
      _painelArrumadoEm = DateTime.tryParse(
        sync?['painelArrumadoEm'] as String? ?? '',
      );
      _applyData(data);
    } catch (_) {
      // Uma cache antiga ou inválida não impede a app de arrancar — arranca
      // vazia, que é melhor do que arrancar com metade de um estado antigo.
      _limparMemoria();
    }
  }

  /// [apenasDadosDaEmpresa] deixa de fora as entidades que pertencem ao canal
  /// das operações. Ver [importarFichaDaEmpresa], que é quem o usa — a
  /// leitura do que está gravado no telemóvel ([_restore]) tem de aplicar tudo,
  /// senão a app arrancava sem metade do que lá está.
  ///
  /// [ignorarPainel] existe pela mesma razão, para o outro lado: o painel
  /// grava-se em disco mas já não viaja no instantâneo — tem tabela própria.
  /// Um instantâneo escrito por uma app anterior à Fase 3 ainda traz a chave
  /// `painel`, e lê-la aqui era deixar um payload velho mandar num canal que
  /// já não é dele.
  void _applyData(
    Map<String, dynamic> data, {
    bool apenasDadosDaEmpresa = false,
    bool ignorarPainel = false,
  }) {
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
    // O histórico mensal fica **dentro** do que é da empresa: é declarado pelo
    // gestor uma vez, como os custos fixos, e não anda de mão em mão.
    _replace(
      _historicalMonths,
      data['historicalMonths'],
      _historicalMonthFromJson,
    );
    // O painel vem do disco deste aparelho, e só de lá. Do servidor chega pela
    // sua tabela — ver [SincronizacaoDoPainel] —, não por aqui.
    //
    // **Ausente não é vazio.** Um payload que não tem a chave `painel` não está
    // a dizer "não escolheu nada" — está calado sobre ele. Ler esse silêncio
    // como painel vazio apagava a arrumação do gestor sem erro nenhum à vista.
    // Esvaziá-lo de propósito continua a passar: aí a chave vem, com as listas
    // vazias.
    if (!ignorarPainel) {
      final painelGravado = _mapOrNull(data['painel']);
      if (painelGravado != null) {
        _painel = ArranjoDoPainel.fromJson(painelGravado);
      }
    }
    if (apenasDadosDaEmpresa) return;
    _replace(_machines, data['machines'], _machineFromJson);
    _replace(_customers, data['customers'], _customerFromJson);
    _replace(_leads, data['leads'], _leadFromJson);
    _replace(_bookings, data['bookings'], _bookingFromJson);
    _replace(_expenses, data['expenses'], _expenseFromJson);
    _replace(_receipts, data['receipts'], _receiptFromJson);
    _replace(_collaborators, data['collaborators'], _collaboratorFromJson);
    _replace(_vehicles, data['vehicles'], _vehicleFromJson);
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
    'purchasePriceCents': item.purchasePriceCents,
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
    // Ausente no JSON (fichas antigas, gravadas antes deste campo existir) =
    // `null` — nunca zero inventado.
    purchasePriceCents: _nullableInt(data['purchasePriceCents']),
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
    'convertedCustomerId': item.convertedCustomerId,
    'bookingId': item.bookingId,
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
    // Ausentes em tudo o que foi gravado antes destes campos existirem: ficam
    // nulos, e o `convertLead` volta a preenchê-los na próxima conversão. Uma
    // lead antiga já convertida fica sem cadeia — não se inventa aqui um
    // cliente a partir do telemóvel, que era como se criavam elos falsos.
    convertedCustomerId: _nullableString(data['convertedCustomerId']),
    bookingId: _nullableString(data['bookingId']),
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
    'paymentDayOfMonth': item.paymentDayOfMonth,
    'insuranceCents': item.insuranceCents,
    'insuranceFrequency': item.insuranceFrequency?.name,
    'maintenanceCents': item.maintenanceCents,
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
    paymentDayOfMonth: diaDoMesValido(_nullableInt(data['paymentDayOfMonth'])),
    insuranceCents: _nullableInt(data['insuranceCents']),
    insuranceFrequency: _nullableString(data['insuranceFrequency']) == null
        ? null
        : InsuranceFrequency.values.byName(_string(data, 'insuranceFrequency')),
    maintenanceCents: _nullableInt(data['maintenanceCents']),
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
