import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/contabilista_service.dart';
import 'domain/contabilista.dart';

/// Serviço do histórico contabilístico. Nos testes é substituído por um fake
/// via `ProviderScope(overrides: [...])`.
final contabilistaServiceProvider = Provider<ContabilistaService>(
  (ref) => SupabaseContabilistaService(Supabase.instance.client),
);

/// Convites emitidos. `autoDispose` para o ecrã reler ao voltar — um convite
/// que o contabilista abriu entretanto tem de mudar de estado sem reiniciar.
final convitesContabilistaProvider =
    FutureProvider.autoDispose<List<ConviteContabilista>>(
      (ref) => ref.watch(contabilistaServiceProvider).convites(),
    );

/// O catálogo de perguntas. Não é `autoDispose`: muda quando se acrescenta uma
/// rubrica à base, não durante uma sessão.
final catalogoContabilistaProvider =
    FutureProvider<List<RubricaContabilista>>(
      (ref) => ref.watch(contabilistaServiceProvider).catalogo(),
    );

/// O que ficou por responder. Alimenta as Tarefas e o ecrã do histórico.
final lacunasContabilistaProvider =
    FutureProvider.autoDispose<List<LacunaContabilista>>(
      (ref) => ref.watch(contabilistaServiceProvider).lacunas(),
    );

/// As respostas guardadas de uma rubrica, para o ecrã de edição.
final respostasDaRubricaProvider = FutureProvider.autoDispose
    .family<List<RespostaContabilista>, String>(
      (ref, rubrica) =>
          ref.watch(contabilistaServiceProvider).respostasDe(rubrica),
    );
