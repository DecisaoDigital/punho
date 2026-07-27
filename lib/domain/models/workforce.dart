enum CollaboratorStatus { active, inactive }

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
  });
  final String id, name, notes;
  final String? phone, role;
  final CollaboratorStatus status;
  final CostFrequency costFrequency;
  final int? costCents;
  final Map<int, WorkDay> schedule;
  final bool archived;

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
    this.insuranceCents,
    this.insuranceFrequency,
    this.notes = '',
    this.archived = false,
  });
  final String id, plate, type, notes;
  final String? alias;
  final VehicleStatus status;
  final int? monthlyPaymentCents, insuranceCents;
  final InsuranceFrequency? insuranceFrequency;
  final bool archived;
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
int monthlyFleetCost(Vehicle v) =>
    (v.monthlyPaymentCents ?? 0) + (monthlyInsuranceCost(v) ?? 0);
