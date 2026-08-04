import 'package:flutter/widgets.dart';
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

/// O build que o gestor dispensou no X do banner — só esse, e só nesta
/// sessão. Vive à parte do [punhoUpdateProvider] porque dispensar não é
/// esquecer: se aparecer uma versão mais recente ainda nesta sessão, o aviso
/// volta. O que o X promete é "não agora, para esta"; para o resto ele fica a
/// zero outra vez a cada arranque, tal como o [punhoUpdateProvider] — não há
/// nada a persistir.
final updateDispensadoProvider = StateProvider<int?>((_) => null);

class PunhoUpdateController extends Notifier<PunhoUpdateInfo?> {
  StreamSubscription<AuthState>? _subscricaoAuth;
  Timer? _timer;
  _ObservadorDeRegresso? _observador;
  bool _vivo = true;
  String? _ultimoUtilizador;

  @override
  PunhoUpdateInfo? build() {
    ref.onDispose(() {
      _vivo = false;
      _subscricaoAuth?.cancel();
      _timer?.cancel();
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
        _observador = null;
      }
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
    _ouvirRegressoDoBackground();
    _timer = Timer.periodic(
      intervaloVerificacaoUpdate,
      (_) => unawaited(verificar()),
    );
    return null;
  }

  /// Voltar à app conta como momento de verificar.
  ///
  /// Sem isto havia só dois momentos: o arranque de raiz e o temporizador de 24
  /// horas. Quem deixa a app em segundo plano e alterna para ela — que é como o
  /// Cesar a usa — nunca apanhava uma versão publicada entretanto. Foi
  /// exactamente o que aconteceu com a v0.0.17 e a v0.0.18: a Edge Function
  /// respondia "há versão nova" e ninguém lhe perguntava.
  void _ouvirRegressoDoBackground() {
    _observador = _ObservadorDeRegresso(() {
      if (_vivo) unawaited(verificar());
    });
    WidgetsBinding.instance.addObserver(_observador!);
  }

  /// `v2` porque o envelope passou a levar `guardado_em`: uma entrada do
  /// formato antigo não tem data e seria tratada como eterna. Mudar de chave
  /// descarta-a sem código de migração.
  static const _kCache = 'punho_update.cache_v2';

  /// Um aviso guardado não vale para sempre. Se a versão for retirada de
  /// `versoes_apps`, `check()` passa a devolver `null` — e `null` também é o
  /// que devolve quando não há rede, por isso não dá para distinguir os dois
  /// casos e limpar o cache à conta disso. A validade resolve: ao fim de uma
  /// semana o cache deixa de ser mostrado por si só.
  static const _validadeCache = Duration(days: 7);

  Future<void> _carregarCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kCache);
      if (raw == null) return;
      final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final guardadoEm = DateTime.tryParse(
        envelope['guardado_em'] as String? ?? '',
      );
      if (guardadoEm == null ||
          DateTime.now().difference(guardadoEm) > _validadeCache) {
        await sp.remove(_kCache);
        return;
      }
      final cached = PunhoUpdateInfo.fromJson(
        Map<String, dynamic>.from(envelope['info'] as Map),
      );
      // Só mostra o cache se o build actual da app ainda for inferior — se ja
      // instalou a versao, cache está desactualizado e deve ser ignorado.
      final info = await PackageInfo.fromPlatform();
      final buildAtual = int.tryParse(info.buildNumber) ?? 0;
      if (cached.buildNumber <= buildAtual) {
        await sp.remove(_kCache);
        return;
      }
      if (!_vivo) return;
      // A rede pode ter ganho a corrida: `_carregarCache` e `verificar` arrancam
      // os dois no `build()` sem ordem garantida. Se já há estado, veio do
      // servidor e é mais fresco do que isto — não o pisar.
      if (state != null) return;
      state = cached.semBloqueio();
      debugPrint(
        '[PunhoUpdate] cache: v${cached.version} apresentado imediatamente',
      );
    } catch (e) {
      debugPrint('[PunhoUpdate] cache load falhou: $e');
    }
  }

  Future<void> _guardarCache(PunhoUpdateInfo info) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _kCache,
        jsonEncode({
          'guardado_em': DateTime.now().toIso8601String(),
          'info': info.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('[PunhoUpdate] cache save falhou: $e');
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
    _subscricaoAuth = Supabase.instance.client.auth.onAuthStateChange.listen(
      (estado) {
        if (estado.event != AuthChangeEvent.signedIn) return;
        final utilizador = estado.session?.user.id;
        if (utilizador == null || utilizador == _ultimoUtilizador) return;
        _ultimoUtilizador = utilizador;
        unawaited(verificar());
      },
      // Este canal também traz erros — um link de email caducado, por exemplo,
      // desde que a app passou a receber `punho://auth/callback`. Sem `onError`
      // rebentavam para fora da zona, e uma falha de autenticação não é
      // assunto de quem procura actualizações.
      onError: (_) {},
    );
  }
}

/// Observador mínimo do ciclo de vida. Existe como classe própria porque um
/// `Notifier` do Riverpod não pode ele próprio ser um `WidgetsBindingObserver`
/// sem arrastar o mixin e o `dispose` para dentro do provider.
class _ObservadorDeRegresso extends WidgetsBindingObserver {
  _ObservadorDeRegresso(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}
