import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/collaborator/presentation/collaborator_shell.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../auth/fake_acesso_service.dart';
import '../auth/gate_helpers.dart';

/// P0-1: com Supabase ligado, o AcessoGate escolhia sempre a AppShell de
/// gestor. Um colaborador aprovado via custos, salários e lucros globais.
/// P0-2: mandá-lo para a CollaboratorShell rebentava, porque o ecrã fazia
/// `session.collaboratorId!` sobre a sessão de demonstração (sempre gestor).
void main() {
  group('Shell escolhida pelo perfil aprovado', () {
    testWidgets('gestor recebe a AppShell', (tester) async {
      await montarGate(
        tester,
        FakeAcessoService(
          acesso: const EstadoAcesso(
            membroAtivo: true,
            estado: 'aprovado',
            perfil: 'gestor',
          ),
        ),
      );

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(CollaboratorShell), findsNothing);
    });

    testWidgets('colaborador recebe a CollaboratorShell, não a de gestor', (
      tester,
    ) async {
      await montarGate(
        tester,
        FakeAcessoService(
          acesso: const EstadoAcesso(
            membroAtivo: true,
            estado: 'aprovado',
            perfil: 'colaborador',
          ),
        ),
      );

      expect(find.byType(CollaboratorShell), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('a shell do colaborador monta sem rebentar e sem menu de '
        'custos', (tester) async {
      await montarGate(
        tester,
        FakeAcessoService(
          acesso: const EstadoAcesso(
            membroAtivo: true,
            estado: 'aprovado',
            perfil: 'colaborador',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // As acções do colaborador estão lá...
      expect(find.text('Nova lead'), findsOneWidget);
      expect(find.text('Registar recebimento'), findsOneWidget);
      // ...e nada de gestão financeira global.
      expect(find.textContaining('Custos'), findsNothing);
      expect(find.textContaining('Salários'), findsNothing);
      expect(find.textContaining('Lucro'), findsNothing);
      expect(find.textContaining('Centro de comando'), findsNothing);
    });

    testWidgets('a identidade do colaborador vem da conta autenticada', (
      tester,
    ) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(
          membroAtivo: true,
          estado: 'aprovado',
          perfil: 'colaborador',
        ),
        utilizadorId: 'user-abc',
      );
      await montarGate(tester, fake);

      final shell = tester.widget<CollaboratorShell>(
        find.byType(CollaboratorShell),
      );
      expect(shell.collaboratorId, 'user-abc');
    });
  });

  group('CollaboratorShell sem colaborador associado', () {
    testWidgets('mostra o estado em vez de rebentar com null check', (
      tester,
    ) async {
      // Reproduz o P0-2: sessão de demonstração em modo gestor, cujo
      // collaboratorId é nulo.
      await tester.pumpWidget(
        const ProviderScopeParaTeste(child: CollaboratorShell()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Sem colaborador associado'), findsOneWidget);
    });
  });
}
