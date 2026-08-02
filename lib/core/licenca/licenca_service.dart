import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'licenca_info.dart';

/// Assinatura da chamada às Edge Functions. Existe para os testes poderem
/// substituir a rede sem precisar de um package de mocking.
typedef InvocarFuncao =
    Future<FunctionResponse> Function(String nome, Map<String, dynamic> corpo);

const _timeout = Duration(seconds: 10);

/// Cliente do licenciamento. Fala com as Edge Functions `registar-terminal` e
/// `validar-licenca` do Control, sempre com `app: 'punho'`.
///
/// Não exige sessão iniciada: as funções aceitam a chave pública do projecto,
/// o que permite registar o terminal logo no arranque, antes do login.
///
/// Não verifica `SupabaseConfig.enabled` — isso é responsabilidade de quem
/// chama (`licencaProvider` e o arranque em `main`), para o serviço continuar
/// testável sem `--dart-define`.
class PunhoLicencaService {
  PunhoLicencaService(SupabaseClient client)
    : _invocar = ((nome, corpo) =>
          client.functions.invoke(nome, body: corpo).timeout(_timeout));

  /// Para testes.
  PunhoLicencaService.comInvocador(this._invocar);

  final InvocarFuncao _invocar;

  /// Regista o terminal. Idempotente do lado do servidor por
  /// `(machine_id, app)`, por isso pode ser chamado em todos os arranques.
  Future<void> registarTerminal(String machineId, {String? nif}) async {
    try {
      final corpo = <String, dynamic>{
        'machine_id': machineId,
        'app': 'punho',
        'info_host': await _colherInfoHost(),
      };
      if (nif != null && nif.isNotEmpty) corpo['nif'] = nif;
      await _invocar('registar-terminal', corpo);
    } catch (erro) {
      // Falha em silêncio: o utilizador não deve ver erros de rede no arranque.
      debugPrint('registar-terminal falhou: $erro');
    }
  }

  /// Valida a licença. Devolve `null` se não conseguir falar com o servidor,
  /// para o chamador distinguir "offline" de "sem licença".
  Future<LicencaInfo?> validar(String machineId) async {
    try {
      final resposta = await _invocar('validar-licenca', {
        'machine_id': machineId,
        'app': 'punho',
      });
      final dados = resposta.data;
      if (dados is! Map) return null;
      return LicencaInfo.fromJson(
        Map<String, dynamic>.from(dados),
        machineId: machineId,
      );
    } catch (erro) {
      debugPrint('validar-licenca falhou: $erro');
      return null;
    }
  }

  /// Contexto do terminal para o Cesar identificar a instalação no Control.
  /// Só identificação de máquina e versão — nada de dados de negócio.
  Future<Map<String, dynamic>> _colherInfoHost() async {
    final info = <String, dynamic>{'plataforma': Platform.operatingSystem};
    try {
      final pacote = await PackageInfo.fromPlatform();
      info['versao_app'] = pacote.version;
      info['build'] = pacote.buildNumber;
    } catch (_) {
      // Sem package_info não vale a pena falhar o registo.
    }
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        info['host'] = android.model;
        info['fabricante'] = android.manufacturer;
        info['versao_so'] = android.version.release;
      } else if (Platform.isWindows) {
        final windows = await plugin.windowsInfo;
        info['host'] = windows.computerName;
        info['versao_so'] = windows.productName;
      }
    } catch (_) {
      // Idem: o info_host é informativo, não é condição para registar.
    }
    return info;
  }
}
