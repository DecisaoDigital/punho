import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/presentation/registo_screen.dart';

import 'fake_acesso_service.dart';

/// Campos por ordem no ecrã de registo.
const campoNome = 0,
    campoEmail = 1,
    campoPalavraPasse = 2,
    campoEmpresa = 3,
    campoConvite = 4;

Future<void> montarRegisto(WidgetTester tester, FakeAcessoService fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [acessoServiceProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: RegistoScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> preencher(
  WidgetTester tester, {
  String nome = 'Ana Silva',
  String email = 'ana@exemplo.pt',
  String palavraPasse = 'palavra-passe',
  String empresa = 'Lavandaria Central',
  String convite = '',
}) async {
  final campos = find.byType(TextField);
  await tester.enterText(campos.at(campoNome), nome);
  await tester.enterText(campos.at(campoEmail), email);
  await tester.enterText(campos.at(campoPalavraPasse), palavraPasse);
  await tester.enterText(campos.at(campoEmpresa), empresa);
  if (convite.isNotEmpty) {
    await tester.enterText(campos.at(campoConvite), convite);
  }
  await tester.pump();
}

Future<void> submeter(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Pedir acesso'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pedir acesso'));
  await tester.pumpAndSettle();
}
