import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/operations/presentation/boas_vindas_screen.dart';
import 'package:punho/features/operations/presentation/mais_dados_screen.dart';

/// Os dois ecrãs de contexto do onboarding, em isolamento.
///
/// O de boas-vindas tem uma exigência própria: **compõe nos dois modos**. Pede
/// ao utilizador para rodar o dispositivo antes de tocar no botão, portanto tem
/// de sobreviver a ser rodado.
void main() {
  Future<void> montar(
    WidgetTester tester,
    Widget ecra, {
    Size tamanho = const Size(420, 900),
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ecra));
    await tester.pumpAndSettle();
  }

  group('MaisDadosScreen', () {
    testWidgets('diz o que vem a seguir e tem um só botão', (tester) async {
      var avancou = 0;
      await montar(tester, MaisDadosScreen(aoAvancar: () => avancou++));

      expect(find.text('Óptimo. Vamos afinar isto.'), findsOneWidget);
      expect(
        find.textContaining('colaboradores, veículos, máquinas e as receitas'),
        findsOneWidget,
      );
      expect(find.text('Continuar →'), findsOneWidget);

      await tester.tap(find.text('Continuar →'));
      expect(avancou, 1);
    });

    testWidgets('sem aoVoltar não mostra o Voltar', (tester) async {
      await montar(tester, MaisDadosScreen(aoAvancar: () {}));

      expect(find.text('Voltar'), findsNothing);
    });
  });

  group('BoasVindasScreen', () {
    testWidgets('recebe o gestor e avisa da rotação', (tester) async {
      var entrou = 0;
      await montar(tester, BoasVindasScreen(aoEntrar: () => entrou++));

      expect(find.text('Bem-vindo à Punho.'), findsOneWidget);
      expect(find.textContaining('em cinco vistas'), findsOneWidget);
      expect(find.textContaining('por apurar'), findsOneWidget);
      expect(find.textContaining('modo horizontal'), findsOneWidget);
      expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
      expect(find.text('Entrar na Punho →'), findsOneWidget);

      await tester.tap(find.text('Entrar na Punho →'));
      expect(entrou, 1);
    });

    testWidgets('compõe em retrato e depois de rodar para paisagem', (
      tester,
    ) async {
      // O utilizador é convidado a rodar *antes* de tocar no botão. Se o ecrã
      // rebentasse ao rodar, o convite era uma armadilha.
      await montar(tester, BoasVindasScreen(aoEntrar: () {}));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(900, 420);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Entrar na Punho →'), findsOneWidget);
      expect(find.textContaining('modo horizontal'), findsOneWidget);
    });

    testWidgets('não fixa orientação nenhuma', (tester) async {
      // O bloqueio de paisagem entra com o completeOnboarding, não aqui: quem
      // ainda não entrou na app tem de poder rodar à vontade. Se este ecrã
      // chamasse setPreferredOrientations, apareceria aqui uma chamada ao
      // canal de sistema.
      final chamadas = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          chamadas.add(chamada.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await montar(tester, BoasVindasScreen(aoEntrar: () {}));

      expect(
        chamadas.where((c) => c.contains('setPreferredOrientations')),
        isEmpty,
      );
    });
  });
}
