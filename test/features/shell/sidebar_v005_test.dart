import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/features/tarefas/presentation/tarefas_page.dart';

import '../dashboard/fixtura.dart';

void main() {
  group('Destinos visíveis', () {
    test('Tarefas e Finanças estão sempre lá', () {
      final destinos = visibleOperationalDestinations(estadoComMovimento());

      expect(destinos, contains(AppDestination.tasks));
      expect(destinos, contains(AppDestination.finances));
    });

    test('Frota só aparece com frota declarada', () {
      expect(
        visibleOperationalDestinations(estadoComMovimento()),
        contains(AppDestination.vehicles),
      );
      expect(
        visibleOperationalDestinations(
          estadoComMovimento().copyWith(hasFleet: false),
        ),
        isNot(contains(AppDestination.vehicles)),
      );
    });

    test('Funcionários continua condicionado aos colaboradores declarados', () {
      expect(
        visibleOperationalDestinations(
          estadoComMovimento().copyWith(declaredCollaboratorCount: 0),
        ),
        isNot(contains(AppDestination.employees)),
      );
    });
  });

  group('Barra lateral', () {
    testWidgets('mostra os rótulos debaixo dos ícones', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
      );

      // Rótulos visíveis, não só tooltips.
      expect(_naBarra('Gestão'), findsOneWidget);
      expect(_naBarra('Máquinas'), findsOneWidget);
      expect(_naBarra('Clientes'), findsOneWidget);
      expect(_naBarra('Reservas'), findsOneWidget);
      expect(_naBarra('Finanças'), findsOneWidget);
      expect(_naBarra('Tarefas'), findsOneWidget);
      expect(_naBarra('Frota'), findsOneWidget);
    });

    testWidgets('o badge de Tarefas mostra a contagem de pendentes', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(tester, container, const AppShell());

      final pendentes = container.read(contagemTarefasPendentesProvider);
      expect(pendentes, greaterThan(0));
      expect(find.text('$pendentes'), findsWidgets);
      // Há uma cobrança em atraso, portanto o badge é o vermelho de urgente.
      expect(container.read(tarefasTemUrgenteProvider), isTrue);
    });

    testWidgets('sem frota declarada o destino desaparece da barra', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento().copyWith(hasFleet: false)),
        const AppShell(),
      );

      expect(_naBarra('Frota'), findsNothing);
      expect(_naBarra('Máquinas'), findsOneWidget);
    });

    testWidgets('tocar em Tarefas abre a página de Tarefas', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
      );

      await tester.tap(_naBarra('Tarefas'));
      await tester.pumpAndSettle();

      expect(find.byType(TarefasPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
    });

    testWidgets('a barra tem 88 dp para caber o rótulo', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
      );

      expect(
        tester.getSize(find.byKey(chaveDaBarraLateral)).width,
        88,
        reason: 'com 72 dp o rótulo não cabia',
      );
    });
  });
}

Finder _naBarra(String rotulo) => find.descendant(
  of: find.byKey(chaveDaBarraLateral),
  matching: find.text(rotulo),
);
