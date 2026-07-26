import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/data/acesso_service.dart';

import 'fake_acesso_service.dart';
import 'registo_helpers.dart';

void main() {
  group('Registo com código de convite', () {
    testWidgets('código válido é validado e segue para o registo', (
      tester,
    ) async {
      final fake = FakeAcessoService(validacao: ValidacaoConvite.valido);
      await montarRegisto(tester, fake);
      await preencher(tester, convite: 'ABC1234567');
      await submeter(tester);

      expect(fake.codigosValidados, ['ABC1234567']);
      expect(fake.registos, hasLength(1));
      expect(fake.registos.single['convite'], 'ABC1234567');
      expect(find.textContaining('pendente de aprovação manual'), findsOneWidget);
    });

    testWidgets('código expirado é recusado e não cria conta', (tester) async {
      final fake = FakeAcessoService(validacao: ValidacaoConvite.expirado);
      await montarRegisto(tester, fake);
      await preencher(tester, convite: 'EXPIRADO01');
      await submeter(tester);

      expect(fake.codigosValidados, ['EXPIRADO01']);
      expect(fake.registos, isEmpty);
      expect(find.textContaining('já expirou'), findsOneWidget);
    });

    testWidgets('código já utilizado é recusado e não cria conta', (
      tester,
    ) async {
      final fake = FakeAcessoService(validacao: ValidacaoConvite.usado);
      await montarRegisto(tester, fake);
      await preencher(tester, convite: 'USADO12345');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('já foi utilizado'), findsOneWidget);
    });

    testWidgets('código inexistente é recusado e não cria conta', (
      tester,
    ) async {
      final fake = FakeAcessoService(validacao: ValidacaoConvite.invalido);
      await montarRegisto(tester, fake);
      await preencher(tester, convite: 'NAOEXISTE1');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('inválido'), findsOneWidget);
    });
  });

  group('Mensagens de validação de convite', () {
    test('um código válido não tem mensagem de erro', () {
      expect(ValidacaoConvite.valido.mensagem, isNull);
    });

    test('nenhuma mensagem revela a empresa ou quem convidou', () {
      for (final v in ValidacaoConvite.values) {
        final mensagem = v.mensagem;
        if (mensagem == null) continue;
        expect(mensagem.toLowerCase(), isNot(contains('empresa')));
      }
    });
  });
}
