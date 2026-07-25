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
  static String mensagemSegura(String? code) {
    switch (code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return 'Email ou palavra-passe incorretos.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Já existe uma conta com este email. Inicia sessão.';
      case 'email_not_confirmed':
        return 'Confirma o email antes de iniciares sessão.';
      case 'over_request_rate_limit':
        return 'Foram feitas demasiadas tentativas. Tenta novamente mais tarde.';
      default:
        return 'Não foi possível concluir. Confirma a ligação e tenta novamente.';
    }
  }
}
