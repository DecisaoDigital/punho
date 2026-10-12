// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/conflitos/registo_de_conflitos.dart';
import '../../core/conflitos/sincronizacao_de_conflitos.dart';
import '../../domain/models/conflito_pendente.dart';
import '../auth/acesso_providers.dart';

/// Motor de sincronização dos conflitos pendentes — mesma costura do
/// `motorSyncProvider` em `sync_providers.dart`: provider próprio para os
/// testes poderem substituir por um duplo sem rede nem disco.
final motorConflitosSyncProvider = FutureProvider<SincronizacaoDeConflitos?>((
  ref,
) async {
  if (!SupabaseConfig.enabled) return null;
  final acesso = ref.watch(estadoAcessoProvider).valueOrNull;
  final empresaId = acesso?.empresaId;
  if (acesso == null || !acesso.membroAtivo || empresaId == null) return null;

  final registo = RegistoDeConflitos(await SharedPreferences.getInstance());
  return SincronizacaoDeConflitos(
    registo: registo,
    cliente: Supabase.instance.client,
    empresaId: empresaId,
    ehGestor: acesso.eGestor,
  );
});

/// Conflitos pendentes (`estado == pendente`) da empresa actual.
///
/// Fase 0: fica pronto sem consumidor — nem a detecção (que escreveria aqui,
/// no aparelho do Gestor) nem o banner (que leria isto, filtrado por papel)
/// existem ainda. Quando existirem, este provider deixa de bastar tal como
/// está: uma leitura do `SharedPreferences` não é reactiva a alterações
/// feitas por fora dele, e vai precisar de um sinal explícito de
/// invalidação, tal como o `operationsProvider` tem
/// `recarregarDoRepositorio()`.
final conflitosPendentesProvider = FutureProvider<List<ConflitoPendente>>((
  ref,
) async {
  final motor = await ref.watch(motorConflitosSyncProvider.future);
  return motor?.registo.pendentes ?? const [];
});
