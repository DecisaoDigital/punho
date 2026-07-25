import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/auth/auth_rules.dart';

void main() {
  group('AuthRules', () {
    test('valida email, palavra-passe e empresa obrigatórios', () {
      expect(AuthRules.validarEmail(''), isNotNull);
      expect(AuthRules.validarEmail('sem-arroba'), isNotNull);
      expect(AuthRules.validarEmail('gestor@empresa.pt'), isNull);

      expect(AuthRules.validarPalavraPasse('1234567'), isNotNull);
      expect(AuthRules.validarPalavraPasse('12345678'), isNull);

      expect(AuthRules.validarNomeEmpresa('  '), isNotNull);
      expect(AuthRules.validarNomeEmpresa('Alugueres Norte'), isNull);
    });

    test('nunca apresenta a mensagem técnica do fornecedor', () {
      expect(
        AuthRules.mensagemSegura('invalid_credentials'),
        'Email ou palavra-passe incorretos.',
      );
      expect(
        AuthRules.mensagemSegura('erro-interno-com-detalhes'),
        'Não foi possível concluir. Confirma a ligação e tenta novamente.',
      );
    });
  });
}
