import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/orientacao/orientacao_do_contexto.dart';
import 'package:punho/features/collaborator/presentation/collaborator_shell.dart';
import 'package:punho/features/operations/presentation/boas_vindas_screen.dart';
import 'package:punho/features/operations/presentation/mais_dados_screen.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../dashboard/fixtura.dart';

/// Orientação por contexto — Decisão 13.
///
/// **Um só ecrã em toda a app leva landscape: o shell do gestor autenticado.**
///
/// Este ficheiro substituiu um teste que afirmava o contrário ("o arranque pede
/// landscape e só landscape"). Estava a fixar o bug em vez do comportamento: o
/// bloqueio global punha o passo 4 do onboarding deitado num tablet, com o
/// gestor a preencher campos de lado. Um teste verde não garante que o
/// comportamento é o certo — garante que é o que alguém escreveu.
void main() {
  /// Regista as orientações pedidas ao canal de sistema.
  List<List<String>> espiarOrientacoes(WidgetTester tester) {
    final pedidos = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (chamada) async {
        if (chamada.method == 'SystemChrome.setPreferredOrientations') {
          pedidos.add(List<String>.from(chamada.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return pedidos;
  }

  const soPortrait = ['DeviceOrientation.portraitUp'];
  const soLandscape = [
    'DeviceOrientation.landscapeLeft',
    'DeviceOrientation.landscapeRight',
  ];

  Future<void> montar(
    WidgetTester tester,
    Widget ecra, {
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = MaterialApp(home: ecra);
    await tester.pumpWidget(
      container == null
          ? ProviderScope(child: app)
          : UncontrolledProviderScope(container: container, child: app),
    );
    await tester.pumpAndSettle();
  }

  group('Portrait', () {
    testWidgets('o onboarding pede portrait', (tester) async {
      final pedidos = espiarOrientacoes(tester);
      await montar(
        tester,
        const OnboardingPage(),
        container: containerCom(estadoSemMovimento().copyWith(onboarded: false)),
      );

      expect(pedidos, contains(equals(soPortrait)));
      expect(
        pedidos,
        isNot(contains(equals(soLandscape))),
        reason: 'era isto que punha o passo 4 deitado num tablet',
      );
    });

    testWidgets('o ecrã Mais dados pede portrait', (tester) async {
      final pedidos = espiarOrientacoes(tester);
      await montar(tester, MaisDadosScreen(aoAvancar: () {}));

      expect(pedidos, contains(equals(soPortrait)));
    });

    testWidgets('o shell do colaborador pede portrait', (tester) async {
      final pedidos = espiarOrientacoes(tester);
      await montar(
        tester,
        const CollaboratorShell(collaboratorId: 'col-1'),
        container: containerCom(estadoComMovimento()),
      );

      expect(pedidos, contains(equals(soPortrait)));
      expect(pedidos, isNot(contains(equals(soLandscape))));
    });
  });

  group('Landscape', () {
    testWidgets('o shell do gestor é o único que pede landscape', (
      tester,
    ) async {
      final pedidos = espiarOrientacoes(tester);
      await montar(
        tester,
        const AppShell(),
        container: containerCom(estadoComMovimento()),
      );

      expect(pedidos, contains(equals(soLandscape)));
    });
  });

  group('Boas-vindas: portrait até ao botão, landscape depois', () {
    testWidgets('ao abrir pede portrait', (tester) async {
      // Este teste é o inverso do que existia na sprint 1, onde se exigia que o
      // ecrã **não** mexesse na orientação. A ideia era deixar o gestor rodar à
      // mão; o bug mostrou que o problema não era este ecrã, era o bloqueio
      // global — e com ele fora, quem não pede nada fica deitado.
      final pedidos = espiarOrientacoes(tester);
      await montar(tester, BoasVindasScreen(aoEntrar: () {}));

      expect(pedidos, contains(equals(soPortrait)));
      expect(pedidos, isNot(contains(equals(soLandscape))));
    });

    testWidgets('"Entrar na Punho" pede landscape antes de entrar', (
      tester,
    ) async {
      final pedidos = espiarOrientacoes(tester);
      var entrou = false;
      await montar(tester, BoasVindasScreen(aoEntrar: () => entrou = true));
      pedidos.clear();

      await tester.tap(find.text('Entrar na Punho →'));
      await tester.pumpAndSettle();

      expect(pedidos, contains(equals(soLandscape)));
      expect(entrou, isTrue);
    });

    testWidgets('o texto promete que o ecrã roda sozinho', (tester) async {
      // Antes pedia-se ao gestor para rodar o tablet à mão. Agora a app roda,
      // portanto a frase tem de dizer isso — senão fica a pedir uma coisa que
      // já acontece sem ele.
      await montar(tester, BoasVindasScreen(aoEntrar: () {}));

      expect(find.textContaining('vai rodar sozinho'), findsOneWidget);
      expect(find.textContaining('roda o tablet'), findsNothing);
    });
  });

  group('OrientacaoDoContexto', () {
    testWidgets('libertar devolve o controlo ao sistema', (tester) async {
      final pedidos = espiarOrientacoes(tester);

      await OrientacaoDoContexto.libertar();

      expect(pedidos.single, hasLength(4));
    });
  });
}
