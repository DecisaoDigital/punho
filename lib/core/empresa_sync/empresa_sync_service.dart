import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'ficha_da_empresa.dart';

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
  /// Traz a ficha da empresa do servidor, se lá houver alguma.
  ///
  /// Durante muito tempo isto só andava num sentido: a app empurrava a ficha e
  /// nunca a lia de volta. Quem trocasse de telemóvel — ou reinstalasse —
  /// tinha os dados no servidor, sessão iniciada, e mesmo assim era recebido
  /// com o onboarding a perguntar-lhe o nome outra vez.
  ///
  /// O RLS já permitia isto desde sempre (`membro vê a própria empresa`);
  /// faltava alguém perguntar. Devolve `null` se não houver ficha, se não
  /// houver rede, ou se a que existe não disser o essencial.
  Future<FichaDaEmpresa?> buscarFicha() async {
    if (!SupabaseConfig.enabled || _client == null) return null;
    try {
      final linha = await _client
          .from('punho_empresas')
          .select('dados')
          // Sem `.eq()`: o RLS já limita à empresa de quem está autenticado, e
          // repetir a condição aqui obrigava a app a saber o id antes de o ter.
          .maybeSingle()
          .timeout(_timeout);
      final dados = linha?['dados'];
      if (dados is! Map) return null;
      final ficha = FichaDaEmpresa.doServidor(Map<String, dynamic>.from(dados));
      return ficha.temOEssencial ? ficha : null;
    } catch (erro) {
      debugPrint('buscarFicha falhou: $erro');
      return null;
    }
  }

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
