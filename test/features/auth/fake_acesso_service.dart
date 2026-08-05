import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';

/// Fake do [AcessoService] para os testes de acessos.
///
/// O repositório não tem package de mocking de propósito (ver
/// `lib/core/licenca/licenca_service.dart`), por isso implementa-se a interface
/// à mão e regista-se o que foi chamado.
class FakeAcessoService implements AcessoService {
  FakeAcessoService({
    EstadoAcesso? acesso,
    this.validacao = ValidacaoConvite.valido,
    this.convites = const [],
    this.erroAoRegistar,
    this.erroAoCriarConvite,
    this.erroAoLerAcesso,
    this.utilizadorId = 'user-1',
  }) : acesso =
           acesso ?? const EstadoAcesso(membroAtivo: false, estado: 'pendente');

  @override
  final String? utilizadorId;

  EstadoAcesso acesso;
  ValidacaoConvite validacao;
  List<Convite> convites;
  Object? erroAoRegistar;
  Object? erroAoCriarConvite;
  Object? erroAoLerAcesso;
  Object? erroAoPedirAcesso;

  /// O que o servidor devolve ao pedido — e o que a conta passa a ter.
  String estadoAposPedir = 'pendente';

  final registos = <Map<String, dynamic>>[];
  final pedidosDeAcesso = <Map<String, String>>[];
  final convitesCriados = <Map<String, String>>[];
  final codigosValidados = <String>[];
  int sessoesTerminadas = 0;

  @override
  Future<EstadoAcesso> meuAcesso() async {
    if (erroAoLerAcesso != null) throw erroAoLerAcesso!;
    return acesso;
  }

  @override
  Future<ValidacaoConvite> validarConvite(String codigo) async {
    codigosValidados.add(codigo);
    return validacao;
  }

  @override
  Future<void> registar({
    required String email,
    required String palavraPasse,
    required String nome,
    required String empresa,
    required String perfil,
    String? codigoConvite,
    String? machineId,
  }) async {
    if (erroAoRegistar != null) throw erroAoRegistar!;
    registos.add({
      'email': email,
      'nome': nome,
      'empresa': empresa,
      'perfil': perfil,
      'convite': codigoConvite,
      'machine_id': machineId,
    });
  }

  @override
  Future<String> pedirAcesso({
    required String nome,
    required String empresa,
    required String perfil,
    String? machineId,
  }) async {
    if (erroAoPedirAcesso != null) throw erroAoPedirAcesso!;
    pedidosDeAcesso.add({
      'nome': nome,
      'empresa': empresa,
      'perfil': perfil,
      'machine_id': machineId ?? '',
    });
    // O servidor passa a ter pedido: a leitura seguinte tem de o reflectir,
    // senão o teste não distingue "pediu" de "continua sem pedido".
    acesso = EstadoAcesso(
      membroAtivo: acesso.membroAtivo,
      perfil: acesso.perfil,
      estado: estadoAposPedir,
      empresaId: acesso.empresaId,
    );
    return estadoAposPedir;
  }

  @override
  Future<Convite> criarConvite({
    required String email,
    required String perfil,
  }) async {
    if (erroAoCriarConvite != null) throw erroAoCriarConvite!;
    convitesCriados.add({'email': email, 'perfil': perfil});
    return Convite(
      codigo: 'ABC1234567',
      email: email,
      perfil: perfil,
      expiraEm: DateTime.now().add(const Duration(days: 14)),
    );
  }

  @override
  Future<List<Convite>> listarConvites() async => convites;

  @override
  Future<void> terminarSessao() async => sessoesTerminadas++;
}
