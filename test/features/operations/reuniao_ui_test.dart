// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

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
