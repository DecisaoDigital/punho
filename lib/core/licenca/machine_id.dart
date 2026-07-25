import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave em SharedPreferences onde o identificador fica em cache.
const chaveMachineId = 'punho_machine_id';

/// Identificador estável deste dispositivo, usado pelo Control para associar
/// a linha em `licencas`.
///
/// É o SHA256 de uma semente própria da plataforma, guardado em
/// SharedPreferences para não depender de o `device_info_plus` responder
/// sempre da mesma maneira ao longo do tempo. [semente] existe para os testes
/// poderem correr sem plugins nativos.
Future<String> resolverMachineId({Future<String> Function()? semente}) async {
  final prefs = await SharedPreferences.getInstance();
  final emCache = prefs.getString(chaveMachineId);
  if (emCache != null && emCache.length >= 8) return emCache;

  final crua = await (semente ?? sementeDoDispositivo)();
  final hash = sha256.convert(utf8.encode(crua)).toString();
  await prefs.setString(chaveMachineId, hash);
  return hash;
}

/// Semente por plataforma. Nunca sai da app — só o hash é enviado.
Future<String> sementeDoDispositivo() async {
  final plugin = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    // ANDROID_ID: estável por dispositivo + assinatura da app.
    return 'android:${info.id}';
  }
  if (Platform.isWindows) {
    final info = await plugin.windowsInfo;
    // deviceId é o MachineGuid do registo — estável entre arranques.
    return 'windows:${info.computerName}:${info.deviceId}';
  }
  // Plataformas não suportadas: gera-se um valor único que fica em cache,
  // por isso mantém-se estável a partir do primeiro arranque.
  return 'desconhecido:${Platform.operatingSystem}:'
      '${DateTime.now().microsecondsSinceEpoch}';
}
