import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/acesso_service.dart';
import 'domain/estado_acesso.dart';

/// Serviço de acessos. Nos testes é substituído por um fake via
/// `ProviderScope(overrides: [acessoServiceProvider.overrideWithValue(...)])`.
final acessoServiceProvider = Provider<AcessoService>(
  (ref) => SupabaseAcessoService(Supabase.instance.client),
);

/// Estado de acesso da sessão actual. É `autoDispose` para ser recalculado a
/// cada entrada: uma revogação tem de fechar a porta no arranque seguinte.
final estadoAcessoProvider = FutureProvider.autoDispose<EstadoAcesso>(
  (ref) => ref.watch(acessoServiceProvider).meuAcesso(),
);

/// Convites da empresa do gestor.
final convitesProvider = FutureProvider.autoDispose<List<Convite>>(
  (ref) => ref.watch(acessoServiceProvider).listarConvites(),
);
