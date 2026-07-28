import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/features/empresa/presentation/empresa_page.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../dashboard/fixtura.dart';

/// O destino Empresa e as suas abas (Decisão 2).
///
/// A barra lateral tinha oito destinos e crescia a cada funcionalidade. Três
/// deles — dados da empresa, veículos, finanças — não são sítios de trabalho
/// diário: são o retrato da empresa. Juntá-los liberta a barra para a operação.
void main() {
  Future<void> abrirEmpresa(
    WidgetTester tester, {
    AbaDaEmpresa aba = AbaDaEmpresa.dados,
  }) => montarLandscape(
    tester,
    containerCom(estadoComMovimento()),
    EmpresaPage(abaInicial: aba),
    tamanho: const Size(1280, 900),
  );

  group('Abas', () {
    testWidgets('as seis estão lá, pela ordem certa', (tester) async {
      await abrirEmpresa(tester);

      expect(find.byType(Tab), findsNWidgets(6));
      final rotulos = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((t) => t.text)
          .toList();
      expect(rotulos, [
        'Dados',
        'Regime',
        'Custos fixos',
        'Veículos',
        'Finanças',
        'Estado',
      ]);
    });

    testWidgets('abre nos Dados por omissão', (tester) async {
      await abrirEmpresa(tester);

      expect(find.textContaining('Isto é o que indicou no arranque'), findsOneWidget);
    });

    testWidgets('cada aba mostra o seu conteúdo', (tester) async {
      await abrirEmpresa(tester);

      await tester.tap(find.text('Regime'));
      await tester.pumpAndSettle();
      expect(find.text('Regime actual'), findsOneWidget);

      await tester.tap(find.text('Custos fixos'));
      await tester.pumpAndSettle();
      expect(find.text('Custos fixos mensais'), findsOneWidget);

      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Timeline de obrigações fiscais'),
        findsOneWidget,
      );
    });

    testWidgets('a aba Dados não repete o cabeçalho', (tester) async {
      // Embutida, a página de dados dispensa o seu Scaffold e AppBar: com eles
      // ficavam dois cabeçalhos empilhados a dizer quase o mesmo.
      await abrirEmpresa(tester);

      expect(find.text('Empresa'), findsOneWidget);
      expect(find.text('Dados da empresa'), findsNothing);
    });
  });

  group('Entrar directamente numa aba', () {
    testWidgets('Veículos', (tester) async {
      await abrirEmpresa(tester, aba: AbaDaEmpresa.veiculos);

      expect(find.text('Veículos'), findsWidgets);
      expect(find.text('Adicionar veículo'), findsOneWidget);
    });

    testWidgets('Finanças', (tester) async {
      await abrirEmpresa(tester, aba: AbaDaEmpresa.financas);

      expect(find.textContaining('Isto é o que indicou'), findsNothing);
    });
  });

  group('Saltos antigos continuam a funcionar', () {
    test('os destinos que saíram sabem a que aba pertencem', () {
      // É isto que impede que uma tarefa antiga, ou código que ainda os nomeie,
      // vá dar a um ecrã vazio.
      expect(AppDestination.vehicles.abaDeEmpresa, AbaDaEmpresa.veiculos);
      expect(AppDestination.finances.abaDeEmpresa, AbaDaEmpresa.financas);
      expect(AppDestination.empresa.abaDeEmpresa, isNull);
      expect(AppDestination.machines.abaDeEmpresa, isNull);
    });

    testWidgets('navegar para Veículos abre a Empresa na aba dele', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(
        tester,
        container,
        const AppShell(),
        tamanho: const Size(1280, 900),
      );

      container.read(navigationProvider.notifier).goTo(AppDestination.vehicles);
      await tester.pumpAndSettle();

      expect(find.byType(EmpresaPage), findsOneWidget);
      expect(find.text('Adicionar veículo'), findsOneWidget);
    });
  });

  group('Barra lateral', () {
    testWidgets('Empresa é um dos sete destinos e abre a página', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
        tamanho: const Size(1280, 900),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(chaveDaBarraLateral),
          matching: find.text('Empresa'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmpresaPage), findsOneWidget);
    });
  });
}
