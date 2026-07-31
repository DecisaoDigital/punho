import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      debugPrint(
        '[PunhoUpdate] Supabase desactivado (defines em falta) — sem verificação',
      );
      return null;
    }
    // Ler cache local imediatamente para mostrar o banner sem esperar pela
    // rede. Antes o Cesar abria a app, o pedido demorava 1-3s a devolver, e
    // ele fechava antes de ver o banner. Fecha e reabre → mostra. Cache
    // resolve.
    unawaited(_carregarCache());
    unawaited(verificar());
    _ouvirGanhoDeSessao();
    _timer = Timer.periodic(
      intervaloVerificacaoUpdate,
      (_) => unawaited(verificar()),
    );
    return null;
  }

  static const _kCache = 'punho_update.cache_v1';

  Future<void> _carregarCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kCache);
      if (raw == null) return;
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final cached = PunhoUpdateInfo.fromJson(json);
      // Só mostra o cache se o build actual da app ainda for inferior — se ja
      // instalou a versao, cache está desactualizado e deve ser ignorado.
      final info = await PackageInfo.fromPlatform();
      final buildAtual = int.tryParse(info.buildNumber) ?? 0;
      if (cached.buildNumber <= buildAtual) {
        await sp.remove(_kCache);
        return;
      }
      if (!_vivo) return;
      state = cached;
      debugPrint('[PunhoUpdate] cache: v\${cached.version} apresentado imediatamente');
    } catch (e) {
      debugPrint('[PunhoUpdate] cache load falhou: \$e');
    }
  }

  Future<void> _guardarCache(PunhoUpdateInfo info) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kCache, jsonEncode(info.toJson()));
    } catch (e) {
      debugPrint('[PunhoUpdate] cache save falhou: \$e');
    }
  }

  /// Pergunta ao Control se há versão nova. Seguro de chamar a qualquer momento.
  Future<void> verificar() async {
    final servico = ref.read(punhoUpdateServiceProvider);
    final info = await servico.check();
    if (!_vivo || info == null) return;
    // Só se escreve quando há novidade: uma verificação falhada por estar
    // offline não pode apagar um aviso que já estava à vista.
    state = info;
    unawaited(_guardarCache(info));
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
