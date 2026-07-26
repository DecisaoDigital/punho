import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/presentation/auth_gate.dart';

import 'fake_acesso_service.dart';

/// Monta só o [AcessoGate] — a decisão pós-login — com o serviço substituído.
/// O ecrã de login não entra aqui: esse depende de `Supabase.instance`.
Future<void> montarGate(WidgetTester tester, FakeAcessoService fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [acessoServiceProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: AcessoGate()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Envolve um ecrã em `ProviderScope` + `MaterialApp` sem substituir nada.
class ProviderScopeParaTeste extends StatelessWidget {
  const ProviderScopeParaTeste({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: MaterialApp(home: child));
}
