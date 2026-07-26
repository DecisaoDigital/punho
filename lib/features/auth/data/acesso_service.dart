import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/estado_acesso.dart';

/// Convite gerado por um gestor, para partilhar por fora (não há envio de
/// emails nesta fase).
class Convite {
  final String codigo;
  final String email;
  final String perfil;
  final DateTime expiraEm;
  final bool usado;

  const Convite({
    required this.codigo,
    required this.email,
    required this.perfil,
    required this.expiraEm,
    this.usado = false,
  });

  factory Convite.fromJson(Map<String, dynamic> json) => Convite(
    codigo: json['codigo'] as String,
    email: (json['email'] as String?) ?? '',
    perfil: (json['perfil'] as String?) ?? 'colaborador',
    expiraEm: DateTime.parse(json['expira_em'] as String),
    usado: json['usado'] == true,
  );

  bool expiradoEm(DateTime agora) => !agora.isBefore(expiraEm);
  bool disponivelEm(DateTime agora) => !usado && !expiradoEm(agora);
}

/// Resultado da validação de um código de convite, antes do registo.
enum ValidacaoConvite { valido, invalido, expirado, usado }

extension ValidacaoConviteMensagem on ValidacaoConvite {
  /// Mensagem para o utilizador. Não distingue "não existe" de "de outra
  /// empresa" — não há nada a ganhar em dizê-lo.
  String? get mensagem => switch (this) {
    ValidacaoConvite.valido => null,
    ValidacaoConvite.expirado =>
      'Este código de convite já expirou. Pede um novo ao gestor.',
    ValidacaoConvite.usado =>
      'Este código de convite já foi utilizado. Pede um novo ao gestor.',
    ValidacaoConvite.invalido =>
      'Código de convite inválido, expirado ou já utilizado.',
  };
}

/// Contrato de tudo o que a área de acessos precisa do servidor.
///
/// É uma interface fina de propósito: o repositório não tem package de mocking
/// e `SupabaseClient` é uma classe concreta com API encadeada, impossível de
/// fakear a sério. Os testes implementam isto; a produção usa
/// [SupabaseAcessoService].
abstract class AcessoService {
  Future<EstadoAcesso> meuAcesso();
  Future<ValidacaoConvite> validarConvite(String codigo);
  Future<void> registar({
    required String email,
    required String palavraPasse,
    required String nome,
    required String empresa,
    required String perfil,
    String? codigoConvite,
  });
  Future<Convite> criarConvite({required String email, required String perfil});
  Future<List<Convite>> listarConvites();
  Future<void> terminarSessao();
}

class SupabaseAcessoService implements AcessoService {
  SupabaseAcessoService(this._client);
  final SupabaseClient _client;

  @override
  Future<EstadoAcesso> meuAcesso() async {
    final linhas = await _client.rpc('punho_meu_acesso') as List<dynamic>;
    if (linhas.isEmpty) {
      return const EstadoAcesso(membroAtivo: false, estado: 'pendente');
    }
    return EstadoAcesso.fromJson(linhas.first as Map<String, dynamic>);
  }

  @override
  Future<ValidacaoConvite> validarConvite(String codigo) async {
    final estado = await _client.rpc(
      'punho_validar_convite',
      params: {'p_codigo': codigo},
    );
    return switch (estado as String?) {
      'valido' => ValidacaoConvite.valido,
      'expirado' => ValidacaoConvite.expirado,
      'usado' => ValidacaoConvite.usado,
      _ => ValidacaoConvite.invalido,
    };
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
    // `app: 'punho'` é o que o trigger de auth.users usa para distinguir este
    // registo dos do POS, que partilham o mesmo projecto Supabase.
    await _client.auth.signUp(
      email: email,
      password: palavraPasse,
      data: {
        'app': 'punho',
        'nome': nome,
        'empresa': empresa,
        'perfil': perfil,
        if (codigoConvite != null && codigoConvite.isNotEmpty)
          'convite': codigoConvite,
      },
    );
  }

  @override
  Future<Convite> criarConvite({
    required String email,
    required String perfil,
  }) async {
    final linhas =
        await _client.rpc(
              'punho_criar_convite',
              params: {'p_email': email, 'p_perfil': perfil},
            )
            as List<dynamic>;
    final linha = linhas.first as Map<String, dynamic>;
    return Convite(
      codigo: linha['codigo'] as String,
      email: email,
      perfil: perfil,
      expiraEm: DateTime.parse(linha['expira_em'] as String),
    );
  }

  @override
  Future<List<Convite>> listarConvites() async {
    final linhas = await _client
        .from('punho_convites')
        .select('codigo, email, perfil, expira_em, usado')
        .order('criado_em', ascending: false);
    return (linhas as List)
        .cast<Map<String, dynamic>>()
        .map(Convite.fromJson)
        .toList();
  }

  @override
  Future<void> terminarSessao() => _client.auth.signOut();
}
