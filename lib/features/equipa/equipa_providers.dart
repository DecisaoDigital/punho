// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../auth/acesso_providers.dart';
import 'data/equipa_service.dart';
import 'domain/funcao_na_equipa.dart';

final equipaServiceProvider = Provider<EquipaService>(
  (ref) => SupabaseEquipaService(Supabase.instance.client),
);

/// O que eu sou na equipa. Sem servidor, ou se a pergunta falhar, vale gerente:
/// esconder ecrãs é apresentação, e uma falha de rede não pode esconder o Painel
/// a quem é gerente nem trancar ninguém fora de nada.
final minhaFuncaoProvider = FutureProvider.autoDispose<FuncaoNaEquipa>((
  ref,
) async {
  if (!SupabaseConfig.enabled) return FuncaoNaEquipa.gerente;
  ref.watch(eventosDeSessaoProvider);
  try {
    return await ref.watch(equipaServiceProvider).minhaFuncao();
  } catch (erro) {
    debugPrint('[Equipa] função falhou: $erro');
    return FuncaoNaEquipa.gerente;
  }
});

/// A equipa, para o gerente a gerir.
final equipaProvider = FutureProvider.autoDispose<List<MembroDaEquipa>>(
  (ref) => ref.watch(equipaServiceProvider).listar(),
);
