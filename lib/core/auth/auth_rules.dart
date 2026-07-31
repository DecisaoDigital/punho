import '../../features/auth/data/acesso_service.dart'
    show codigoEmailJaRegistado;

/// Regras puras da autenticação, separadas da UI para poderem ser testadas.
class AuthRules {
  AuthRules._();

  static String? validarEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Indica o email.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Indica um email válido.';
    }
    return null;
  }

  static String? validarPalavraPasse(String value) {
    if (value.length < 8) {
      return 'A palavra-passe deve ter pelo menos 8 caracteres.';
    }
    return null;
  }

  static String? validarNomeEmpresa(String value) =>
      value.trim().isEmpty ? 'Indica o nome da empresa.' : null;

  /// Nunca expõe mensagens técnicas vindas do fornecedor de autenticação.
  ///
  /// Os códigos vêm do enum `AuthErrorCode` do `gotrue`; os que aqui estão
  /// foram conferidos contra essa lista, e não inventados a partir do que
  /// parecia provável. O `punho_email_ja_registado` é a excepção, e é nosso —
  /// ver `codigoEmailJaRegistado`.
  static String mensagemSegura(String? code) {
    switch (code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return 'Email ou palavra-passe incorretos.';
      case 'user_already_exists':
      case 'email_exists':
      case 'identity_already_exists':
      case codigoEmailJaRegistado:
        return 'Este email já tem conta. Faz início de sessão.';
      case 'weak_password':
        return 'Palavra-passe demasiado fraca. Usa pelo menos 8 caracteres.';
      case 'validation_failed':
      case 'email_address_invalid':
        return 'Email inválido.';
      case 'email_not_confirmed':
        return 'Confirma o email antes de iniciares sessão.';
      case 'over_email_send_rate_limit':
        return 'Muitas tentativas seguidas. Espera um minuto.';
      case 'over_request_rate_limit':
        return 'Foram feitas demasiadas tentativas. Tenta novamente mais tarde.';
      case 'signup_disabled':
        return 'O registo está desactivado de momento.';
      default:
        return 'Não foi possível concluir. Confirma a ligação e tenta novamente.';
    }
  }
}
