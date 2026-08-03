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
