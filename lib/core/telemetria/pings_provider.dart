// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../licenca/machine_id.dart';
import '../operations/operations_controller.dart';
import 'pings.dart';

final pingsServiceProvider = Provider<FistPings>(
  (ref) => FistPings(Supabase.instance.client),
);

/// Mantém a app a dizer que está viva: um ping no arranque e outro a cada seis
/// horas, enquanto correr.
///
/// Observado no `build` da app, como o [licencaRefreshProvider] e o
/// `syncProvider` — é o padrão da casa para o que tem de sobreviver à
/// navegação toda.
///
/// Vive aqui dentro do `ProviderScope`, e não no `main`, por uma razão: é aqui
/// que o NIF da empresa está à mão. No `main` o ping saía sempre sem NIF, e o
/// Control ficava com linhas que não conseguia ligar a nenhum cliente.
final pingsProvider = Provider<void>((ref) {
  if (!SupabaseConfig.enabled) return;

  Future<void> pingar(String origem) async {
    final servico = ref.read(pingsServiceProvider);
    await servico.enviar(
      machineId: await resolverMachineId(),
      origem: origem,
      nif: ref.read(operationsProvider).companyTaxId,
    );
  }

  unawaited(pingar('arranque'));
  final timer = Timer.periodic(
    FistPings.intervalo,
    (_) => unawaited(pingar('timer_6h')),
  );
  ref.onDispose(timer.cancel);
});
