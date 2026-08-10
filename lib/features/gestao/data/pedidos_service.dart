import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alguém que se inscreveu com um convite desta empresa e espera resposta.
///
/// O que aqui vem é o que a pessoa **declarou**, não um registo: o nome que
/// escreveu na app e, se o pôs, o contribuinte. Nada disto entrou ainda em
/// lado nenhum — é a aprovação que decide se entra, e onde.
class PedidoPendente {
  const PedidoPendente({
    required this.id,
    required this.email,
    required this.criadoEm,
    this.nome,
    this.nifDeclarado,
    this.app,
  });

  factory PedidoPendente.fromJson(Map<String, dynamic> json) => PedidoPendente(
    id: json['pedido_id'] as String,
    email: (json['email'] as String?) ?? '',
    criadoEm:
        DateTime.tryParse((json['criado_em'] as String?) ?? '') ??
        DateTime.now(),
    nome: json['nome'] as String?,
    nifDeclarado: json['nif_declarado'] as String?,
    app: json['app'] as String?,
  );

  final String id, email;
  final DateTime criadoEm;
  final String? nome, nifDeclarado, app;

  /// Como apresentar quem pede. Sem nome fica o email — é o único
  /// identificador que existe sempre, e é melhor que um espaço em branco.
  String get comoSeChama => nome ?? email;

  /// Veio da app do operador? Muda o que se lhe pode dar: pela OP entra
  /// sempre como operador, mesmo que o convite dissesse outra coisa.
  bool get veioDaAppDoOperador => app == 'punho_op';
}

/// Os pedidos da empresa, e a decisão sobre eles.
///
/// Vive fora do `AcessoService` de propósito: aquele é a porta de quem ainda
/// não entrou, e isto é uma ferramenta de quem já gere. Misturá-los obrigava
/// todos os duplos de teste do registo a saber de aprovações.
class PedidosService {
  const PedidosService(this._cliente);
  final SupabaseClient _cliente;

  Future<List<PedidoPendente>> pendentes() async {
    final linhas =
        await _cliente.rpc('punho_pedidos_da_minha_empresa') as List<dynamic>;
    return linhas
        .map((l) => PedidoPendente.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Os que já foram decididos — aprovados, recusados, revogados.
  ///
  /// Lista à parte da dos pendentes de propósito: aquela é a fila de trabalho,
  /// esta é o arquivo, e é dela que sai o caminho de volta para quem foi
  /// recusado por engano.
  Future<List<PedidoDecidido>> decididos() async {
    final linhas =
        await _cliente.rpc('punho_pedidos_decididos_da_minha_empresa')
            as List<dynamic>;
    return linhas
        .map((l) => PedidoDecidido.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Aprovar, ligando à ficha de empregado indicada — ou criando uma nova
  /// quando [colaboradorId] vem nulo.
  ///
  /// Nulo não é descuido: é a escolha "contratação nova", e o ecrã obriga a
  /// escolher entre as duas antes de deixar aprovar.
  ///
  /// [colaboradorId] é o id **local** da ficha, o mesmo que a app usa. Quem o
  /// traduz para o id da tabela é o servidor: a fórmula é dele, e um cliente
  /// que a soubesse ficava preso a ela para sempre.
  Future<void> aprovar(String pedidoId, {String? colaboradorId}) =>
      _decidir(pedidoId, 'aprovar', colaboradorId: colaboradorId);

  Future<void> recusar(String pedidoId) => _decidir(pedidoId, 'recusar');

  /// Tirar o acesso a quem o tinha. Não apaga ninguém — o membro fica
  /// inactivo, e quem trabalhou continua a constar com o custo que teve.
  Future<void> revogar(String pedidoId) => _decidir(pedidoId, 'revogar');

  /// Devolver à fila de decisão quem foi recusado ou revogado. Por si só não
  /// dá acesso nenhum: quem o dá é o `aprovar` que vem a seguir.
  Future<void> reabrir(String pedidoId) => _decidir(pedidoId, 'reabrir');

  Future<void> _decidir(
    String pedidoId,
    String decisao, {
    String? colaboradorId,
  }) => _cliente.rpc(
    'punho_gestor_decidir_pedido',
    params: {
      'p_pedido_id': pedidoId,
      'p_decisao': decisao,
      'p_colaborador_id': colaboradorId,
    },
  );
}

/// Um pedido que já teve resposta. O estado é o do servidor — `aprovado`,
/// `recusado` ou `revogado`.
class PedidoDecidido {
  const PedidoDecidido({
    required this.id,
    required this.email,
    required this.estado,
    this.nome,
    this.decididoEm,
  });

  factory PedidoDecidido.fromJson(Map<String, dynamic> json) => PedidoDecidido(
    id: json['pedido_id'] as String,
    email: (json['email'] as String?) ?? '',
    estado: (json['estado'] as String?) ?? '',
    nome: json['nome'] as String?,
    decididoEm: DateTime.tryParse((json['decidido_em'] as String?) ?? ''),
  );

  final String id, email, estado;
  final String? nome;
  final DateTime? decididoEm;

  String get comoSeChama => nome ?? email;

  /// Tem acesso neste momento? É o que decide se se lhe oferece revogar ou
  /// reabrir.
  bool get temAcesso => estado == 'aprovado';

  /// Ficou de fora — por recusa ou por revogação. É a estes que o caminho de
  /// volta interessa.
  bool get estaDeFora => estado == 'recusado' || estado == 'revogado';

  String get comoSeLe => switch (estado) {
    'aprovado' => 'Com acesso',
    'recusado' => 'Recusado',
    'revogado' => 'Acesso retirado',
    _ => estado,
  };
}

final pedidosServiceProvider = Provider<PedidosService>(
  (ref) => PedidosService(Supabase.instance.client),
);

final pedidosPendentesProvider = FutureProvider<List<PedidoPendente>>(
  (ref) => ref.watch(pedidosServiceProvider).pendentes(),
);

final pedidosDecididosProvider = FutureProvider<List<PedidoDecidido>>(
  (ref) => ref.watch(pedidosServiceProvider).decididos(),
);
