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
    test('sete destinos, sempre os mesmos, sempre na mesma ordem', () {
      // Decisão 2. Estes testes exigiam o contrário — que Frota e Funcionários
      // aparecessem e desaparecessem conforme os dados. Reescritos, não
      // ajustados: o comportamento certo é agora o oposto.
      expect(visibleOperationalDestinations(estadoComMovimento()), const [
        AppDestination.management,
        AppDestination.machines,
        AppDestination.bookings,
        AppDestination.clients,
        AppDestination.employees,
        AppDestination.empresa,
        AppDestination.tasks,
      ]);
    });

    test('não muda com o estado dos dados', () {
      final semNada = estadoComMovimento().copyWith(
        hasFleet: false,
        declaredCollaboratorCount: 0,
      );

      expect(
        visibleOperationalDestinations(semNada),
        visibleOperationalDestinations(estadoComMovimento()),
      );
    });

    test('Veículos e Finanças deixaram de ser destinos da barra', () {
      final destinos = visibleOperationalDestinations(estadoComMovimento());

      expect(destinos, isNot(contains(AppDestination.vehicles)));
      expect(destinos, isNot(contains(AppDestination.finances)));
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
      expect(_naBarra('Painel'), findsOneWidget);
      expect(_naBarra('Máquinas'), findsOneWidget);
      expect(_naBarra('Reservas'), findsOneWidget);
      expect(_naBarra('Clientes'), findsOneWidget);
      expect(_naBarra('Colaboradores'), findsOneWidget);
      expect(_naBarra('Empresa'), findsOneWidget);
      expect(_naBarra('Tarefas'), findsOneWidget);
      expect(_naBarra('v 0.0.13'), findsOneWidget);
      // Os nomes antigos saíram: "Gestão" dizia o que a app faz, não o que o
      // ecrã mostra, e "Frota" era jargão de quem já sabe.
      expect(_naBarra('Gestão'), findsNothing);
      expect(_naBarra('Frota'), findsNothing);
      expect(_naBarra('Funcionários'), findsNothing);
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
