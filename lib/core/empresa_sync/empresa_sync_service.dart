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

  /// Envia a ficha e diz **porquê** correu mal, quando corre mal.
  ///
  /// Um `bool` não chegava: "falhou" tanto podia ser sem rede (tentar outra
  /// vez) como dados inválidos (nunca vai passar). Sem a distinção, a app
  /// tratava tudo como temporário e insistia para sempre.
  Future<ResultadoDaFicha> sincronizar(Map<String, dynamic> dados) async {
    if (_invocarMock != null) {
      try {
        final r = await _invocarMock!({'dados': dados}).timeout(_timeout);
        if (r['ok'] == true) return const ResultadoDaFicha.entregue();
        final erro = r['error'] ?? r['erro'];
        return erro == null
            ? const ResultadoDaFicha.adiada()
            : ResultadoDaFicha.recusada('$erro');
      } catch (e) {
        debugPrint('EmpresaSyncService.mock falhou: $e');
        return const ResultadoDaFicha.adiada();
      }
    }
    if (!SupabaseConfig.enabled) return const ResultadoDaFicha.adiada();
    if (_client == null) return const ResultadoDaFicha.adiada();
    try {
      final resposta = await _client.functions
          .invoke('sincronizar-empresa-punho', body: {'dados': dados})
          .timeout(_timeout);
      final body = resposta.data;
      if (body is Map && body['ok'] == true) {
        return const ResultadoDaFicha.entregue();
      }
      debugPrint('sincronizar-empresa-punho resposta inesperada: $body');
      // Resposta com erro nomeado = a função percebeu o pedido e recusou-o.
      // Insistir com o mesmo conteúdo dá sempre o mesmo — foi assim que o
      // `nif_invalido` ficou preso a reenviar de 20 em 20 minutos.
      if (body is Map && (body['error'] ?? body['erro']) != null) {
        return ResultadoDaFicha.recusada('${body['error'] ?? body['erro']}');
      }
      return const ResultadoDaFicha.adiada();
    } on FunctionException catch (erro) {
      // 4xx é "os dados estão mal"; 5xx é "o servidor está mal". Só o primeiro
      // é definitivo — o segundo passa.
      final detalhe = erro.details;
      final motivo = detalhe is Map
          ? '${detalhe['error'] ?? detalhe['erro'] ?? erro.status}'
          : '${erro.status}';
      debugPrint('sincronizar-empresa-punho recusou (${erro.status}): $motivo');
      return erro.status >= 400 && erro.status < 500
          ? ResultadoDaFicha.recusada(motivo)
          : const ResultadoDaFicha.adiada();
    } catch (erro) {
      debugPrint('sincronizar-empresa-punho falhou: $erro');
      return const ResultadoDaFicha.adiada();
    }
  }
}

/// Como correu a entrega da ficha da empresa ao Control.
///
/// A distinção que faltava: **adiada** volta a ser tentada, **recusada** não.
class ResultadoDaFicha {
  const ResultadoDaFicha.entregue() : recusa = null, entregou = true;

  /// Sem rede, servidor em baixo, timeout. Vale a pena insistir.
  const ResultadoDaFicha.adiada() : recusa = null, entregou = false;

  /// O servidor percebeu o pedido e disse que não. Insistir com o mesmo
  /// conteúdo dá sempre o mesmo resultado.
  const ResultadoDaFicha.recusada(String this.recusa) : entregou = false;

  final bool entregou;
  final String? recusa;

  bool get foiRecusada => recusa != null;
}

/// Provider global. Retorna `null` em modo demo (sem Supabase) — o chamador
/// deve tratar isso como "não sincroniza, é modo local".
final empresaSyncProvider = Provider<EmpresaSyncService?>((ref) {
  if (!SupabaseConfig.enabled) return null;
  return EmpresaSyncService(Supabase.instance.client);
});
