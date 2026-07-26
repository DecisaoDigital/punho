import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/auth/presentation/acesso_indisponivel_screen.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import 'fake_acesso_service.dart';
import 'gate_helpers.dart';

void main() {
  group('Acesso revogado', () {
    testWidgets('quem era membro e foi revogado perde a AppShell', (
      tester,
    ) async {
      // Revogar no Control é `punho_membros.ativo = false` + estado revogado.
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'revogado'),
      );
      await montarGate(tester, fake);

      expect(find.byType(AcessoIndisponivelScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('antes da revogação, o mesmo utilizador entrava', (
      tester,
    ) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(
          membroAtivo: true,
          estado: 'aprovado',
          perfil: 'colaborador',
        ),
      );
      await montarGate(tester, fake);

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(AcessoIndisponivelScreen), findsNothing);
    });

    testWidgets('o único botão é terminar sessão', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'revogado'),
      );
      await montarGate(tester, fake);

      await tester.tap(find.text('Terminar sessão'));
      await tester.pump();
      expect(fake.sessoesTerminadas, 1);
    });

    test('decidirAcesso: revogado → indisponível', () {
      expect(
        decidirAcesso(const EstadoAcesso(membroAtivo: false, estado: 'revogado')),
        DecisaoAcesso.indisponivel,
      );
    });
  });
}
