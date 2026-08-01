import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/acesso_service.dart';
import 'domain/estado_acesso.dart';

/// Serviço de acessos. Nos testes é substituído por um fake via
/// `ProviderScope(overrides: [acessoServiceProvider.overrideWithValue(...)])`.
final acessoServiceProvider = Provider<AcessoService>(
  (ref) => SupabaseAcessoService(Supabase.instance.client),
);

/// Eventos de autenticação. Existe para o [estadoAcessoProvider] os poder
/// observar — ver lá porquê.
final eventosDeSessaoProvider = StreamProvider.autoDispose<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

/// Estado de acesso da sessão actual. É `autoDispose` para ser recalculado a
/// cada entrada: uma revogação tem de fechar a porta no arranque seguinte.
///
/// Observa os eventos de sessão, e não é um detalhe: a pergunta que faz ao
/// servidor é «este utilizador é membro activo?», e a resposta depende do
/// `auth.uid()` do token. Perguntada antes de o token estar aplicado, a
/// resposta é *não* — e sem nada que a mande perguntar outra vez, ficava um
/// gestor aprovado a olhar para «Pedido em análise» até reiniciar a app.
final estadoAcessoProvider = FutureProvider.autoDispose<EstadoAcesso>((ref) {
  ref.watch(eventosDeSessaoProvider);
  return ref.watch(acessoServiceProvider).meuAcesso();
});

/// Convites da empresa do gestor.
final convitesProvider = FutureProvider.autoDispose<List<Convite>>(
  (ref) => ref.watch(acessoServiceProvider).listarConvites(),
);
