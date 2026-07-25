/// Estado da licença deste terminal, tal como devolvido pela Edge Function
/// `validar-licenca` do Control.
enum EstadoLicenca {
  /// Licença válida. A app funciona sem restrições.
  activa,

  /// Existiu licença mas a validade já passou.
  expirada,

  /// Licença suspensa manualmente no Control.
  inactiva,

  /// O terminal ainda não está registado em `licencas`.
  inexistente,
}

EstadoLicenca _estadoDe(Object? valor) => switch (valor) {
  'activa' => EstadoLicenca.activa,
  'expirada' => EstadoLicenca.expirada,
  'inactiva' => EstadoLicenca.inactiva,
  _ => EstadoLicenca.inexistente,
};

int _inteiroDe(Object? valor) => switch (valor) {
  final int x => x,
  final num x => x.toInt(),
  final String x => int.tryParse(x) ?? 0,
  _ => 0,
};

String? _textoDe(Object? valor) {
  if (valor is! String) return null;
  final limpo = valor.trim();
  return limpo.isEmpty ? null : limpo;
}

/// Fotografia do estado de licenciamento deste terminal para a app `punho`.
class LicencaInfo {
  const LicencaInfo({
    required this.estado,
    required this.machineId,
    this.app = 'punho',
    this.plano,
    this.nif,
    this.nome,
    this.validade,
    this.diasRestantes = 0,
    this.oferta = false,
    this.tier = 'base',
    this.preferenciasFeatures = const {},
  });

  final EstadoLicenca estado;
  final String app;

  /// `trial`, `mensal`, … — mesmo conjunto de planos usado pelo POS.
  final String? plano;
  final String? nif;
  final String? nome;
  final DateTime? validade;
  final int diasRestantes;
  final bool oferta;
  final String machineId;

  /// `base` ou `pro`.
  final String tier;
  final Map<String, dynamic> preferenciasFeatures;

  /// A app deve funcionar sem restrições.
  bool get funcional => estado == EstadoLicenca.activa;

  /// Período de avaliação a decorrer.
  bool get emTrial => plano == 'trial' && funcional;

  factory LicencaInfo.fromJson(
    Map<String, dynamic> json, {
    String machineId = '',
  }) {
    final validadeCrua = json['validade'];
    return LicencaInfo(
      estado: _estadoDe(json['estado']),
      machineId: _textoDe(json['machine_id']) ?? machineId,
      app: _textoDe(json['app']) ?? 'punho',
      plano: _textoDe(json['plano']),
      nif: _textoDe(json['nif']),
      nome: _textoDe(json['nome']),
      validade: validadeCrua is String
          ? DateTime.tryParse(validadeCrua)
          : null,
      diasRestantes: _inteiroDe(json['dias_restantes']),
      oferta: json['oferta'] == true,
      tier: _textoDe(json['tier']) ?? 'base',
      preferenciasFeatures: switch (json['preferencias_features']) {
        final Map<String, dynamic> mapa => mapa,
        final Map mapa => Map<String, dynamic>.from(mapa),
        _ => const {},
      },
    );
  }
}
