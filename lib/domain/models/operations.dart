/// Estado de uma máquina.
///
/// `stopped` está **deprecated** desde a v0.0.5 e deixou de ser observável pelo
/// utilizador: uma máquina que não está alugada, reservada nem em manutenção
/// está disponível, e ponto. "Fora de serviço" já tem `Machine.archived`, que é
/// outra coisa. Fica no enum para não partir serialização antiga (backups,
/// payloads sincronizados, séries de dados) — em qualquer interpretação nova,
/// mapear para `available`.
enum MachineStatus { available, reserved, rented, maintenance, stopped }

/// Estados que o utilizador pode escolher. Sem `stopped`, de propósito.
const estadosEscolhiveisDeMaquina = [
  MachineStatus.available,
  MachineStatus.reserved,
  MachineStatus.rented,
  MachineStatus.maintenance,
];

String machineStatusLabel(MachineStatus status) => switch (status) {
  MachineStatus.available => 'Disponível',
  MachineStatus.reserved => 'Reservada',
  MachineStatus.rented => 'Alugada',
  MachineStatus.maintenance => 'Em manutenção',
  // Mesmo label do `available`: dados antigos com este estado leem-se como
  // disponíveis em vez de mostrarem um estado que já não existe.
  MachineStatus.stopped => 'Disponível',
};

enum LeadStatus { newLead, contacted, proposal, lost, converted }

/// De onde veio a lead. É o que torna o CAC por canal calculável — sem origem
/// não há forma de dividir a publicidade pelos clientes que ela trouxe.
///
/// Serializado **por nome** (`LeadSource.values.byName`), portanto acrescentar
/// valores no fim não parte dados antigos.
enum LeadSource {
  call,
  referral,
  facebook,
  google,
  other,

  /// Chegou por formulário no site.
  landingPage,

  /// Chegou por WhatsApp.
  whatsapp,

  /// Importada da agenda do telemóvel.
  agenda,
}

String leadSourceLabel(LeadSource origem) => switch (origem) {
  LeadSource.call => 'Chamada',
  LeadSource.referral => 'Recomendação',
  LeadSource.facebook => 'Facebook',
  LeadSource.google => 'Google',
  LeadSource.landingPage => 'Site',
  LeadSource.whatsapp => 'WhatsApp',
  LeadSource.agenda => 'Agenda',
  LeadSource.other => 'Outro',
};

String leadStatusLabel(LeadStatus estado) => switch (estado) {
  LeadStatus.newLead => 'Nova',
  LeadStatus.contacted => 'Contactada',
  LeadStatus.proposal => 'Com proposta',
  LeadStatus.lost => 'Perdida',
  LeadStatus.converted => 'Convertida',
};

enum BookingStatus {
  request,
  proposalSent,
  confirmed,
  rented,
  completed,
  cancelled,
}

/// O nome que o utilizador lê para cada estado do trabalho.
///
/// Vivia privado dentro de `operational_pages.dart`, e por isso qualquer ecrã
/// novo tinha de reinventar as mesmas seis palavras — dois sítios a chamar
/// "Confirmada" o mesmo estado é como se começa a ter três. Passa a viver ao
/// lado de [machineStatusLabel] e [leadSourceLabel], onde já estava o resto do
/// vocabulário.
String bookingStatusLabel(BookingStatus status) => switch (status) {
  BookingStatus.request => 'Pedido',
  BookingStatus.proposalSent => 'Proposta enviada',
  BookingStatus.confirmed => 'Confirmada',
  BookingStatus.rented => 'Em aluguer',
  BookingStatus.completed => 'Concluída',
  BookingStatus.cancelled => 'Cancelada',
};

class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.reference,
    required this.category,
    required this.status,
    this.dailyRateCents,
    this.acquiredOn,
    this.purchasePriceCents,
    this.notes = '',
    this.photoPaths = const [],
    this.archived = false,
  });
  final String id, name, reference, category, notes;
  final List<String> photoPaths;
  final MachineStatus status;
  final int? dailyRateCents;
  final DateTime? acquiredOn;

  /// Valor de compra, em cêntimos. Opcional: quem não souber quanto pagou
  /// pela máquina tem de a poder gravar na mesma — a célula "Utilização vs
  /// Rentabilidade" (`sintese_slide.dart`) fica "Por apurar", com motivo, em
  /// vez de bloquear o resto da ficha.
  final int? purchasePriceCents;
  final bool archived;

  Machine copyWith({
    String? name,
    String? reference,
    String? category,
    MachineStatus? status,
    int? dailyRateCents,
    // Ganha o parâmetro que faltava: o campo existe na classe desde sempre,
    // mas o copyWith nunca o recebia — editar uma máquina preservava sempre
    // a data de aquisição original, mesmo tentando mudá-la.
    DateTime? acquiredOn,
    int? purchasePriceCents,
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
    acquiredOn: acquiredOn ?? this.acquiredOn,
    purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
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
    this.address,
    this.postalCode,
    this.locality,
    this.notes = '',
    this.companyId = 'local-company',
    this.archived = false,
    this.createdAt,
  });
  final String id, name, phone, notes;
  final String companyId;
  final String? taxId, email, address, postalCode, locality;

  /// Quando este cliente entrou na casa.
  ///
  /// Existe por causa de um número errado: o "Clientes novos (30d)" contava
  /// pela data de início da primeira reserva, e dois clientes criados na manhã
  /// de 10 de Agosto de 2026, com reservas marcadas para dia 11 e 12, davam
  /// **zero** — só contariam no dia em que a máquina saísse. Um cliente é novo
  /// no dia em que se regista, não no dia em que a máquina sai.
  ///
  /// `null` num registo cujo id também não saiba a data (ver [dataDoId]) — aí
  /// não se conta como novo, que é diferente de se inventar uma data.
  final DateTime? createdAt;

  /// A data escondida no id, para os clientes gravados antes de existir
  /// [createdAt].
  ///
  /// Os ids nascem `c<microsegundos>` — é o relógio da app no instante em que o
  /// cliente foi criado, já lá escrito. Ler daí não é adivinhar: é recuperar o
  /// que ficou registado. `null` quando o id não é um relógio (as sementes de
  /// demonstração, `c1`, `c2`) ou quando a data que dele sai é impossível.
  static DateTime? dataDoId(String id) {
    final micros = int.tryParse(id.startsWith('c') ? id.substring(1) : id);
    if (micros == null || micros <= 0) return null;
    final data = DateTime.fromMicrosecondsSinceEpoch(micros);
    // O Punho não existia em 2020, e nada foi criado no século que vem.
    if (data.year < 2020 || data.year > 2100) return null;
    return data;
  }

  /// Soft-delete, como em [Machine], [Vehicle] e [Collaborator]: um cliente
  /// arquivado sai das listas activas, mas o registo continua a existir —
  /// reservas e recebimentos antigos apontam sempre para alguém que existe.
  final bool archived;

  Customer copyWith({
    String? name,
    String? phone,
    String? taxId,
    String? email,
    String? address,
    String? postalCode,
    String? locality,
    String? notes,
    bool? archived,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    taxId: taxId ?? this.taxId,
    email: email ?? this.email,
    address: address ?? this.address,
    postalCode: postalCode ?? this.postalCode,
    locality: locality ?? this.locality,
    notes: notes ?? this.notes,
    companyId: companyId,
    archived: archived ?? this.archived,
    // Não é editável: a data de entrada de um cliente não se corrige a partir
    // de um formulário de edição.
    createdAt: createdAt,
  );
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
    this.convertedCustomerId,
    this.bookingId,
  });
  final String id, name, phone, summary;
  final LeadStatus status;
  final LeadSource? source;
  final DateTime createdAt;
  final String? collaboratorResponsibleId;

  /// O cliente em que esta lead se tornou.
  ///
  /// `LeadStatus.converted` dizia que a conversão aconteceu, mas não dizia em
  /// quem — a cadeia partia-se logo no primeiro elo e não havia como saber o
  /// que a origem tinha rendido. Com este campo e o [bookingId], a pergunta
  /// "quanto é que o Facebook trouxe" deixa de ser uma contagem de leads e
  /// passa a ser uma soma de euros: `Lead → Customer → Booking → Receipt`.
  final String? convertedCustomerId;

  /// O primeiro trabalho que este cliente deu depois de convertido.
  ///
  /// Só o primeiro, de propósito: é o que fecha o ciclo da origem — a lead
  /// chegou e resultou em trabalho. Os trabalhos seguintes já não pertencem à
  /// campanha, pertencem à relação, e misturá-los inflacionaria o retorno de
  /// quem trouxe o cliente uma vez.
  final String? bookingId;

  Lead copyWith({
    LeadStatus? status,
    String? collaboratorResponsibleId,
    String? convertedCustomerId,
    String? bookingId,
  }) => Lead(
    id: id,
    name: name,
    phone: phone,
    status: status ?? this.status,
    createdAt: createdAt,
    source: source,
    summary: summary,
    collaboratorResponsibleId:
        collaboratorResponsibleId ?? this.collaboratorResponsibleId,
    convertedCustomerId: convertedCustomerId ?? this.convertedCustomerId,
    bookingId: bookingId ?? this.bookingId,
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
