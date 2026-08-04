/// O que o Punho pede ao contabilista, e o que ele já respondeu.
///
/// Desenho e razões em `docs/PORTAL_DO_CONTABILISTA.md`. O resumo é: o
/// contabilista não é utilizador da app. É uma fonte de dados que abre um link,
/// preenche uma grelha de meses e vai-se embora. Estes modelos são o que a app
/// precisa de saber sobre esse trabalho.
library;

/// De quanto em quanto tempo se pergunta uma rubrica.
enum PeriodicidadeRubrica {
  /// Uma resposta por mês. É o que dá comparação homóloga.
  mensal,

  /// Uma resposta e pronto — o regime de contabilidade, o CAE.
  unica;

  static PeriodicidadeRubrica dePostgres(String? valor) =>
      valor == 'unica' ? PeriodicidadeRubrica.unica : PeriodicidadeRubrica.mensal;
}

/// De onde veio o número. Não é decoração: quando o contabilista e o gestor
/// discordam sobre o mesmo mês, é isto que diz qual é qual.
enum OrigemResposta {
  contabilista,
  gestor;

  static OrigemResposta dePostgres(String? valor) =>
      valor == 'gestor' ? OrigemResposta.gestor : OrigemResposta.contabilista;

  String get paraPostgres => name;

  String get label => switch (this) {
    OrigemResposta.contabilista => 'Contabilista',
    OrigemResposta.gestor => 'Escrito por si',
  };
}

/// Uma pergunta do catálogo. Vive na base (`punho_rubricas_contabilista`) e não
/// em Dart, porque tem dois leitores — esta app e a página que o contabilista
/// abre. Duas cópias divergiriam à segunda rubrica acrescentada, e a que
/// divergisse era a que ele via.
class RubricaContabilista {
  const RubricaContabilista({
    required this.chave,
    required this.rotulo,
    required this.periodicidade,
    required this.tipo,
    this.ajuda,
    this.opcoes = const [],
    this.essencial = false,
    this.aceitaAnual = false,
  });

  final String chave;
  final String rotulo;
  final PeriodicidadeRubrica periodicidade;

  /// `euros`, `texto` ou `opcao`.
  final String tipo;
  final String? ajuda;
  final List<String> opcoes;

  /// Só as essenciais viram tarefa para o gestor. Pedir-lhe o que não muda nada
  /// no que ele vê gasta a única atenção que ele tem.
  final bool essencial;

  /// Aceita "não sei os meses, o ano todo deu X". Ver [aceitaAnual] no catálogo:
  /// o IVA liquidado não aceita, porque um total anual de IVA não reparte.
  final bool aceitaAnual;

  bool get eEuros => tipo == 'euros';

  factory RubricaContabilista.fromJson(Map<String, dynamic> json) =>
      RubricaContabilista(
        chave: json['chave'] as String,
        rotulo: json['rotulo'] as String,
        periodicidade: PeriodicidadeRubrica.dePostgres(
          json['periodicidade'] as String?,
        ),
        tipo: (json['tipo'] as String?) ?? 'euros',
        ajuda: json['ajuda'] as String?,
        opcoes:
            (json['opcoes'] as List<dynamic>?)?.map((o) => o as String).toList() ??
            const [],
        essencial: json['essencial'] == true,
        aceitaAnual: json['aceita_anual'] == true,
      );
}

/// Uma resposta guardada — do contabilista ou do gestor.
///
/// [mes] e [ano] excluem-se: ou é a resposta de um mês, ou é o total de um ano,
/// ou é uma rubrica de resposta única e são ambos nulos. A base garante-o com
/// uma constraint; aqui é só o que se lê.
class RespostaContabilista {
  const RespostaContabilista({
    required this.rubrica,
    required this.origem,
    this.mes,
    this.ano,
    this.valorCentavos,
    this.valorTexto,
  });

  final String rubrica;
  final DateTime? mes;
  final int? ano;
  final int? valorCentavos;
  final String? valorTexto;
  final OrigemResposta origem;

  factory RespostaContabilista.fromJson(Map<String, dynamic> json) =>
      RespostaContabilista(
        rubrica: json['rubrica'] as String,
        mes: json['mes'] == null ? null : DateTime.parse(json['mes'] as String),
        ano: (json['ano'] as num?)?.toInt(),
        valorCentavos: (json['valor_centavos'] as num?)?.toInt(),
        valorTexto: json['valor_texto'] as String?,
        origem: OrigemResposta.dePostgres(json['origem'] as String?),
      );
}

/// O que ficou por responder, agregado por rubrica.
///
/// Agregado de propósito. Cinco rubricas mensais em sessenta meses são
/// trezentas células; trezentas tarefas não são uma lista, são um muro.
class LacunaContabilista {
  const LacunaContabilista({
    required this.rubrica,
    required this.rotulo,
    required this.periodicidade,
    required this.emFalta,
    required this.soAnual,
    this.primeiroMes,
    this.ultimoMes,
  });

  final String rubrica;
  final String rotulo;
  final PeriodicidadeRubrica periodicidade;

  /// Meses sem cobertura nenhuma. Numa rubrica de resposta única é 1 ou 0.
  final int emFalta;

  /// Meses que só o total do ano cobre. Não é um buraco — é um número de pior
  /// qualidade, e por isso vale sugestão e não pendência.
  final int soAnual;

  final DateTime? primeiroMes;
  final DateTime? ultimoMes;

  bool get temAlgoAPedir => emFalta > 0 || soAnual > 0;

  factory LacunaContabilista.fromJson(Map<String, dynamic> json) =>
      LacunaContabilista(
        rubrica: json['rubrica'] as String,
        rotulo: json['rotulo'] as String,
        periodicidade: PeriodicidadeRubrica.dePostgres(
          json['periodicidade'] as String?,
        ),
        emFalta: (json['em_falta'] as num?)?.toInt() ?? 0,
        soAnual: (json['so_anual'] as num?)?.toInt() ?? 0,
        primeiroMes: json['primeiro_mes'] == null
            ? null
            : DateTime.parse(json['primeiro_mes'] as String),
        ultimoMes: json['ultimo_mes'] == null
            ? null
            : DateTime.parse(json['ultimo_mes'] as String),
      );
}

/// Em que ponto está o convite. Deriva-se das datas, não é uma coluna: uma
/// coluna de estado e cinco datas dão seis sítios para a verdade estar errada.
enum EstadoConvite {
  revogado,
  expirado,
  submetido,
  aberto,
  porAbrir;

  String get label => switch (this) {
    EstadoConvite.revogado => 'Revogado',
    EstadoConvite.expirado => 'Expirado',
    EstadoConvite.submetido => 'Entregue',
    EstadoConvite.aberto => 'A preencher',
    EstadoConvite.porAbrir => 'Ainda não abriu',
  };

  /// O link continua a servir para alguma coisa?
  bool get vivo =>
      this == EstadoConvite.submetido ||
      this == EstadoConvite.aberto ||
      this == EstadoConvite.porAbrir;
}

/// Um convite emitido. **Não tem o token** — a base guarda só o `sha256`, e o
/// valor em claro existe uma vez só, no ecrã que o criou.
class ConviteContabilista {
  const ConviteContabilista({
    required this.id,
    required this.mesInicial,
    required this.mesFinal,
    required this.criadoEm,
    required this.expiraEm,
    this.nome,
    this.email,
    this.mesInicialEfectivo,
    this.abertoEm,
    this.submetidoEm,
    this.revogadoEm,
  });

  final String id;
  final String? nome;
  final String? email;
  final DateTime mesInicial;

  /// O que o contabilista disse que faz sentido pedir, se disse. Uma empresa
  /// aberta em 2024 não tem 2021, e quem sabe isso é ele.
  ///
  /// Vale a pena mostrá-lo ao gestor: "pedi cinco anos, ele diz que só há
  /// desde Março de 2024" é o gestor a ficar a saber uma coisa sobre a própria
  /// empresa.
  final DateTime? mesInicialEfectivo;
  final DateTime mesFinal;
  final DateTime criadoEm;
  final DateTime expiraEm;
  final DateTime? abertoEm;
  final DateTime? submetidoEm;
  final DateTime? revogadoEm;

  EstadoConvite estadoEm(DateTime agora) {
    if (revogadoEm != null) return EstadoConvite.revogado;
    if (!agora.isBefore(expiraEm)) return EstadoConvite.expirado;
    if (submetidoEm != null) return EstadoConvite.submetido;
    if (abertoEm != null) return EstadoConvite.aberto;
    return EstadoConvite.porAbrir;
  }

  /// O período que está mesmo a ser preenchido.
  DateTime get inicioReal => mesInicialEfectivo ?? mesInicial;

  /// O contabilista encurtou o que lhe pediram?
  bool get periodoEncurtado =>
      mesInicialEfectivo != null && mesInicialEfectivo!.isAfter(mesInicial);

  /// Como se lhe chama numa lista. Sem nome nem email — que são opcionais,
  /// porque o gestor pode entregar o link à mão — sobra a data de emissão.
  String get designacao {
    final n = nome?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = email?.trim();
    if (e != null && e.isNotEmpty) return e;
    return 'Convite de ${criadoEm.day.toString().padLeft(2, '0')}/'
        '${criadoEm.month.toString().padLeft(2, '0')}';
  }

  factory ConviteContabilista.fromJson(Map<String, dynamic> json) =>
      ConviteContabilista(
        id: json['id'] as String,
        nome: json['nome'] as String?,
        email: json['email'] as String?,
        mesInicial: DateTime.parse(json['mes_inicial'] as String),
        mesInicialEfectivo: json['mes_inicial_efectivo'] == null
            ? null
            : DateTime.parse(json['mes_inicial_efectivo'] as String),
        mesFinal: DateTime.parse(json['mes_final'] as String),
        criadoEm: DateTime.parse(json['criado_em'] as String),
        expiraEm: DateTime.parse(json['expira_em'] as String),
        abertoEm: json['aberto_em'] == null
            ? null
            : DateTime.parse(json['aberto_em'] as String),
        submetidoEm: json['submetido_em'] == null
            ? null
            : DateTime.parse(json['submetido_em'] as String),
        revogadoEm: json['revogado_em'] == null
            ? null
            : DateTime.parse(json['revogado_em'] as String),
      );
}

/// O que volta de `punho_criar_convite_contabilista`, e a única vez que o token
/// existe em claro.
///
/// A base guarda o `sha256`. Se este objecto se perder antes de o gestor copiar
/// o link, não há como o recuperar — gera-se outro, e o outro revoga este. É
/// deliberado: um link perdido que continuasse a abrir era um link perdido a
/// escrever na contabilidade.
class ConviteCriado {
  const ConviteCriado({
    required this.token,
    required this.conviteId,
    required this.mesInicial,
    required this.mesFinal,
    required this.expiraEm,
  });

  final String token;
  final String conviteId;
  final DateTime mesInicial;
  final DateTime mesFinal;
  final DateTime expiraEm;

  factory ConviteCriado.fromJson(Map<String, dynamic> json) => ConviteCriado(
    token: json['token'] as String,
    conviteId: json['convite_id'] as String,
    mesInicial: DateTime.parse(json['mes_inicial'] as String),
    mesFinal: DateTime.parse(json['mes_final'] as String),
    expiraEm: DateTime.parse(json['expira_em'] as String),
  );
}
