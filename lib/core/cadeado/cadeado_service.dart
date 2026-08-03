import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cadeado local (biometria + PIN fallback) — task #201 + pedido do Cesar
/// para bloquear ao voltar de background após inactividade.
///
/// **Estado guardado:**
///   - PIN: hash sha256 com salt em `flutter_secure_storage` (keystore Android)
///   - Threshold em minutos: `SharedPreferences` (`cadeado.threshold_minutes`;
///     -1 = nunca; 1/2/5/15/30). Default 2.
///   - Biometria activada: `SharedPreferences` (`cadeado.biometria`; default true
///     se disponível)
///   - Último `paused` (epoch ms): `SharedPreferences`
///     (`cadeado.ultimo_paused_ms`) — persiste entre kills.
///
/// **Fluxo de lifecycle:**
///   - Cold start: se PIN definido → bloqueado
///   - `paused` → guarda timestamp
///   - `resumed` → se threshold > 0 e (agora - timestamp) > threshold →
///     bloqueado
///
/// **Falhas:** 5 tentativas de PIN falhadas → obriga terminar sessão Supabase
/// no `LockScreen`.
class CadeadoService {
  CadeadoService({FlutterSecureStorage? secure, LocalAuthentication? auth})
    : _secure = secure ?? const FlutterSecureStorage(),
      _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _secure;
  final LocalAuthentication _auth;

  static const _kPinHash = 'cadeado.pin_hash_v1';
  static const _kPinSalt = 'cadeado.pin_salt_v1';
  static const _kThreshold = 'cadeado.threshold_minutes';
  static const _kBiometria = 'cadeado.biometria';
  static const _kUltimoPausedMs = 'cadeado.ultimo_paused_ms';
  static const thresholdDefault = 2;

  Future<bool> temPinDefinido() async {
    final h = await _secure.read(key: _kPinHash);
    return h != null && h.isNotEmpty;
  }

  Future<bool> biometriaDisponivelNoDispositivo() async {
    try {
      final suportado = await _auth.isDeviceSupported();
      if (!suportado) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final tipos = await _auth.getAvailableBiometrics();
      return tipos.isNotEmpty;
    } catch (e) {
      debugPrint('biometria check falhou: $e');
      return false;
    }
  }

  Future<bool> biometriaActivada() async {
    final sp = await SharedPreferences.getInstance();
    // default: true se disponível
    return sp.getBool(_kBiometria) ?? await biometriaDisponivelNoDispositivo();
  }

  Future<void> setBiometriaActivada(bool activada) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBiometria, activada);
  }

  /// -1 = nunca bloquear (só cold start). 0 = sempre. n>0 = após n min.
  Future<int> thresholdMinutos() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kThreshold) ?? thresholdDefault;
  }

  Future<void> setThresholdMinutos(int m) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kThreshold, m);
  }

  Future<void> guardarPin(String pin) async {
    assert(pin.length >= 4 && pin.length <= 6);
    final salt = _gerarSalt();
    final hash = _hash(pin, salt);
    await _secure.write(key: _kPinSalt, value: salt);
    await _secure.write(key: _kPinHash, value: hash);
  }

  Future<bool> validarPin(String pin) async {
    final hash = await _secure.read(key: _kPinHash);
    final salt = await _secure.read(key: _kPinSalt);
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> apagarPin() async {
    await _secure.delete(key: _kPinHash);
    await _secure.delete(key: _kPinSalt);
  }

  /// Pede a digital/rosto ao sistema.
  ///
  /// **`stickyAuth` tem de ficar `false`.** Com `true`, o plugin engole o
  /// `ERROR_CANCELED` sempre que a activity está em pausa — e a activity fica em
  /// pausa precisamente enquanto o prompt do sistema está à frente. O `Future`
  /// nunca completava: o ecrã de bloqueio ficava eternamente em "a aguardar
  /// biometria", sem prompt, sem erro e sem forma de chegar ao PIN. Era este o
  /// bug que o Cesar apanhou na v0.0.16.
  ///
  /// **`biometricOnly` tem de ficar `true`.** Com `false` o plugin acrescenta
  /// `DEVICE_CREDENTIAL` aos autenticadores aceites e, ao fazê-lo, deixa de pôr
  /// botão de cancelar no prompt. Não faz sentido nenhum aqui: o fallback já é
  /// o nosso PIN, e sem botão de cancelar não havia como lá chegar.
  /// `true` enquanto o prompt do sistema está à frente da app.
  ///
  /// O prompt tira o foco à activity, e o Flutter reporta isso como uma ida a
  /// background. Sem esta marca, o [CadeadoGate] carimbava "saiu da app" a meio
  /// do desbloqueio e voltava a bloquear no instante em que a digital era
  /// aceite — quem tivesse o cadeado em "Sempre" nunca mais entrava pela digital.
  bool get aPedirBiometria => _aPedirBiometria;
  bool _aPedirBiometria = false;

  Future<ResultadoBiometria> pedirBiometria() async {
    _aPedirBiometria = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Desbloquear Punho',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
      return ok
          ? const ResultadoBiometria.ok()
          : const ResultadoBiometria.recusada();
    } on PlatformException catch (e) {
      // Nunca falhar em silêncio outra vez: o utilizador tem de perceber se é
      // "não tens digitais registadas" ou "tentaste demasiadas vezes".
      debugPrint('biometria falhou: ${e.code} · ${e.message}');
      return ResultadoBiometria.erro(_mensagemDoErro(e.code));
    } catch (e) {
      debugPrint('biometria falhou: $e');
      return const ResultadoBiometria.erro(
        'Não foi possível usar a biometria neste dispositivo.',
      );
    } finally {
      _aPedirBiometria = false;
    }
  }

  static String _mensagemDoErro(String codigo) => switch (codigo) {
    'NotEnrolled' =>
      'Não há impressões digitais registadas neste telemóvel. '
          'Regista uma nas definições do Android.',
    'NotAvailable' => 'Este telemóvel não disponibilizou o leitor de digitais.',
    'LockedOut' =>
      'Demasiadas tentativas falhadas. Espera um pouco ou usa o PIN.',
    'PermanentlyLockedOut' =>
      'A biometria ficou bloqueada pelo Android. Desbloqueia o telemóvel '
          'pelo método do sistema e volta a tentar.',
    'no_fragment_activity' =>
      'Erro de configuração da app: a biometria não pode arrancar.',
    _ => 'A biometria não respondeu. Usa o PIN.',
  };

  Future<void> registarPaused() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kUltimoPausedMs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> deveBloquearAoRetomar() async {
    final t = await thresholdMinutos();
    if (t < 0) return false; // nunca
    if (t == 0) return true; // sempre
    final sp = await SharedPreferences.getInstance();
    final ultimoMs = sp.getInt(_kUltimoPausedMs);
    if (ultimoMs == null) return false;
    final agora = DateTime.now().millisecondsSinceEpoch;
    final minutosPassados = (agora - ultimoMs) / 60000.0;
    return minutosPassados >= t;
  }

  String _gerarSalt() =>
      DateTime.now().microsecondsSinceEpoch.toString() +
      DateTime.now().hashCode.toString();

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt|$pin')).toString();
}

/// O que aconteceu ao pedido de biometria.
///
/// Um `bool` não chegava: "o utilizador carregou em cancelar" e "o leitor nem
/// existe" levam a app a sítios diferentes, e o segundo tem de ser dito em voz
/// alta em vez de deixar o ecrã parado.
class ResultadoBiometria {
  const ResultadoBiometria.ok() : autenticado = true, erro = null;
  const ResultadoBiometria.recusada() : autenticado = false, erro = null;
  const ResultadoBiometria.erro(String this.erro) : autenticado = false;

  /// Passou.
  final bool autenticado;

  /// Mensagem a mostrar, ou `null` se foi o utilizador a desistir — nesse caso
  /// não há nada a explicar, ele sabe o que fez.
  final String? erro;
}

/// Provider global do service. Não tem state — o state está no
/// [cadeadoBloqueadoProvider].
final cadeadoServiceProvider = Provider<CadeadoService>(
  (_) => CadeadoService(),
);

/// Estado boolean: true = mostrar LockScreen; false = aplicação visível.
final cadeadoBloqueadoProvider = StateProvider<bool>((_) => false);
