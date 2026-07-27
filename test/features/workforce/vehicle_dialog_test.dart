import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// O diálogo dos veículos tinha os mesmos quatro defeitos do dos colaboradores,
/// apanhados pelo Cesar no smoke da v0.0.4.
void main() {
  Future<void> abrirVeiculos(WidgetTester tester, container) async {
    await montarLandscape(tester, container, const VehiclesPage());
    await tester.tap(find.text('Adicionar veículo').first);
    await tester.pumpAndSettle();
  }

  testWidgets('o título diz "Adicionar", não "Novo"', (tester) async {
    // "Novo veículo" lia-se como "veículo criado" — o mesmo mal-entendido dos
    // colaboradores.
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    expect(find.text('Adicionar veículo'), findsWidgets);
    expect(find.text('Novo veículo'), findsNothing);
  });

  testWidgets('guardar sem matrícula avisa e não grava', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Indica a matrícula do veículo.'), findsOneWidget);
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      isNot(contains('')),
    );
    // O diálogo fica aberto para se corrigir, em vez de fechar e perder tudo.
    expect(find.text('Adicionar veículo'), findsWidgets);
  });

  testWidgets('com matrícula guarda e fecha', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.enterText(find.byType(TextField).first, 'ZZ-99-XX');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // O controller relê do repositório depois de gravar, por isso confirma-se
    // pela presença da matrícula e não pela contagem.
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      contains('ZZ-99-XX'),
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a matrícula ganha foco e escreve-se em maiúsculas', (
    tester,
  ) async {
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    final campo = tester.widget<TextField>(find.byType(TextField).first);
    expect(campo.autofocus, isTrue);
    expect(campo.textCapitalization, TextCapitalization.characters);
  });

  testWidgets('não fecha ao tocar fora', (tester) async {
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('cancelar fecha sem gravar', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      isNot(contains('AA-11-BB')),
    );
  });
}
