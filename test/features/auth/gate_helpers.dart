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
import 'package:fist/features/auth/acesso_providers.dart';
import 'package:fist/features/auth/presentation/auth_gate.dart';

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
