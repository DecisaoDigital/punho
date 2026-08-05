import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/auth/presentation/pedido_em_analise_screen.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import 'fake_acesso_service.dart';
import 'gate_helpers.dart';

void main() {
  group('Pedido pendente', () {
    testWidgets('não abre a AppShell', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
      );
      await montarGate(tester, fake);

      expect(find.byType(PedidoEmAnaliseScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('Pedido em análise'), findsOneWidget);
    });

    testWidgets('o único botão é terminar sessão', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
      );
      await montarGate(tester, fake);

      await tester.tap(find.text('Terminar sessão'));
      await tester.pump();
      expect(fake.sessoesTerminadas, 1);
    });

    testWidgets('pedido aprovado mas ainda sem adesão continua à espera', (
      tester,
    ) async {
      // O Control aprova o pedido e só depois cria a linha em punho_membros.
      // Entre as duas coisas a app não pode abrir.
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'aprovado'),
      );
      await montarGate(tester, fake);

      expect(find.byType(PedidoEmAnaliseScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('erro a consultar o acesso não abre a app', (tester) async {
      final fake = FakeAcessoService(erroAoLerAcesso: Exception('rede'));
      await montarGate(tester, fake);

      expect(find.byType(AppShell), findsNothing);
      expect(find.textContaining('Não foi possível confirmar'), findsOneWidget);
    });
  });

  group('decidirAcesso', () {
    test('sem adesão e pendente → espera', () {
      expect(
        decidirAcesso(
          const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
        ),
        DecisaoAcesso.pendente,
      );
    });

    test('com adesão activa → app, seja qual for o estado do pedido', () {
      // Contas anteriores a este modelo não têm pedido nenhum; a adesão manda.
      for (final estado in ['pendente', 'aprovado', 'recusado', 'revogado']) {
        expect(
          decidirAcesso(EstadoAcesso(membroAtivo: true, estado: estado)),
          DecisaoAcesso.app,
          reason: estado,
        );
      }
    });

    test('estado desconhecido não abre a app', () {
      expect(
        decidirAcesso(const EstadoAcesso(membroAtivo: false, estado: 'xpto')),
        DecisaoAcesso.pendente,
      );
    });
  });
}
