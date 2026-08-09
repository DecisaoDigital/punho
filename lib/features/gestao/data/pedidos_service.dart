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

  /// Aprovar, ligando à ficha de empregado indicada — ou criando uma nova
  /// quando [colaboradorId] vem nulo.
  ///
  /// Nulo não é descuido: é a escolha "contratação nova", e o ecrã obriga a
  /// escolher entre as duas antes de deixar aprovar.
  Future<void> aprovar(String pedidoId, {String? colaboradorId}) =>
      _cliente.rpc(
        'punho_gestor_decidir_pedido',
        params: {
          'p_pedido_id': pedidoId,
          'p_decisao': 'aprovar',
          'p_colaborador_id': colaboradorId,
        },
      );

  Future<void> recusar(String pedidoId) => _cliente.rpc(
    'punho_gestor_decidir_pedido',
    params: {'p_pedido_id': pedidoId, 'p_decisao': 'recusar'},
  );
}

final pedidosServiceProvider = Provider<PedidosService>(
  (ref) => PedidosService(Supabase.instance.client),
);

final pedidosPendentesProvider = FutureProvider<List<PedidoPendente>>(
  (ref) => ref.watch(pedidosServiceProvider).pendentes(),
);
