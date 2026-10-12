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
import 'package:fist/core/navigation/app_destination.dart';
import 'package:fist/features/equipa/data/equipa_service.dart';
import 'package:fist/features/equipa/domain/funcao_na_equipa.dart';
import 'package:fist/features/equipa/equipa_providers.dart';
import 'package:fist/features/equipa/presentation/acessos_da_equipa_screen.dart';

class _Falso implements EquipaService {
  _Falso(this.membros);
  List<MembroDaEquipa> membros;
  final chamadas = <(String, String, Set<String>)>[];
  bool falha = false;

  @override
  Future<FuncaoNaEquipa> minhaFuncao() async => FuncaoNaEquipa.gerente;
  @override
  Future<List<MembroDaEquipa>> listar() async => membros;
  @override
  Future<void> definir(
    String userId, {
    required String funcao,
    required Set<String> ecrasOcultos,
  }) async {
    if (falha) throw Exception('rede');
    chamadas.add((userId, funcao, ecrasOcultos));
  }
}

MembroDaEquipa _m(
  String id,
  String email, {
  String funcao = 'gerente',
  Set<String> ocultos = const {},
  bool eu = false,
}) => MembroDaEquipa(
  userId: id,
  email: email,
  funcao: FuncaoNaEquipa(funcao: funcao, ecrasOcultos: ocultos),
  eu: eu,
);

void main() {
  group('FuncaoNaEquipa', () {
    final todos = [
      AppDestination.management,
      AppDestination.clients,
      AppDestination.empresa,
      AppDestination.kpis,
    ];

    test('o gerente vê tudo', () {
      expect(FuncaoNaEquipa.gerente.filtrar(todos), todos);
      expect(FuncaoNaEquipa.gerente.nomeParaRegisto, 'gerente');
    });

    test('a administrativa não vê o que lhe esconderam', () {
      const f = FuncaoNaEquipa(
        funcao: 'administrativa',
        ecrasOcultos: {'management', 'kpis'},
      );
      expect(f.filtrar(todos), [
        AppDestination.clients,
        AppDestination.empresa,
      ]);
      expect(f.nomeParaRegisto, 'administrativa');
    });

    test('esconder Empresa esconde também as abas que foram dela', () {
      const f = FuncaoNaEquipa(
        funcao: 'administrativa',
        ecrasOcultos: {'empresa'},
      );
      expect(f.oculta(AppDestination.finances), isTrue);
      expect(f.oculta(AppDestination.vehicles), isTrue);
      expect(f.oculta(AppDestination.clients), isFalse);
    });

    test('lê o que o servidor devolve; valor estranho cai em gerente', () {
      final a = FuncaoNaEquipa.fromJson({
        'funcao': 'administrativa',
        'ecras_ocultos': ['management'],
      });
      expect(a.eAdministrativa, isTrue);
      expect(a.ecrasOcultos, {'management'});
      expect(
        FuncaoNaEquipa.fromJson({'funcao': 'chefe'}).eAdministrativa,
        isFalse,
      );
      expect(FuncaoNaEquipa.fromJson({}).funcao, 'gerente');
    });

    test('só se podem esconder ecrãs da barra', () {
      expect(ecrasEscondiveis, contains(AppDestination.management));
      expect(ecrasEscondiveis, isNot(contains(AppDestination.finances)));
    });
  });

  group('Acessos da equipa', () {
    Future<_Falso> abrir(
      WidgetTester tester,
      List<MembroDaEquipa> membros,
    ) async {
      final falso = _Falso(membros);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [equipaServiceProvider.overrideWithValue(falso)],
          child: const MaterialApp(home: AcessosDaEquipaScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return falso;
    }

    testWidgets('sem mais ninguém na gestão explica como aparecer', (
      tester,
    ) async {
      await abrir(tester, [_m('g', 'eu@x.pt', eu: true)]);
      expect(find.textContaining('Ainda não há mais ninguém'), findsOneWidget);
    });

    testWidgets('fazer de alguém a administrativa grava logo', (tester) async {
      final f = await abrir(tester, [
        _m('g', 'eu@x.pt', eu: true),
        _m('a', 'ana@x.pt'),
      ]);
      expect(find.text('ana@x.pt'), findsOneWidget);
      expect(
        find.text('eu@x.pt'),
        findsNothing,
      ); // ninguém se gere a si próprio
      expect(
        find.text('Painel'),
        findsNothing,
      ); // sem ser administrativa não há ecrãs a escolher
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(f.chamadas.single.$1, 'a');
      expect(f.chamadas.single.$2, 'administrativa');
      expect(f.chamadas.single.$3, <String>{});
      expect(find.text('Painel'), findsOneWidget);
    });

    testWidgets('desmarcar o Painel esconde-o à administrativa', (
      tester,
    ) async {
      final f = await abrir(tester, [
        _m('g', 'eu@x.pt', eu: true),
        _m('a', 'ana@x.pt', funcao: 'administrativa'),
      ]);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Painel'));
      await tester.pumpAndSettle();
      expect(f.chamadas.single.$1, 'a');
      expect(f.chamadas.single.$2, 'administrativa');
      expect(f.chamadas.single.$3, <String>{'management'});
      // voltar a marcar devolve-lho
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Painel'));
      await tester.pumpAndSettle();
      expect(f.chamadas.last.$3, <String>{});
    });

    testWidgets('se a gravação falhar, volta atrás e diz', (tester) async {
      final f = await abrir(tester, [
        _m('g', 'eu@x.pt', eu: true),
        _m('a', 'ana@x.pt', funcao: 'administrativa'),
      ]);
      f.falha = true;
      await tester.tap(find.widgetWithText(CheckboxListTile, 'KPIs (todos)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não consegui gravar'), findsOneWidget);
      final caixa = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'KPIs (todos)'),
      );
      expect(caixa.value, isTrue); // continua visível: nada mudou
    });

    testWidgets('tirar a função de administrativa limpa os ecrãs escondidos', (
      tester,
    ) async {
      final f = await abrir(tester, [
        _m('g', 'eu@x.pt', eu: true),
        _m('a', 'ana@x.pt', funcao: 'administrativa', ocultos: {'management'}),
      ]);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(f.chamadas.single.$1, 'a');
      expect(f.chamadas.single.$2, 'gerente');
      expect(f.chamadas.single.$3, <String>{});
    });
  });
}
