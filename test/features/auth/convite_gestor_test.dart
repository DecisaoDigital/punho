import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:punho/features/gestao/presentation/convites_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_acesso_service.dart';

/// Erro que a RPC `punho_criar_convite()` devolve a quem não é gestor
/// aprovado da empresa. É o servidor que decide — a UI só o mostra.
PostgrestException get _semPermissao => PostgrestException(
  message: 'Só um gestor aprovado pode criar convites.',
  code: 'P0001',
);

Future<void> _montar(WidgetTester tester, FakeAcessoService fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [acessoServiceProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: ConvitesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _criarConvite(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField).first, email);
  await tester.pump();
  await tester.ensureVisible(find.text('Criar convite'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Criar convite'));
  await tester.pumpAndSettle();
}

void main() {
  group('Criar convite', () {
    testWidgets('gestor aprovado cria e vê o código para partilhar', (
      tester,
    ) async {
      final fake = FakeAcessoService();
      await _montar(tester, fake);
      await _criarConvite(tester, 'novo@exemplo.pt');

      expect(fake.convitesCriados, hasLength(1));
      expect(fake.convitesCriados.single['email'], 'novo@exemplo.pt');
      // Cargo por omissão: colaborador, não gestor.
      expect(fake.convitesCriados.single['perfil'], 'colaborador');

      expect(find.text('Convite criado'), findsOneWidget);
      expect(find.text('ABC1234567'), findsOneWidget);
      expect(find.textContaining('aprovação manual'), findsOneWidget);
    });

    testWidgets('colaborador é recusado pelo servidor e vê o motivo', (
      tester,
    ) async {
      final fake = FakeAcessoService(erroAoCriarConvite: _semPermissao);
      await _montar(tester, fake);
      await _criarConvite(tester, 'novo@exemplo.pt');

      expect(fake.convitesCriados, isEmpty);
      expect(find.text('Convite criado'), findsNothing);
      expect(
        find.text('Só um gestor aprovado pode criar convites.'),
        findsOneWidget,
      );
    });

    testWidgets('conta de outra empresa sem adesão activa é recusada', (
      tester,
    ) async {
      final fake = FakeAcessoService(
        erroAoCriarConvite: PostgrestException(
          message: 'Conta sem empresa activa.',
          code: 'P0001',
        ),
      );
      await _montar(tester, fake);
      await _criarConvite(tester, 'novo@exemplo.pt');

      expect(fake.convitesCriados, isEmpty);
      expect(find.text('Conta sem empresa activa.'), findsOneWidget);
    });

    testWidgets('email inválido nem chega ao servidor', (tester) async {
      final fake = FakeAcessoService();
      await _montar(tester, fake);
      await _criarConvite(tester, 'isto-nao-e-email');

      expect(fake.convitesCriados, isEmpty);
      expect(find.textContaining('email válido'), findsOneWidget);
    });
  });

  group('Lista de convites', () {
    testWidgets('mostra estado e esconde o código dos já usados', (
      tester,
    ) async {
      final agora = DateTime.now();
      final fake = FakeAcessoService(
        convites: [
          Convite(
            codigo: 'PORUSAR001',
            email: 'a@exemplo.pt',
            perfil: 'colaborador',
            expiraEm: agora.add(const Duration(days: 10)),
          ),
          Convite(
            codigo: 'JAUSADO002',
            email: 'b@exemplo.pt',
            perfil: 'gestor',
            expiraEm: agora.add(const Duration(days: 10)),
            usado: true,
          ),
          Convite(
            codigo: 'EXPIRADO03',
            email: 'c@exemplo.pt',
            perfil: 'colaborador',
            expiraEm: agora.subtract(const Duration(days: 1)),
          ),
        ],
      );
      await _montar(tester, fake);

      expect(find.textContaining('Por utilizar'), findsOneWidget);
      expect(find.textContaining('Utilizado'), findsWidgets);
      expect(find.textContaining('Expirado'), findsOneWidget);

      // Só o convite ainda utilizável mostra o código.
      expect(find.text('PORUSAR001'), findsOneWidget);
      expect(find.text('JAUSADO002'), findsNothing);
      expect(find.text('EXPIRADO03'), findsNothing);
    });

    testWidgets('sem convites mostra mensagem própria', (tester) async {
      await _montar(tester, FakeAcessoService());
      expect(find.text('Ainda não emitiu convites.'), findsOneWidget);
    });
  });

  group('Convite (modelo)', () {
    final agora = DateTime.parse('2026-07-26T12:00:00Z');
    Convite comExpiracao(DateTime quando, {bool usado = false}) => Convite(
      codigo: 'X',
      email: 'a@b.pt',
      perfil: 'colaborador',
      expiraEm: quando,
      usado: usado,
    );

    test('expira exactamente no instante marcado', () {
      expect(comExpiracao(agora).expiradoEm(agora), isTrue);
      expect(
        comExpiracao(agora.add(const Duration(seconds: 1))).expiradoEm(agora),
        isFalse,
      );
    });

    test('usado não está disponível mesmo dentro da validade', () {
      final c = comExpiracao(agora.add(const Duration(days: 5)), usado: true);
      expect(c.disponivelEm(agora), isFalse);
    });
  });
}
