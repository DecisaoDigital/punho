enum CollaboratorStatus { active, inactive }

/// Como a pessoa está ligada à empresa. Muda o que custa e o que se pede.
///
/// Em **recibos verdes** o que a empresa paga é o custo total: não há TSU da
/// entidade patronal a somar, e os dados fiscais do prestador (NISS, estado
/// civil, dependentes) não afectam o custo da empresa — logo não se pedem.
///
/// Em **contrato** ao bruto acresce a TSU patronal, que é o custo que mais se
/// esquece, e aí faz sentido pedir os dados que permitem estimar o líquido do
/// trabalhador.
enum EmploymentType { recibosVerdes, contrato }

String rotuloDeVinculo(EmploymentType tipo) => switch (tipo) {
  EmploymentType.recibosVerdes => 'Recibos verdes',
  EmploymentType.contrato => 'Contrato de trabalho',
};

/// Situação familiar, para a tabela de retenção de IRS.
///
/// Só é relevante em [EmploymentType.contrato]: em recibos verdes o prestador
/// é responsável pelos próprios descontos e a empresa não tem de saber com
/// quem ele é casado.
enum MaritalStatus { unmarried, married1Holder, married2Holders, other }

String rotuloDeEstadoCivil(MaritalStatus estado) => switch (estado) {
  MaritalStatus.unmarried => 'Solteiro',
  MaritalStatus.married1Holder => 'Casado — 1 titular',
  MaritalStatus.married2Holders => 'Casado — 2 titulares',
  MaritalStatus.other => 'Outro',
};

enum CostFrequency { monthly, weekly }

enum VehicleStatus { active, maintenance, inactive }

enum InsuranceFrequency { monthly, semiannual, annual }

class WorkDay {
  const WorkDay({this.works = false, this.start, this.end});
  final bool works;
  final TimeOfDay? start, end;
}

class TimeOfDay {
  const TimeOfDay(this.hour, this.minute);
  final int hour, minute;
  int get minutes => hour * 60 + minute;
}

class Collaborator {
  const Collaborator({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.role,
    this.costFrequency = CostFrequency.monthly,
    this.costCents,
    this.schedule = const {},
    this.notes = '',
    this.archived = false,
    // Contrato por omissão: é o vínculo mais comum, e é o que preserva a
    // intenção dos registos criados antes de este campo existir — foram todos
    // pensados como pessoal da casa.
    this.employmentType = EmploymentType.contrato,
    this.socialSecurityNumber,
    this.taxId,
    this.maritalStatus = MaritalStatus.unmarried,
    this.dependents = 0,
  });
  final String id, name, notes;
  final String? phone, role;
  final CollaboratorStatus status;
  final CostFrequency costFrequency;
  final int? costCents;
  final Map<int, WorkDay> schedule;
  final bool archived;

  final EmploymentType employmentType;

  /// NISS. Texto e não número: são 11 dígitos mas escrevem-se com espaços, e
  /// guardar como int perdia zeros à esquerda. Só se pede em contrato.
  final String? socialSecurityNumber;

  /// NIF do prestador. Só se pede em recibos verdes, para a empresa poder
  /// lançar a despesa contra alguém.
  final String? taxId;

  final MaritalStatus maritalStatus;

  /// Dependentes fiscais. Só conta para a estimativa de IRS do trabalhador.
  final int dependents;

  /// Editar um colaborador tem de manter o `id` e tudo o que o diálogo não
  /// mostra. Sem isto, gravar uma edição construía um Collaborator novo e
  /// perdia silenciosamente as notas e o histórico ligado ao id antigo.
  ///
  /// Os campos opcionais usam um sentinela em vez de `null`, para distinguir
  /// **não mexer** de **apagar**: com `phone ?? this.phone` era impossível
  /// limpar um telemóvel escrito errado, que é o defeito registado no P2-5 da
  /// auditoria v0.0.3. É a mesma ideia do `Campo<T>` do controller, escrita à
  /// mão aqui para o domínio não passar a depender dele.
  Collaborator copyWith({
    String? name,
    Object? phone = _naoMexer,
    Object? role = _naoMexer,
    CollaboratorStatus? status,
    CostFrequency? costFrequency,
    Object? costCents = _naoMexer,
    Map<int, WorkDay>? schedule,
    String? notes,
    bool? archived,
    EmploymentType? employmentType,
    Object? socialSecurityNumber = _naoMexer,
    Object? taxId = _naoMexer,
    MaritalStatus? maritalStatus,
    int? dependents,
  }) => Collaborator(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    phone: phone == _naoMexer ? this.phone : phone as String?,
    role: role == _naoMexer ? this.role : role as String?,
    costFrequency: costFrequency ?? this.costFrequency,
    costCents: costCents == _naoMexer ? this.costCents : costCents as int?,
    schedule: schedule ?? this.schedule,
    notes: notes ?? this.notes,
    archived: archived ?? this.archived,
    employmentType: employmentType ?? this.employmentType,
    // Sentinela também aqui: trocar de contrato para recibos verdes tem de
    // poder limpar o NISS, e vice-versa para o NIF.
    socialSecurityNumber: socialSecurityNumber == _naoMexer
        ? this.socialSecurityNumber
        : socialSecurityNumber as String?,
    taxId: taxId == _naoMexer ? this.taxId : taxId as String?,
    maritalStatus: maritalStatus ?? this.maritalStatus,
    dependents: dependents ?? this.dependents,
  );
}

/// Sentinela de "este parâmetro não foi passado".
const Object _naoMexer = Object();

class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.type,
    required this.status,
    this.alias,
    this.monthlyPaymentCents,
    this.paymentDayOfMonth,
    this.insuranceCents,
    this.insuranceFrequency,
    this.maintenanceCents,
    this.notes = '',
    this.archived = false,
  });
  final String id, plate, type, notes;
  final String? alias;
  final VehicleStatus status;
  final int? monthlyPaymentCents, insuranceCents;

  /// Dia do mês em que a prestação é debitada — 1 a 31, ou `null` se não tiver
  /// sido declarado.
  ///
  /// A data importa tanto como o valor: uma prestação de 350 € que sai a 2 já
  /// saiu no dia 4, e uma que sai a 28 ainda não. Sem isto o painel só sabia
  /// quanto custa a frota por mês, nunca quanto já tinha saído da conta.
  final int? paymentDayOfMonth;
  final InsuranceFrequency? insuranceFrequency;

  /// Manutenção prevista, valor **anual** — mesma unidade em que o Cesar pensa
  /// nela ("quanto vou gastar de manutenção este ano"), convertida para mensal
  /// só no cálculo do custo da frota, tal como o seguro anual.
  final int? maintenanceCents;
  final bool archived;

  /// Os campos opcionais usam o sentinela [_naoMexer] em vez de `null`, para
  /// distinguir **não mexer** de **apagar** — mesma ideia do
  /// `Collaborator.copyWith` acima. Sem isto, editar um veículo para limpar
  /// uma prestação ou um seguro escritos errado não tinha efeito: `valor ??
  /// this.valor` ignora silenciosamente um `null` passado de propósito.
  Vehicle copyWith({
    String? plate,
    String? type,
    VehicleStatus? status,
    Object? alias = _naoMexer,
    Object? monthlyPaymentCents = _naoMexer,
    Object? paymentDayOfMonth = _naoMexer,
    Object? insuranceCents = _naoMexer,
    Object? insuranceFrequency = _naoMexer,
    Object? maintenanceCents = _naoMexer,
    String? notes,
    bool? archived,
  }) => Vehicle(
    id: id,
    plate: plate ?? this.plate,
    type: type ?? this.type,
    status: status ?? this.status,
    alias: alias == _naoMexer ? this.alias : alias as String?,
    monthlyPaymentCents: monthlyPaymentCents == _naoMexer
        ? this.monthlyPaymentCents
        : monthlyPaymentCents as int?,
    paymentDayOfMonth: paymentDayOfMonth == _naoMexer
        ? this.paymentDayOfMonth
        : paymentDayOfMonth as int?,
    insuranceCents: insuranceCents == _naoMexer
        ? this.insuranceCents
        : insuranceCents as int?,
    insuranceFrequency: insuranceFrequency == _naoMexer
        ? this.insuranceFrequency
        : insuranceFrequency as InsuranceFrequency?,
    maintenanceCents: maintenanceCents == _naoMexer
        ? this.maintenanceCents
        : maintenanceCents as int?,
    notes: notes ?? this.notes,
    archived: archived ?? this.archived,
  );
}

int? monthlyCollaboratorCost(Collaborator c) => c.costCents == null
    ? null
    : c.costFrequency == CostFrequency.monthly
    ? c.costCents
    : c.costCents! * 52 ~/ 12;
double? hourlyCollaboratorCost(Collaborator c) {
  final monthly = monthlyCollaboratorCost(c);
  final weeklyMinutes = c.schedule.values
      .where(
        (d) =>
            d.works &&
            d.start != null &&
            d.end != null &&
            d.end!.minutes > d.start!.minutes,
      )
      .fold(0, (s, d) => s + d.end!.minutes - d.start!.minutes);
  return monthly == null || weeklyMinutes == 0
      ? null
      : monthly / ((weeklyMinutes / 60) * 52 / 12);
}

int? monthlyInsuranceCost(Vehicle v) =>
    v.insuranceCents == null || v.insuranceFrequency == null
    ? null
    : switch (v.insuranceFrequency!) {
        InsuranceFrequency.monthly => v.insuranceCents!,
        InsuranceFrequency.semiannual => v.insuranceCents! ~/ 6,
        InsuranceFrequency.annual => v.insuranceCents! ~/ 12,
      };
int? monthlyMaintenanceCost(Vehicle v) =>
    v.maintenanceCents == null ? null : v.maintenanceCents! ~/ 12;
/// Custo mensal do veículo, ou `null` quando falta alguma parcela.
///
/// Devolve `null` de propósito em vez de somar zeros. Um veículo com a
/// prestação preenchida e o seguro e a manutenção por declarar aparecia como
/// "Custo mensal da frota: 350,00 €" — um número que o gestor lê como facto
/// quando é, quando muito, um terço da conta. As três funções acima já
/// devolvem `null` de propósito; transformá-las em zero aqui era desfazer
/// nesta linha o cuidado que elas têm.
///
/// Ressalva conhecida: uma prestação a `null` tanto pode querer dizer "por
/// declarar" como "veículo pago, sem financiamento". O modelo `Vehicle` não
/// distingue os dois hoje, por isso um veículo próprio conta como por apurar.
/// Distingui-los é uma mudança no modelo, não nesta função.
/// O que se sabe custar, somando só as parcelas declaradas.
///
/// Responde a uma pergunta diferente da [monthlyFleetCost] e por isso existe
/// à parte. Aqui a pergunta é "quanto é que esta frota já pesa na tesouraria",
/// e a resposta certa para uma parcela por declarar é não a contar — não é
/// deitar fora as que estão declaradas. Um veículo com prestação conhecida e
/// seguro por preencher pesa a prestação; dizer que pesa zero seria pior do
/// que subestimar.
///
/// A [monthlyFleetCost] responde a "qual é o custo deste veículo", e aí uma
/// resposta incompleta é uma resposta errada — daí devolver `null`.
int monthlyFleetCostKnown(Vehicle v) =>
    (v.monthlyPaymentCents ?? 0) +
    (monthlyInsuranceCost(v) ?? 0) +
    (monthlyMaintenanceCost(v) ?? 0);

int? monthlyFleetCost(Vehicle v) {
  final prestacao = v.monthlyPaymentCents;
  final seguro = monthlyInsuranceCost(v);
  final manutencao = monthlyMaintenanceCost(v);
  if (prestacao == null || seguro == null || manutencao == null) return null;
  return prestacao + seguro + manutencao;
}
