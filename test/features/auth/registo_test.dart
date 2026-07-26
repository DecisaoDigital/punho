import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_acesso_service.dart';
import 'registo_helpers.dart';

void main() {
  group('Registo livre', () {
    testWidgets('cria a conta e deixa o acesso pendente de aprovação', (
      tester,
    ) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester);
      await submeter(tester);

      expect(fake.registos, hasLength(1));
      expect(fake.registos.single['email'], 'ana@exemplo.pt');
      expect(fake.registos.single['nome'], 'Ana Silva');
      expect(fake.registos.single['empresa'], 'Lavandaria Central');
      // Sem código, não se chega sequer a validar convite.
      expect(fake.registos.single['convite'], isNull);
      expect(fake.codigosValidados, isEmpty);

      expect(find.textContaining('pendente de aprovação manual'), findsOneWidget);
    });

    testWidgets('o cargo pretendido vai no pedido', (tester) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gestor').last);
      await tester.pumpAndSettle();

      await submeter(tester);
      expect(fake.registos.single['perfil'], 'gestor');
    });

    testWidgets('por omissão pede colaborador, não gestor', (tester) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester);
      await submeter(tester);
      expect(fake.registos.single['perfil'], 'colaborador');
    });
  });

  group('Validação local', () {
    testWidgets('palavra-passe com menos de 8 caracteres não regista', (
      tester,
    ) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester, palavraPasse: 'curta');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('pelo menos 8 caracteres'), findsOneWidget);
    });

    testWidgets('empresa vazia não regista', (tester) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester, empresa: '');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('nome da empresa'), findsOneWidget);
    });

    testWidgets('email inválido não regista', (tester) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester, email: 'ana-arroba-exemplo');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('email válido'), findsOneWidget);
    });

    testWidgets('nome vazio não regista', (tester) async {
      final fake = FakeAcessoService();
      await montarRegisto(tester, fake);
      await preencher(tester, nome: '');
      await submeter(tester);

      expect(fake.registos, isEmpty);
      expect(find.textContaining('o teu nome'), findsOneWidget);
    });
  });
}
