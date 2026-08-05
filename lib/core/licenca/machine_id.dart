import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
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
///
/// **Em Android é o ANDROID_ID, e tem de ser.** Esteve em `androidInfo.id`, que
/// não é isso: é o `Build.ID`, o identificador da *ROM* — `TKQ1.221013.002` no
/// Redmi. Dois aparelhos com a mesma versão de MIUI produziam o mesmo hash,
/// logo o mesmo terminal, logo a mesma licença. Dois clientes diferentes a
/// partilhar uma linha, sem nada no ecrã a denunciá-lo.
///
/// O ANDROID_ID verdadeiro é único por (aparelho, chave de assinatura da app) e
/// sobrevive a uma reinstalação — que é o que se quer de um terminal
/// licenciado. O `device_info_plus` deixou de o expor; vem do `android_id`.
///
/// Corrigido a 5 de Agosto de 2026, com o Punho a recomeçar do zero. Era o
/// único momento em que sai de graça: mudar a semente com terminais registados
/// obrigaria a reemitir todas as licenças.
Future<String> sementeDoDispositivo() async {
  final plugin = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final androidId = await const AndroidId().getId();
    if (androidId != null && androidId.trim().isNotEmpty) {
      return 'android:${androidId.trim()}';
    }
    // Sem ANDROID_ID não se cai para o `Build.ID`: era esse o erro. Um valor
    // único gerado aqui fica em cache no primeiro arranque e nunca colide —
    // perde-se numa reinstalação, o que é preferível a dois donos na mesma
    // licença.
    return 'android:sem-android-id:'
        '${DateTime.now().microsecondsSinceEpoch}:'
        '${Object().hashCode}';
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
