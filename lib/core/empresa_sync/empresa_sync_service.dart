import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Sincroniza os dados detalhados da empresa (NIF, morada, contactos,
/// facturação, custos) com o Supabase, chamando a Edge Function
/// `sincronizar-empresa-punho`.
///
/// A EF grava em `punho_empresas.dados` (jsonb) e um trigger DB
/// cria/actualiza automaticamente a linha em `licencas` (app='punho') que o
/// Control lê para mostrar a empresa na sua lista.
///
/// **Contexto:** o `completeOnboarding` grava tudo em SharedPreferences local.
/// Sem esta sincronização, os dados nunca chegam ao servidor e o Control nunca
/// vê a empresa — foi assim entre a v0.0.1 e a v0.0.13.
class EmpresaSyncService {
  EmpresaSyncService(this._client);

  /// Para testes.
  EmpresaSyncService.mock(
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) invocar,
  ) : _invocarMock = invocar,
      _client = null;

  final SupabaseClient? _client;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? _invocarMock;

  static const _timeout = Duration(seconds: 15);

  /// Envia o payload `dados` (jsonb) para a Edge Function. Fire-and-forget do
  /// lado de quem chama — se a rede falhar, a próxima abertura de Definições
  /// pode carregar em "Sincronizar" novamente. Retorna `true` se a EF aceitou.
  Future<bool> sincronizar(Map<String, dynamic> dados) async {
    if (_invocarMock != null) {
      try {
        final r = await _invocarMock!({'dados': dados}).timeout(_timeout);
        return r['ok'] == true;
      } catch (e) {
        debugPrint('EmpresaSyncService.mock falhou: $e');
        return false;
      }
    }
    if (!SupabaseConfig.enabled) return false;
    if (_client == null) return false;
    try {
      final resposta = await _client.functions
          .invoke('sincronizar-empresa-punho', body: {'dados': dados})
          .timeout(_timeout);
      final body = resposta.data;
      if (body is Map && body['ok'] == true) return true;
      debugPrint('sincronizar-empresa-punho resposta inesperada: $body');
      return false;
    } catch (erro) {
      debugPrint('sincronizar-empresa-punho falhou: $erro');
      return false;
    }
  }
}

/// Provider global. Retorna `null` em modo demo (sem Supabase) — o chamador
/// deve tratar isso como "não sincroniza, é modo local".
final empresaSyncProvider = Provider<EmpresaSyncService?>((ref) {
  if (!SupabaseConfig.enabled) return null;
  return EmpresaSyncService(Supabase.instance.client);
});
