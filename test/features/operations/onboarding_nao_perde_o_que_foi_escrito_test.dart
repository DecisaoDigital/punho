import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Para trás é um passo, e o que foi escrito não se perde.**
///
/// «estava a colocar os dados da empresa e sem querer voltou tudo para trás. só
/// deveria ter ido uma página para trás. os dados nunca foram gravados/enviados
/// para o servidor, estavam todos vazios novamente enquanto deveriam estar
/// preenchidos e permitir alteração» — Cesar, 5/8/2026.
///
/// Eram dois defeitos ao mesmo tempo. O onboarding não tinha `PopScope`: o
/// gesto para trás do Android não recuava um passo, saía do onboarding — no
/// Redmi dele, para o ecrã inicial do telemóvel. E as respostas viviam só nos
/// controladores do `State`: morto o processo (o MIUI mata os que estão em
/// segundo plano), iam com ele.
///
/// O que **não** muda é a regra de sempre: o rascunho é local e nada é gravado
/// nem enviado antes de "Entrar na Punho" — isso continua fixado em
/// `onboarding_fluxo_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerVazio() {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continuar(WidgetTester tester, {int vezes = 1}) async {
    for (var i = 0; i < vezes; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
  }

  /// O gesto/botão "para trás" do Android, tal como o sistema o entrega.
  Future<void> paraTras(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// A app volta ao ecrã. Enquanto está em `paused` o Android não lhe entrega
  /// gestos nenhuns, e o `flutter_test` respeita isso — sem este passo o
  /// "para trás" a seguir não chegava a acontecer.
  Future<void> voltarAoEcra(WidgetTester tester) async {
    // Pelo caminho todo, que é o que o framework exige:
    // `paused` → `hidden` → `inactive` → `resumed`.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('para trás recua um passo, não sai do onboarding', (
    tester,
  ) async {
    await abrir(tester, containerVazio());
    await tester.enterText(find.byType(TextField).first, 'César');
    await continuar(tester, vezes: 2);
    expect(find.text('Qual é o teu cargo?'), findsOneWidget);

    await paraTras(tester);

    expect(find.text('Como se chama a empresa?'), findsOneWidget);
    // Um passo, não dois: o que estava antes continua a ser o passo anterior.
    await paraTras(tester);
    expect(find.text('Como te chamas?'), findsOneWidget);
  });

  testWidgets('para trás não apaga o que já lá estava escrito', (tester) async {
    await abrir(tester, containerVazio());
    await tester.enterText(find.byType(TextField).first, 'César');
    await continuar(tester);
    await tester.enterText(find.byType(TextField).first, 'DepilConcept');
    await continuar(tester);
    await paraTras(tester);
    await paraTras(tester);

    expect(find.text('Como te chamas?'), findsOneWidget);
    expect(find.text('César'), findsOneWidget);
  });

  testWidgets('no primeiro ecrã deixa sair — não prende ninguém', (
    tester,
  ) async {
    // `canPop: true` é o que permite ao Android fazer o que costuma fazer.
    await abrir(tester, containerVazio());

    expect(find.text('Como te chamas?'), findsOneWidget);
    final popScope = tester.widget<PopScope<Object>>(
      find.byType(PopScope<Object>).first,
    );
    expect(popScope.canPop, isTrue);
  });

  testWidgets('o processo morre e o que foi escrito volta', (tester) async {
    // O caso do Cesar: a app vai para segundo plano, o sistema mata-a, e ele
    // reabre-a. Aqui isso é montar uma `OnboardingPage` nova de raiz.
    await abrir(tester, containerVazio());
    await tester.enterText(find.byType(TextField).first, 'César');
    await continuar(tester);
    await tester.enterText(find.byType(TextField).first, 'DepilConcept');
    await continuar(tester);
    expect(find.text('Qual é o teu cargo?'), findsOneWidget);

    // O último aviso que o Android dá antes de terminar o processo.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await abrir(tester, containerVazio());
    await voltarAoEcra(tester);

    expect(
      find.text('Qual é o teu cargo?'),
      findsOneWidget,
      reason: 'volta ao passo onde ia, não ao princípio',
    );
    await paraTras(tester);
    expect(find.text('DepilConcept'), findsOneWidget);
    await paraTras(tester);
    expect(find.text('César'), findsOneWidget);
  });

  testWidgets('o que foi escrito volta para ser alterado, não só para ver', (
    tester,
  ) async {
    // «deveriam estar preenchidos e permitir alteração».
    await abrir(tester, containerVazio());
    await tester.enterText(find.byType(TextField).first, 'Cesar');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await abrir(tester, containerVazio());
    await voltarAoEcra(tester);

    expect(find.text('Cesar'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'César Mendes');
    await tester.pumpAndSettle();

    expect(find.text('César Mendes'), findsOneWidget);
  });

  testWidgets('entrar na app limpa o rascunho', (tester) async {
    // Senão a conta seguinte a fazer onboarding neste telemóvel abria com as
    // respostas de quem cá esteve antes.
    final container = containerVazio();
    await abrir(tester, container);
    await tester.enterText(find.byType(TextField).first, 'César');
    await continuar(tester, vezes: 2);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colaborador').last);
    await tester.pumpAndSettle();
    await continuar(tester);
    await tester.enterText(find.byType(TextField).first, '910000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Começar'));
    await tester.pumpAndSettle();

    expect(container.read(operationsProvider).onboarded, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.contains('onboarding')),
      isEmpty,
      reason: 'o rascunho não pode sobreviver ao fim do onboarding',
    );
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
