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
    this.erroAoCriarConvite,
    this.erroAoLerAcesso,
    this.utilizadorId = 'user-1',
  }) : acesso = acesso ?? const EstadoAcesso(membroAtivo: false, estado: 'pendente');

  @override
  final String? utilizadorId;

  EstadoAcesso acesso;
  ValidacaoConvite validacao;
  List<Convite> convites;
  Object? erroAoCriarConvite;
  Object? erroAoLerAcesso;

  final registos = <Map<String, dynamic>>[];
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
  }) async {
    registos.add({
      'email': email,
      'nome': nome,
      'empresa': empresa,
      'perfil': perfil,
      'convite': codigoConvite,
    });
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
