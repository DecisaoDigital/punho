import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/updates/update_info.dart';
import '../../core/updates/update_service.dart';

/// De quanto em quanto tempo se volta a perguntar ao Control se há versão nova.
/// Alinhado com o padrão do licenciamento (`intervaloRevalidacaoLicenca`).
const intervaloVerificacaoUpdate = Duration(hours: 24);

final punhoUpdateServiceProvider = Provider<PunhoUpdateService>(
  (ref) => PunhoUpdateService(Supabase.instance.client),
);

/// Estado global do auto-update. `null` significa "nada a anunciar" — ou porque
/// não há versão nova, ou porque não foi possível saber.
///
/// É global de propósito: o banner tem de aparecer a quem está no ecrã de login
/// e a quem está bloqueado no `AcessoGate`, não só a quem chega ao dashboard.
/// Por isso a verificação não depende de estado de autenticação nenhum.
final punhoUpdateProvider =
    NotifierProvider<PunhoUpdateController, PunhoUpdateInfo?>(
      PunhoUpdateController.new,
    );

class PunhoUpdateController extends Notifier<PunhoUpdateInfo?> {
  StreamSubscription<AuthState>? _subscricaoAuth;
  Timer? _timer;
  bool _vivo = true;
  String? _ultimoUtilizador;

  @override
  PunhoUpdateInfo? build() {
    ref.onDispose(() {
      _vivo = false;
      _subscricaoAuth?.cancel();
      _timer?.cancel();
    });
    // Sem Supabase configurado (modo demonstração, testes) não há nada a
    // consultar — e `Supabase.instance` rebentaria por não estar inicializado.
    if (!SupabaseConfig.enabled) {
      // Grita nos logs em vez de ficar calado: uma app compilada sem os
      // `--dart-define` do Supabase comporta-se exactamente como uma sem
      // ligação, e foi assim que a v0.0.5 do Cesar passou despercebida.
      debugPrint(
        '[PunhoUpdate] Supabase desactivado (defines em falta) — sem verificação',
      );
      return null;
    }
    unawaited(verificar());
    _ouvirGanhoDeSessao();
    _timer = Timer.periodic(
      intervaloVerificacaoUpdate,
      (_) => unawaited(verificar()),
    );
    return null;
  }

  /// Pergunta ao Control se há versão nova. Seguro de chamar a qualquer momento.
  Future<void> verificar() async {
    final servico = ref.read(punhoUpdateServiceProvider);
    final info = await servico.check();
    if (!_vivo || info == null) return;
    // Só se escreve quando há novidade: uma verificação falhada por estar
    // offline não pode apagar um aviso que já estava à vista.
    state = info;
  }

  /// Uma sessão nova pode trazer informação que a chamada anónima não tinha (e
  /// é o momento em que o utilizador acabou de mexer na app). O `signedIn`
  /// também dispara em refresh de token, por isso só se reage a utilizador novo.
  void _ouvirGanhoDeSessao() {
    _subscricaoAuth = Supabase.instance.client.auth.onAuthStateChange.listen((
      estado,
    ) {
      if (estado.event != AuthChangeEvent.signedIn) return;
      final utilizador = estado.session?.user.id;
      if (utilizador == null || utilizador == _ultimoUtilizador) return;
      _ultimoUtilizador = utilizador;
      unawaited(verificar());
    });
  }
}
