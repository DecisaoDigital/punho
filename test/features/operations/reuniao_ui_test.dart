import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/features/operations/presentation/reunioes_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime(2026, 10, 20, 9, 30);

  Future<ProviderContainer> abrir(WidgetTester t) async {
    final c = ProviderContainer(
      overrides: [relogioProvider.overrideWithValue(() => agora)],
    );
    addTearDown(c.dispose);
    c
        .read(operationsProvider.notifier)
        .addCustomer(
          Customer(
            id: 'c1',
            name: 'Ana Silva',
            phone: '910000000',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const FaixaDeReunioes(),
                Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => abrirReuniao(ctx),
                    child: const Text('abrir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('sem cliente escolhido avisa e não grava', (t) async {
    final c = await abrir(t);
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Marcar reunião'));
    await t.pumpAndSettle();
    expect(find.text('Escolhe o cliente da reunião.'), findsOneWidget);
    expect(c.read(operationsProvider).reunioes, isEmpty);
  });

  testWidgets('marca a reunião e ela aparece na faixa', (t) async {
    final c = await abrir(t);
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cliente *'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ana Silva').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Marcar reunião'));
    await t.pumpAndSettle();

    final r = c.read(operationsProvider).reunioes.single;
    expect(r.customerNameSnapshot, 'Ana Silva');
    expect(r.startsAt, DateTime(2026, 10, 20, 10));
    expect(r.lembreteMinutos, 15);
    expect(find.textContaining('Ana Silva · '), findsOneWidget);
  });
}
