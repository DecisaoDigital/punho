// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'licenca_fist.dart';
import 'licenca_info.dart';
import 'licenca_service.dart';
import 'machine_id.dart';

final licencaServiceProvider = Provider<FistLicencaService>(
  (ref) => FistLicencaService(Supabase.instance.client),
);

final machineIdProvider = FutureProvider<String>((ref) => resolverMachineId());

/// Estado actual da licença, tal como a última resposta de `licenca-fist`.
/// `null` significa "ainda não se sabe" (sem sessão, offline) — não significa
/// "sem licença".
final licencaProvider = FutureProvider<LicencaInfo?>((ref) async {
  if (!SupabaseConfig.enabled) return null;
  return ref.watch(licencaFistProvider).resposta?.licenca;
});

/// Mantém viva a ligação à licença da conta (sessão única + batimento).
/// Basta observá-lo uma vez, no arranque.
final licencaRefreshProvider = Provider<void>((ref) {
  ref.watch(licencaFistLigacaoProvider);
});
