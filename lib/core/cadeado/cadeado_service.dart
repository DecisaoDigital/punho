import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
///     -1 = nunca; 1/5/15/30). Default 5.
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
  static const thresholdDefault = 5;

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

  Future<bool> pedirBiometria() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Desbloquear Punho',
        options: const AuthenticationOptions(
          biometricOnly: false, // permite fallback do device (pattern/PIN Android)
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('biometria falhou: $e');
      return false;
    }
  }

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

/// Provider global do service. Não tem state — o state está no
/// [cadeadoBloqueadoProvider].
final cadeadoServiceProvider = Provider<CadeadoService>((_) => CadeadoService());

/// Estado boolean: true = mostrar LockScreen; false = aplicação visível.
final cadeadoBloqueadoProvider = StateProvider<bool>((_) => false);
