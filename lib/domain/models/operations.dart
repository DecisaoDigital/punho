enum MachineStatus { available, reserved, rented, maintenance, stopped }

enum LeadStatus { newLead, contacted, proposal, lost, converted }

enum LeadSource { call, referral, facebook, google, other }

enum BookingStatus {
  request,
  proposalSent,
  confirmed,
  rented,
  completed,
  cancelled,
}

class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.reference,
    required this.category,
    required this.status,
    this.dailyRateCents,
    this.acquiredOn,
    this.notes = '',
    this.photoPaths = const [],
    this.archived = false,
  });
  final String id, name, reference, category, notes;
  final List<String> photoPaths;
  final MachineStatus status;
  final int? dailyRateCents;
  final DateTime? acquiredOn;
  final bool archived;
  Machine copyWith({
    String? name,
    String? reference,
    String? category,
    MachineStatus? status,
    int? dailyRateCents,
    String? notes,
    List<String>? photoPaths,
    bool? archived,
  }) => Machine(
    id: id,
    name: name ?? this.name,
    reference: reference ?? this.reference,
    category: category ?? this.category,
    status: status ?? this.status,
    dailyRateCents: dailyRateCents ?? this.dailyRateCents,
    acquiredOn: acquiredOn,
    notes: notes ?? this.notes,
    photoPaths: photoPaths ?? this.photoPaths,
    archived: archived ?? this.archived,
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.taxId,
    this.email,
    this.notes = '',
    this.companyId = 'local-company',
  });
  final String id, name, phone, notes;
  final String companyId;
  final String? taxId, email;
}

class Lead {
  const Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.createdAt,
    this.source,
    this.summary = '',
    this.collaboratorResponsibleId,
  });
  final String id, name, phone, summary;
  final LeadStatus status;
  final LeadSource? source;
  final DateTime createdAt;
  final String? collaboratorResponsibleId;
  Lead copyWith({LeadStatus? status, String? collaboratorResponsibleId}) =>
      Lead(
        id: id,
        name: name,
        phone: phone,
        status: status ?? this.status,
        createdAt: createdAt,
        source: source,
        summary: summary,
        collaboratorResponsibleId:
            collaboratorResponsibleId ?? this.collaboratorResponsibleId,
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.machineIds,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.expectedValueCents,
    this.collaboratorResponsibleId,
    this.companyId = 'local-company',
    this.customerNameSnapshot = '',
    this.collaboratorNameSnapshot = '',
    this.notes = '',
  });
  final String id, customerId, notes;
  final List<String> machineIds;
  final DateTime startsAt, endsAt;
  final BookingStatus status;
  final int? expectedValueCents;
  final String? collaboratorResponsibleId;
  final String companyId, customerNameSnapshot, collaboratorNameSnapshot;

  Booking copyWith({
    BookingStatus? status,
    int? expectedValueCents,
    String? notes,
    String? collaboratorResponsibleId,
  }) => Booking(
    id: id,
    customerId: customerId,
    machineIds: machineIds,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status ?? this.status,
    expectedValueCents: expectedValueCents ?? this.expectedValueCents,
    notes: notes ?? this.notes,
    collaboratorResponsibleId:
        collaboratorResponsibleId ?? this.collaboratorResponsibleId,
    companyId: companyId,
    customerNameSnapshot: customerNameSnapshot,
    collaboratorNameSnapshot: collaboratorNameSnapshot,
  );
}

class BookingConflict {
  const BookingConflict(this.machine, this.booking);
  final Machine machine;
  final Booking booking;
}
