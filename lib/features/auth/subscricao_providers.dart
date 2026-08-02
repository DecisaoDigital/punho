import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/operations/operations_controller.dart';
import 'acesso_providers.dart';
import 'data/subscricao_service.dart';

/// Serviço da subscrição. Nos testes é substituído por um duplo via
/// `ProviderScope(overrides: [subscricaoServiceProvider.overrideWithValue(...)])`,
/// tal como [acessoServiceProvider].
final subscricaoServiceProvider = Provider<SubscricaoService>(
  (ref) => SupabaseSubscricaoService(Supabase.instance.client),
);

/// Limite de colaboradores activos que a subscrição no servidor autoriza.
///
/// `null` quando não há como saber — sem Supabase configurado (modo
/// demonstração), sem sessão, sem empresa, ou a leitura falhou — e nesse caso
/// quem usa isto tem de cair no valor local, nunca bloquear. Mesmo padrão do
/// `motorSyncProvider` em `features/sync/sync_providers.dart`: espera pelo
/// acesso resolver antes de perguntar ao servidor.
final limiteColaboradoresServidorProvider = FutureProvider<int?>((ref) async {
  if (!SupabaseConfig.enabled) return null;
  final acesso = ref.watch(estadoAcessoProvider).valueOrNull;
  final empresaId = acesso?.empresaId;
  if (acesso == null || !acesso.membroAtivo || empresaId == null) return null;
  return ref
      .watch(subscricaoServiceProvider)
      .limiteColaboradoresAtivos(empresaId);
});

/// Limite de colaboradores activos que a app deve mesmo aplicar.
///
/// O do servidor manda sempre que se conseguiu ler; falhando isso (rede em
/// baixo, modo demonstração, sem sessão), vale o valor local do onboarding
/// (`OperationsState.activeCollaboratorLimit`) — nunca se bloqueia a criação
/// de colaboradores por causa de uma falha de rede.
final limiteColaboradoresEfetivoProvider = Provider<int>((ref) {
  final doServidor = ref
      .watch(limiteColaboradoresServidorProvider)
      .valueOrNull;
  final local = ref.watch(
    operationsProvider.select((s) => s.activeCollaboratorLimit),
  );
  return doServidor ?? local;
});
