// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/features/operations/presentation/leads_quentes_ui.dart';

void main() {
  Future<ProviderContainer> abrir(WidgetTester tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(operationsProvider.notifier)
        .addLead(
          Lead(
            id: 'l1',
            name: 'Ana',
            phone: '912345678',
            status: LeadStatus.newLead,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            negocio: 'Estética Ana',
            localidade: 'Porto',
            via: LeadVia.bot,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LeadsQuentesSecao()),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('mostra a lead quente com zona, ficha e espera', (tester) async {
    await abrir(tester);
    expect(find.textContaining('1 por validar'), findsOneWidget);
    expect(find.text('Ana · Estética Ana'), findsOneWidget);
    expect(find.textContaining('Porto'), findsOneWidget);
    expect(find.textContaining('ficha 4/6'), findsOneWidget);
    expect(find.textContaining('há 3 h'), findsOneWidget);
  });

  testWidgets('validar tira-a da caixa com um toque', (tester) async {
    final c = await abrir(tester);
    await tester.tap(find.text('Validar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('por validar'), findsNothing);
    expect(c.read(operationsProvider).leads.single.validadaPor, 'gestor');
  });

  testWidgets('perdida pede o motivo e guarda-o', (tester) async {
    final c = await abrir(tester);
    await tester.tap(find.text('Perdida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preço'));
    await tester.pumpAndSettle();
    expect(
      c.read(operationsProvider).leads.single.motivoDePerda,
      MotivoDePerda.preco,
    );
  });

  group('pedido da lead', () {
    Lead lead(
      LeadTipo? tipo, {
      int? dias,
      DateTime? quando,
      String categoria = 'Depilação a laser',
    }) => Lead(
      id: 'p',
      name: 'X',
      phone: '9',
      status: LeadStatus.newLead,
      createdAt: DateTime(2030),
      tipo: tipo,
      categoria: categoria,
      periodoDias: dias,
      horarioPedido: quando,
    );
    Machine maquina(List<int> dias) => Machine(
      id: 'm',
      name: 'A',
      reference: 'A',
      category: 'c',
      status: MachineStatus.available,
      tarifas: [for (final d in dias) Tarifa(dias: d, cents: 1000 * d)],
    );
    final quando = DateTime(2030, 3, 12, 9, 30);

    test('aluguer dentro da tabela mostra a entrega e não pede o gerente', () {
      final t = pedidoDaLead(lead(LeadTipo.aluguer, dias: 3, quando: quando), [
        maquina([1, 3, 30]),
      ]);
      expect(
        t,
        'Depilação a laser · Aluguer de máquinas · 3 dias · entrega 12/03 às 09:30',
      );
    });

    test('aluguer de 15 dias fora da tabela vai ao gerente, sem escala', () {
      final l = lead(LeadTipo.aluguer, dias: 15, quando: quando);
      final m = [
        maquina([1, 3, 30]),
      ];
      expect(periodoForaDaTabela(l, m), isTrue);
      final t = pedidoDaLead(l, m)!;
      expect(t, contains('fora da tabela de preços'));
      expect(t, contains('ver com o gerente'));
      expect(t, isNot(contains('entrega')));
    });

    test('sem tabelas nas máquinas não se diz que está fora', () {
      final l = lead(LeadTipo.aluguer, dias: 15);
      expect(periodoForaDaTabela(l, [maquina([])]), isFalse);
    });

    test('venda é do gerente e não mostra horário', () {
      final t = pedidoDaLead(lead(LeadTipo.venda, quando: quando), const [])!;
      expect(t, 'Depilação a laser · Venda de máquinas · ver com o gerente');
    });

    test('serviço mostra o dia pedido; lead antiga não mostra nada', () {
      expect(
        pedidoDaLead(lead(LeadTipo.servico, quando: quando), const []),
        'Depilação a laser · Serviço · pede 12/03 às 09:30',
      );
      expect(pedidoDaLead(lead(null, categoria: ''), const []), isNull);
      expect(
        pedidoDaLead(lead(LeadTipo.servico, categoria: ''), const []),
        startsWith('sem categoria'),
      );
    });
  });
}
