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

/// `qualified`: a lead já foi falada e tem interesse real; falta o contacto
/// extra (reunião) e o fecho. Acrescentado no fim: serializa-se por nome.
enum LeadStatus { newLead, contacted, proposal, lost, converted, qualified }

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

  /// O operador foi à procura: prospecção feita por ele no terreno.
  ownProspecting,
}

String leadSourceLabel(LeadSource origem) => switch (origem) {
  LeadSource.call => 'Chamada',
  LeadSource.referral => 'Recomendação',
  LeadSource.facebook => 'Facebook',
  LeadSource.google => 'Google',
  LeadSource.landingPage => 'Site',
  LeadSource.whatsapp => 'WhatsApp',
  LeadSource.agenda => 'Agenda',
  LeadSource.ownProspecting => 'Prospecção própria',
  LeadSource.other => 'Outro',
};

String leadStatusLabel(LeadStatus estado) => switch (estado) {
  LeadStatus.newLead => 'Nova',
  LeadStatus.contacted => 'Contactada',
  LeadStatus.proposal => 'Com proposta',
  LeadStatus.lost => 'Perdida',
  LeadStatus.converted => 'Convertida',
  LeadStatus.qualified => 'Qualificada',
};

/// O que uma entrada do calendário de Reservas é. Uma reunião não tem
/// máquina, preço nem recebimentos: partilha o calendário e o log com as
/// reservas, mas nenhuma conta de aluguer a deve ver.
enum BookingTipo { maquina, reuniao }

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
    this.operadorResponsavelId,
  });
  final String id, name, phone, notes;

  /// Operador que cuida deste cliente (entregas, recolhas, relação). Cliente
  /// antigo que volte a alugar não é lead: é uma reserva com este responsável.
  final String? operadorResponsavelId;
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
    // O Fist não existia em 2020, e nada foi criado no século que vem.
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
    String? operadorResponsavelId,
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
    operadorResponsavelId: operadorResponsavelId ?? this.operadorResponsavelId,
  );
}

/// Telemóvel só com dígitos e sem o indicativo português, para comparar
/// «+351 913 000 001» com «913000001».
String telefoneNormalizado(String telefone) {
  var d = telefone.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00351')) d = d.substring(5);
  if (d.startsWith('351') && d.length > 9) d = d.substring(3);
  return d;
}

/// Mensagem de erro se faltar o nome ou o telemóvel de uma lead; `null` se
/// estiver completa. Partilhada pelos dois formulários (gestor e colaborador)
/// para que não voltem a divergir: o do gestor fechava sem gravar nem avisar.
String? validarLead(String nome, String telemovel) =>
    nome.trim().isEmpty || telemovel.trim().isEmpty
    ? 'A lead precisa do nome e do telemóvel.'
    : null;

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

    /// Para atribuir ou desatribuir: devolve o novo valor (pode ser `null`).
    String? Function()? atribuidaA,
  }) => Lead(
    id: id,
    name: name,
    phone: phone,
    status: status ?? this.status,
    createdAt: createdAt,
    source: source,
    summary: summary,
    collaboratorResponsibleId: atribuidaA != null
        ? atribuidaA()
        : collaboratorResponsibleId ?? this.collaboratorResponsibleId,
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
    this.tipo = BookingTipo.maquina,
    this.lembreteMinutos,
    this.criadoPorUid,
  });
  final String id, customerId, notes;
  final List<String> machineIds;
  final DateTime startsAt, endsAt;
  final BookingStatus status;
  final int? expectedValueCents;
  final String? collaboratorResponsibleId;
  final String companyId, customerNameSnapshot, collaboratorNameSnapshot;

  /// Reservas antigas não têm o campo e valem como `maquina`.
  final BookingTipo tipo;

  /// Só das reuniões: quantos minutos antes avisar; `null` = sem aviso.
  final int? lembreteMinutos;

  /// Conta de quem marcou (carimbada pelo servidor). É nela, e só nela, que o
  /// alarme toca. Não confundir com `collaboratorResponsibleId`, que é um
  /// número do negócio e não a conta.
  final String? criadoPorUid;

  bool get eReuniao => tipo == BookingTipo.reuniao;

  Booking copyWith({
    BookingStatus? status,
    int? expectedValueCents,
    String? notes,
    String? collaboratorResponsibleId,
    int? lembreteMinutos,
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
    tipo: tipo,
    lembreteMinutos: lembreteMinutos ?? this.lembreteMinutos,
    criadoPorUid: criadoPorUid,
  );
}

class BookingConflict {
  const BookingConflict(this.machine, this.booking);
  final Machine machine;
  final Booking booking;
}
