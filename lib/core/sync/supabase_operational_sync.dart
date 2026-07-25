import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import '../config/supabase_config.dart';
import 'sync_engine.dart';

/// Sincroniza o estado completo exclusivo do gestor.
///
/// O perfil de colaborador não usa esta via, porque o payload contém custos e
/// finanças. A sincronização granular para colaboradores será feita por tabelas
/// próprias, com permissões por tipo de registo.
class SupabaseOperationalSync {
  const SupabaseOperationalSync(this._repository);

  final PersistentOperationRepository _repository;

  Future<SyncStatus> synchronize() async {
    if (!SupabaseConfig.enabled) return SyncStatus.synchronized;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return SyncStatus.pendingChanges;

    try {
      final member = await client
          .from('punho_membros')
          .select('empresa_id, perfil')
          .eq('user_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
      if (member == null) return SyncStatus.requiresReview;
      if (member['perfil'] != 'gestor') return SyncStatus.synchronized;

      final empresaId = member['empresa_id'] as String;
      final remote = await client
          .from('punho_estado_operacional')
          .select('revision, payload')
          .eq('empresa_id', empresaId)
          .maybeSingle();

      if (remote == null) {
        if (!_repository.hasPendingRemoteChanges) {
          return SyncStatus.synchronized;
        }
        return _push(client, expectedRevision: null);
      }

      final remoteRevision = (remote['revision'] as num).toInt();
      if (!_repository.hasPendingRemoteChanges) {
        final payload = Map<String, dynamic>.from(remote['payload'] as Map);
        return _repository.importOperationalPayload(
              jsonEncode(payload),
              revision: remoteRevision,
            )
            ? SyncStatus.synchronized
            : SyncStatus.requiresReview;
      }

      if (_repository.remoteRevision != remoteRevision) {
        return SyncStatus.requiresReview;
      }
      return _push(client, expectedRevision: remoteRevision);
    } on PostgrestException {
      return SyncStatus.requiresReview;
    } catch (_) {
      return SyncStatus.pendingChanges;
    }
  }

  Future<SyncStatus> _push(
    SupabaseClient client, {
    required int? expectedRevision,
  }) async {
    try {
      final revision = await client.rpc(
        'punho_guardar_estado_operacional',
        params: {
          'novo_payload': jsonDecode(_repository.exportOperationalPayload()),
          'revisao_esperada': expectedRevision,
        },
      );
      _repository.markRemoteSynchronized((revision as num).toInt());
      return SyncStatus.synchronized;
    } on PostgrestException {
      return SyncStatus.requiresReview;
    } catch (_) {
      return SyncStatus.pendingChanges;
    }
  }
}
