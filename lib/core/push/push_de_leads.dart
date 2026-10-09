import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lembretes/lembretes_providers.dart' show uidAtualProvider;

/// Avisos push das leads (camada 2). Só Android: nos outros sistemas, e em
/// qualquer build sem `google-services.json`, tudo isto é um no-op silencioso e
/// a camada 1 (aviso com a app aberta) continua a bastar.
///
/// O servidor decide quem é avisado (ver a edge function `punho-push`); o
/// aparelho só diz «este token é meu» e quem o dono é sai da sessão.
class PushDeLeads {
  PushDeLeads._();

  static const canal = 'leads';
  static Future<bool>? _pronto;
  static String? _tokenRegistado;
  static StreamSubscription<String>? _renovacoes;

  /// `false` fora do Android ou sem o ficheiro do Firebase no build.
  static Future<bool> _init() => _pronto ??= () async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      await Firebase.initializeApp();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              canal,
              'Leads',
              description: 'Leads novas e leads atribuídas a ti',
              importance: Importance.high,
            ),
          );
      return true;
    } catch (e) {
      debugPrint('push desligado: $e');
      return false;
    }
  }();

  /// Regista este aparelho para a conta com sessão. Seguro de chamar
  /// repetidamente: o servidor trata o resto.
  static Future<void> registar() async {
    if (!await _init()) return;
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      final token = await fcm.getToken();
      if (token == null) return;
      await _enviar(token);
      _renovacoes ??= fcm.onTokenRefresh.listen(
        (t) => unawaited(_enviar(t).catchError((_) {})),
      );
    } catch (e) {
      debugPrint('push: registo falhou: $e');
    }
  }

  static Future<void> _enviar(String token) async {
    await Supabase.instance.client.rpc(
      'punho_registar_push',
      params: {'p_token': token},
    );
    _tokenRegistado = token;
  }

  /// Chamar **antes** de terminar a sessão: depois já não há quem autorize.
  /// Sem isto, quem sai da conta continuaria a receber no telemóvel os avisos
  /// da conta que deixou.
  static Future<void> esquecer() async {
    final token = _tokenRegistado;
    if (token == null) return;
    try {
      await Supabase.instance.client
          .rpc('punho_esquecer_push', params: {'p_token': token})
          .timeout(const Duration(seconds: 3));
      _tokenRegistado = null;
    } catch (e) {
      debugPrint('push: esquecer falhou: $e');
    }
  }
}

/// Regista o aparelho sempre que há sessão (e de novo ao voltar à app, porque
/// um token pode ter sido apagado no servidor ao ser dado como morto).
class ObservadorDePush extends ConsumerStatefulWidget {
  const ObservadorDePush({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ObservadorDePush> createState() => _ObservadorDePushState();
}

class _ObservadorDePushState extends ConsumerState<ObservadorDePush>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _registar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _registar();
  }

  void _registar() {
    if (ref.read(uidAtualProvider) != null) unawaited(PushDeLeads.registar());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(uidAtualProvider, (_, uid) {
      if (uid != null) unawaited(PushDeLeads.registar());
    });
    return widget.child;
  }
}
