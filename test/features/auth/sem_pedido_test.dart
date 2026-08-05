import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/auth/presentation/auth_gate.dart';
import 'package:punho/features/auth/presentation/pedir_acesso_screen.dart';

import 'fake_acesso_service.dart';

/// **Não haver pedido não é ter um pedido pendente.**
///
/// A 5 de Agosto de 2026 apagou-se a empresa no servidor para um teste. A conta
/// do gestor ficou sem adesão e sem pedido, e a app disse-lhe "Pedido em
/// análise" — enquanto o Control não tinha linha nenhuma para aprovar. Os dois
/// lados concordavam em silêncio numa coisa que era falsa, e não havia saída:
/// o pedido só nascia no trigger do registo.
///
/// A causa era um `coalesce(..., 'pendente')` em `punho_meu_acesso` e o mesmo
/// valor por omissão no cliente. Estes testes guardam a distinção.
void main() {
  group('decidirAcesso', () {
    test(
      'sem pedido nenhum manda pedir acesso — não diz que está em análise',
      () {
        const acesso = EstadoAcesso(membroAtivo: false);

        expect(acesso.estado, isNull);
        expect(decidirAcesso(acesso), DecisaoAcesso.semPedido);
      },
    );

    test('com pedido pendente continua a ser análise', () {
      const acesso = EstadoAcesso(membroAtivo: false, estado: 'pendente');

      expect(decidirAcesso(acesso), DecisaoAcesso.pendente);
    });

    test('recusado e revogado não voltam a pedir — a decisão está tomada', () {
      // Mandar pedir outra vez seria dar a volta a uma decisão já tomada.
      expect(
        decidirAcesso(
          const EstadoAcesso(membroAtivo: false, estado: 'recusado'),
        ),
        DecisaoAcesso.indisponivel,
      );
      expect(
        decidirAcesso(
          const EstadoAcesso(membroAtivo: false, estado: 'revogado'),
        ),
        DecisaoAcesso.indisponivel,
      );
    });

    test('adesão activa ganha a tudo, mesmo sem pedido', () {
      // As contas anteriores a este modelo não têm pedido nenhum e não podem
      // ficar trancadas de fora por causa disso.
      const acesso = EstadoAcesso(membroAtivo: true, perfil: 'gestor');

      expect(decidirAcesso(acesso), DecisaoAcesso.app);
    });
  });

  group('EstadoAcesso.fromJson', () {
    test('estado ausente fica nulo — não se inventa "pendente"', () {
      final acesso = EstadoAcesso.fromJson({'membro_ativo': false});

      expect(acesso.estado, isNull);
      expect(decidirAcesso(acesso), DecisaoAcesso.semPedido);
    });

    test('estado presente lê-se tal como vem', () {
      final acesso = EstadoAcesso.fromJson({
        'membro_ativo': false,
        'estado': 'pendente',
      });

      expect(acesso.estado, 'pendente');
    });
  });

  group('o porteiro', () {
    Future<FakeAcessoService> montar(
      WidgetTester tester,
      EstadoAcesso a,
    ) async {
      final servico = FakeAcessoService(acesso: a);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [acessoServiceProvider.overrideWithValue(servico)],
          child: const MaterialApp(home: AcessoGate()),
        ),
      );
      await tester.pumpAndSettle();
      return servico;
    }

    testWidgets('sem pedido abre o ecrã de pedir, não o de análise', (
      tester,
    ) async {
      await montar(tester, const EstadoAcesso(membroAtivo: false));

      expect(find.byType(PedirAcessoScreen), findsOneWidget);
      expect(find.text('Falta pedir acesso'), findsOneWidget);
      expect(find.text('Pedido em análise'), findsNothing);
    });

    testWidgets('o pedido chega ao servidor e o ecrã seguinte é a análise', (
      tester,
    ) async {
      final servico = await montar(
        tester,
        const EstadoAcesso(membroAtivo: false),
      );

      await tester.enterText(find.byType(TextField).first, 'Rui Salgueiro');
      await tester.enterText(
        find.byType(TextField).last,
        'Lavandaria Mare Alta',
      );
      await tester.tap(find.text('Pedir acesso'));
      await tester.pumpAndSettle();

      expect(servico.pedidosDeAcesso, hasLength(1));
      expect(servico.pedidosDeAcesso.first['nome'], 'Rui Salgueiro');
      expect(servico.pedidosDeAcesso.first['empresa'], 'Lavandaria Mare Alta');
      // Gestor por omissão: quem está a montar a empresa é quem a gere.
      expect(servico.pedidosDeAcesso.first['perfil'], 'gestor');
      // E o porteiro volta a perguntar ao servidor em vez de assumir.
      expect(find.text('Pedido em análise'), findsOneWidget);
    });

    testWidgets('o pedido leva o terminal de onde partiu', (tester) async {
      // Sem plugins nativos não há machine_id neste ambiente — e é isso mesmo
      // que se guarda: o campo existe e viaja, e quando não se resolve vai
      // vazio em vez de inventado. A chave `(machine_id, app)` é a mesma que o
      // WashInvoice usa para identificar um terminal.
      final servico = await montar(
        tester,
        const EstadoAcesso(membroAtivo: false),
      );

      await tester.enterText(find.byType(TextField).first, 'Rui Salgueiro');
      await tester.enterText(find.byType(TextField).last, 'Mare Alta');
      await tester.tap(find.text('Pedir acesso'));
      await tester.pumpAndSettle();

      expect(servico.pedidosDeAcesso.first.containsKey('machine_id'), isTrue);
    });

    testWidgets('sem nome não se envia nada', (tester) async {
      final servico = await montar(
        tester,
        const EstadoAcesso(membroAtivo: false),
      );

      await tester.tap(find.text('Pedir acesso'));
      await tester.pumpAndSettle();

      expect(servico.pedidosDeAcesso, isEmpty);
      expect(find.text('Indica o teu nome.'), findsOneWidget);
    });
  });
}
