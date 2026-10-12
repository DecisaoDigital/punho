import '../../../core/navigation/app_destination.dart';

/// O que a pessoa é na equipa de gestão e o que não vê.
///
/// A administrativa tem os mesmos poderes de um gerente no servidor (o perfil é
/// `gestor`). O que a distingue é a vista: o gerente escolhe que ecrãs da barra
/// lateral ela não vê (por exemplo o Painel, com a faturação).
///
/// Esconder um ecrã é apresentação, não segurança: os dados chegam ao aparelho
/// dela e os poderes são de gestor, por vontade do dono.
class FuncaoNaEquipa {
  const FuncaoNaEquipa({required this.funcao, this.ecrasOcultos = const {}});

  /// `gerente` ou `administrativa`.
  final String funcao;
  final Set<String> ecrasOcultos;

  static const gerente = FuncaoNaEquipa(funcao: 'gerente');

  bool get eAdministrativa => funcao == 'administrativa';

  /// Nome que fica registado em quem validou uma lead.
  String get nomeParaRegisto => eAdministrativa ? 'administrativa' : 'gerente';

  factory FuncaoNaEquipa.fromJson(Map<String, dynamic> json) => FuncaoNaEquipa(
    funcao: (json['funcao'] as String?) == 'administrativa'
        ? 'administrativa'
        : 'gerente',
    ecrasOcultos: {
      for (final e in (json['ecras_ocultos'] as List?) ?? const [])
        e.toString(),
    },
  );

  /// Um destino está escondido se o seu nome está na lista. Os que viraram abas
  /// de Empresa (Finanças, Veículos, Metas) escondem-se com ela.
  bool oculta(AppDestination d) =>
      ecrasOcultos.contains(d.name) ||
      (d.abaDeEmpresa != null &&
          ecrasOcultos.contains(AppDestination.empresa.name));

  List<AppDestination> filtrar(List<AppDestination> destinos) => [
    for (final d in destinos)
      if (!oculta(d)) d,
  ];
}

/// Os ecrãs que o gerente pode esconder, pela ordem da barra lateral.
const ecrasEscondiveis = <AppDestination>[
  AppDestination.management,
  AppDestination.semana,
  AppDestination.bookings,
  AppDestination.clients,
  AppDestination.machines,
  AppDestination.employees,
  AppDestination.empresa,
  AppDestination.tasks,
  AppDestination.kpis,
];

/// Uma pessoa da equipa de gestão, vista pelo gerente.
class MembroDaEquipa {
  const MembroDaEquipa({
    required this.userId,
    required this.email,
    required this.funcao,
    required this.eu,
  });
  final String userId, email;
  final FuncaoNaEquipa funcao;
  final bool eu;

  factory MembroDaEquipa.fromJson(Map<String, dynamic> json) => MembroDaEquipa(
    userId: json['user_id'] as String,
    email: (json['email'] as String?) ?? '',
    funcao: FuncaoNaEquipa.fromJson(json),
    eu: json['eu'] == true,
  );
}
