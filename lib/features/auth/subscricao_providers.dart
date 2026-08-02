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

/// Vagas de colaboradores activos que a subscrição no servidor autoriza.
///
/// Puramente informativo desde a decisão de 2026-08-02: já não é um limite a
/// impor, é o número que a app mostra ao gestor para ele saber se está acima
/// do plano. `null` quando não há como saber — sem Supabase configurado (modo
/// demonstração), sem sessão, sem empresa, ou a leitura falhou — e nesse caso
/// quem usa isto cai no valor local. Mesmo padrão do `motorSyncProvider` em
/// `features/sync/sync_providers.dart`: espera pelo acesso resolver antes de
/// perguntar ao servidor.
final limiteColaboradoresServidorProvider = FutureProvider<int?>((ref) async {
  if (!SupabaseConfig.enabled) return null;
  final acesso = ref.watch(estadoAcessoProvider).valueOrNull;
  final empresaId = acesso?.empresaId;
  if (acesso == null || !acesso.membroAtivo || empresaId == null) return null;
  return ref
      .watch(subscricaoServiceProvider)
      .limiteColaboradoresAtivos(empresaId);
});

/// Vagas autorizadas a mostrar ao gestor — o número usado nos avisos e no
/// cabeçalho de Funcionários.
///
/// O do servidor vale sempre que se conseguiu ler; falhando isso (rede em
/// baixo, modo demonstração, sem sessão), cai no valor que o gestor declarou
/// no onboarding (`OperationsState.activeCollaboratorLimit`) — que aqui é só
/// o número declarado, não um limite de recurso. Desde a decisão de
/// 2026-08-02 nada nesta app bloqueia a criação de um colaborador por causa
/// disto, servidor a responder ou não: quem impede o acesso de quem excede o
/// autorizado é o circuito de aprovação no Control (`punho_pedidos_acesso`),
/// não `OperationsController.saveCollaborator`.
final limiteColaboradoresEfetivoProvider = Provider<int>((ref) {
  final doServidor = ref
      .watch(limiteColaboradoresServidorProvider)
      .valueOrNull;
  final local = ref.watch(
    operationsProvider.select((s) => s.activeCollaboratorLimit),
  );
  return doServidor ?? local;
});
