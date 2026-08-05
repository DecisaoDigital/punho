/// Tipo do que está em disputa. Começa só com reservas de máquina, mas o
/// modelo não está amarrado a isso — outros tipos de conflito (transversal
/// a apps, não só ao Punho) podem entrar aqui no futuro.
enum TipoConflito { reservaMaquina }

enum EstadoConflito { pendente, resolvido }

/// Um conflito que exige decisão humana — hoje só o caso de duas reservas
/// confirmadas na mesma máquina, chegadas de dois aparelhos que estiveram
/// offline ao mesmo tempo (ver `docs`/plano em curso). Nunca se resolve
/// sozinho: existe para ser mostrado a alguém.
class ConflitoPendente {
  const ConflitoPendente({
    required this.id,
    required this.tipo,
    required this.entidadeAId,
    required this.entidadeBId,
    required this.machineIdsPartilhados,
    required this.envolvidos,
    required this.criadoEm,
    this.estado = EstadoConflito.pendente,
    this.resolvidoEm,
    this.resolvidoPor,
    this.ficaComEntidadeId,
  });

  final String id;
  final TipoConflito tipo;
  final String entidadeAId, entidadeBId;
  final List<String> machineIdsPartilhados;
  final List<String> envolvidos;
  final DateTime criadoEm;
  final EstadoConflito estado;
  final DateTime? resolvidoEm;
  final String? resolvidoPor;
  final String? ficaComEntidadeId;

  /// `id` determinístico a partir do par de reservas, ordenado
  /// alfabeticamente — quem detecta o mesmo conflito em dois aparelhos
  /// diferentes (cada um ao aplicar a operação remota da reserva do outro)
  /// chega sempre ao mesmo `id`, sem coordenação entre eles. Sem isto,
  /// as duas detecções criavam duas linhas para a mesma disputa, e resolver
  /// uma não resolvia a outra no aparelho da contraparte.
  factory ConflitoPendente.reservaMaquina({
    required String reservaId1,
    required String reservaId2,
    required List<String> machineIdsPartilhados,
    required List<String> envolvidos,
    required DateTime criadoEm,
  }) {
    final ordenados = [reservaId1, reservaId2]..sort();
    return ConflitoPendente(
      id: 'reservaMaquina:${ordenados[0]}:${ordenados[1]}',
      tipo: TipoConflito.reservaMaquina,
      entidadeAId: ordenados[0],
      entidadeBId: ordenados[1],
      machineIdsPartilhados: machineIdsPartilhados,
      envolvidos: envolvidos.toSet().toList(),
      criadoEm: criadoEm,
    );
  }

  ConflitoPendente resolvidoComo({
    required String ficaComEntidadeId,
    required String resolvidoPor,
    required DateTime resolvidoEm,
  }) => ConflitoPendente(
    id: id,
    tipo: tipo,
    entidadeAId: entidadeAId,
    entidadeBId: entidadeBId,
    machineIdsPartilhados: machineIdsPartilhados,
    envolvidos: envolvidos,
    criadoEm: criadoEm,
    estado: EstadoConflito.resolvido,
    resolvidoEm: resolvidoEm,
    resolvidoPor: resolvidoPor,
    ficaComEntidadeId: ficaComEntidadeId,
  );

  Map<String, Object?> paraFila() => {
    'id': id,
    'tipo': tipo.name,
    'entidade_a_id': entidadeAId,
    'entidade_b_id': entidadeBId,
    'machine_ids_partilhados': machineIdsPartilhados,
    'envolvidos': envolvidos,
    'criado_em': criadoEm.toUtc().toIso8601String(),
    'estado': estado.name,
    'resolvido_em': resolvidoEm?.toUtc().toIso8601String(),
    'resolvido_por': resolvidoPor,
    'fica_com_entidade_id': ficaComEntidadeId,
  };

  factory ConflitoPendente.daFila(Map<String, dynamic> json) =>
      ConflitoPendente(
        id: json['id'] as String,
        tipo: TipoConflito.values.byName(json['tipo'] as String),
        entidadeAId: json['entidade_a_id'] as String,
        entidadeBId: json['entidade_b_id'] as String,
        machineIdsPartilhados: List<String>.from(
          json['machine_ids_partilhados'] as List? ?? const [],
        ),
        envolvidos: List<String>.from(json['envolvidos'] as List? ?? const []),
        // `toLocal` de propósito, mesmo motivo do `OperacaoPendente`: guarda-se
        // em UTC (o que o servidor entende) mas lê-se cá dentro na hora do
        // telemóvel.
        criadoEm:
            DateTime.tryParse(json['criado_em'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        estado: EstadoConflito.values.byName(
          json['estado'] as String? ?? 'pendente',
        ),
        resolvidoEm: json['resolvido_em'] == null
            ? null
            : DateTime.tryParse(json['resolvido_em'] as String)?.toLocal(),
        resolvidoPor: json['resolvido_por'] as String?,
        ficaComEntidadeId: json['fica_com_entidade_id'] as String?,
      );
}
