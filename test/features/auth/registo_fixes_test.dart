import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/auth/auth_rules.dart';
import 'package:punho/core/updates/update_service.dart';
import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:punho/features/auth/presentation/registo_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_acesso_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:punho/features/auth/acesso_providers.dart';

/// Os três buracos que prendiam quem tentava criar conta.
void main() {
  group('Mensagens de erro específicas', () {
    test('email já registado diz o que fazer a seguir', () {
      const esperada = 'Este email já tem conta. Faz início de sessão.';
      for (final codigo in [
        'user_already_exists',
        'email_exists',
        'identity_already_exists',
        codigoEmailJaRegistado,
      ]) {
        expect(AuthRules.mensagemSegura(codigo), esperada, reason: codigo);
      }
    });

    test('os outros códigos têm cada um a sua mensagem', () {
      expect(
        AuthRules.mensagemSegura('weak_password'),
        'Palavra-passe demasiado fraca. Usa pelo menos 8 caracteres.',
      );
      expect(AuthRules.mensagemSegura('validation_failed'), 'Email inválido.');
      expect(
        AuthRules.mensagemSegura('over_email_send_rate_limit'),
        'Muitas tentativas seguidas. Espera um minuto.',
      );
      expect(
        AuthRules.mensagemSegura('email_not_confirmed'),
        'Confirma o email antes de iniciares sessão.',
      );
    });

    test('código desconhecido ou nulo cai no genérico', () {
      const generica =
          'Não foi possível concluir. Confirma a ligação e tenta novamente.';
      expect(AuthRules.mensagemSegura(null), generica);
      expect(AuthRules.mensagemSegura('coisa_que_nao_conhecemos'), generica);
    });

    test('nunca devolve texto técnico do fornecedor', () {
      // A regra que já existia e não se perde: o utilizador nunca vê o código.
      for (final codigo in [
        'invalid_credentials',
        'weak_password',
        'user_already_exists',
        null,
      ]) {
        expect(AuthRules.mensagemSegura(codigo), isNot(contains('_')));
      }
    });
  });

  group('emailJaRegistado', () {
    // O Supabase, com confirmação de email ligada, **não devolve erro** para um
    // email que já existe: devolve sucesso com identidades vazias, para não
    // permitir enumerar contas. Era isto que fazia o utilizador ver "Conta
    // criada" e ficar à espera de um email que nunca chegava.
    User utilizador({required List<UserIdentity>? identidades}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
      identities: identidades,
    );

    test('identidades vazias significam email já registado', () {
      final resposta = AuthResponse(user: utilizador(identidades: []));
      expect(emailJaRegistado(resposta), isTrue);
    });

    test('conta nova traz pelo menos uma identidade', () {
      final resposta = AuthResponse(
        user: utilizador(
          identidades: [
            UserIdentity(
              id: 'i1',
              identityId: 'id1',
              userId: 'u1',
              identityData: const {},
              provider: 'email',
              createdAt: DateTime(2026).toIso8601String(),
              lastSignInAt: DateTime(2026).toIso8601String(),
              updatedAt: DateTime(2026).toIso8601String(),
            ),
          ],
        ),
      );
      expect(emailJaRegistado(resposta), isFalse);
    });

    test('sem utilizador não se afirma nada', () {
      expect(emailJaRegistado(AuthResponse()), isFalse);
      expect(
        emailJaRegistado(AuthResponse(user: utilizador(identidades: null))),
        isFalse,
      );
    });
  });

  group('Ecrã de registo depois do sucesso', () {
    Future<void> preencherEsubmeter(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'César Mendes',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'novo@exemplo.pt',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Palavra-passe'),
        'palavra-longa',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Empresa / organização'),
        'Decisão Digital',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Pedir acesso'));
      await tester.pumpAndSettle();
    }

    testWidgets('o formulário desaparece e fica um caminho só', (tester) async {
      var voltou = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acessoServiceProvider.overrideWithValue(FakeAcessoService()),
          ],
          child: MaterialApp(
            home: RegistoScreen(aoVoltarParaLogin: () => voltou++),
          ),
        ),
      );
      await preencherEsubmeter(tester);

      // Antes ficava tudo preenchido com o botão a dizer "Pedir acesso" — quem
      // acabara de pedir não sabia se devia carregar outra vez.
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Pedir acesso'), findsNothing);

      expect(find.text('Conta criada'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.textContaining('pendente de aprovação'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Voltar ao início de sessão'),
      );
      expect(voltou, 1);
    });

    testWidgets('com erro o formulário fica, com o que estava escrito', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acessoServiceProvider.overrideWithValue(
              FakeAcessoService(
                erroAoRegistar: const AuthException(
                  'ja existe',
                  code: 'user_already_exists',
                ),
              ),
            ),
          ],
          child: MaterialApp(home: const RegistoScreen()),
        ),
      );
      await preencherEsubmeter(tester);

      expect(
        find.text('Este email já tem conta. Faz início de sessão.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Email'))
            .controller!
            .text,
        'novo@exemplo.pt',
        reason: 'perder o que estava escrito obrigava a repetir tudo',
      );
    });
  });

  group('PunhoUpdateService deixa rasto ao falhar', () {
    test('erro na chamada devolve null mas escreve nos logs', () async {
      final linhas = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (mensagem, {wrapWidth}) => linhas.add(mensagem ?? '');
      addTearDown(() => debugPrint = originalDebugPrint);

      final servico = PunhoUpdateService.comInvocador(
        (corpo, headers) async => throw StateError('rede em baixo'),
      );

      // A UX mantém-se: sem update em vez de erro na cara do utilizador.
      expect(await servico.check(), isNull);
      // O que muda é haver rasto — sem isto, a app do Cesar falhou em cada
      // arranque durante duas versões sem ninguém saber.
      final registo = linhas.firstWhere(
        (l) => l.contains('[PunhoUpdate] check falhou'),
        orElse: () => '',
      );
      expect(registo, isNotEmpty);
      // O tipo da excepção tem de estar na linha: é o que permite distinguir
      // "sem rede" de "sem defines" ao ler o logcat. Não se fixa **qual** o
      // tipo — neste ambiente o `PackageInfo` falha primeiro, e o teste não
      // deve depender de qual das falhas chega em primeiro lugar.
      expect(
        registo,
        matches(RegExp(r'falhou: \w+Exception|falhou: \w+Error')),
      );
    });
  });
}
