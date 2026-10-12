// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/features/auth/domain/estado_acesso.dart';
import 'package:fist/features/auth/presentation/acesso_indisponivel_screen.dart';
import 'package:fist/features/shell/presentation/app_shell.dart';

import 'fake_acesso_service.dart';
import 'gate_helpers.dart';

void main() {
  group('Pedido recusado', () {
    testWidgets('mostra "Acesso indisponível" e não a AppShell', (
      tester,
    ) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'recusado'),
      );
      await montarGate(tester, fake);

      expect(find.byType(AcessoIndisponivelScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('Acesso indisponível'), findsOneWidget);
    });

    testWidgets('não expõe o motivo interno da recusa', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'recusado'),
      );
      await montarGate(tester, fake);

      expect(find.textContaining('recusad'), findsNothing);
      expect(find.textContaining('revogad'), findsNothing);
    });

    testWidgets('o único botão é terminar sessão', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'recusado'),
      );
      await montarGate(tester, fake);

      await tester.tap(find.text('Terminar sessão'));
      await tester.pump();
      expect(fake.sessoesTerminadas, 1);
    });

    test('decidirAcesso: recusado → indisponível', () {
      expect(
        decidirAcesso(
          const EstadoAcesso(membroAtivo: false, estado: 'recusado'),
        ),
        DecisaoAcesso.indisponivel,
      );
    });
  });
}
