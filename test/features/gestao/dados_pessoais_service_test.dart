import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/features/gestao/data/dados_pessoais_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **Um apagamento tem de apagar mesmo — e não pode aceitar de onde.**
///
/// Duas coisas se afirmam aqui, e ambas sobre o pedido que sai para a rede:
///
/// 1. A empresa **não vai** no corpo. Sai da sessão, no servidor. Um cliente
///    que a pudesse dizer podia apagar dados de outra empresa — e a função do
///    servidor recusaria, mas o cliente não devia sequer tentar.
///
/// 2. A leitura do histórico leva limite. É uma lista que só cresce, e um ecrã
///    que a peça toda fica mais lento a cada apagamento que se faz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ClienteQueAnota espia;
  late DadosPessoaisService servico;

  setUp(() {
    espia = _ClienteQueAnota();
    servico = DadosPessoaisService(
      SupabaseClient('https://exemplo.supabase.co', 'chave', httpClient: espia),
    );
  });

  group('procurar', () {
    test('manda o termo para a função de procura', () async {
      await servico.procurar('Casa Ferreira');

      expect(espia.caminho, endsWith('/rpc/punho_procurar_titular'));
      expect(espia.corpo['p_termo'], 'Casa Ferreira');
    });

    test('não manda empresa nenhuma — quem a sabe é o servidor', () async {
      await servico.procurar('Casa Ferreira');

      expect(espia.corpo.keys, ['p_termo']);
    });
  });

  group('apagar', () {
    setUp(() {
      espia.resposta = jsonEncode({
        'ok': true,
        'operacoes_redigidas': 3,
        'reservas_no_log_redigidas': 3,
        'reservas_projectadas_redigidas': 2,
      });
    });

    test('vai à função de apagamento com quem apagar e porquê', () async {
      await servico.apagar(
        entidade: 'customer',
        entidadeId: 'cli-prova-998368',
        motivo: 'pedido do titular',
      );

      expect(espia.caminho, endsWith('/rpc/punho_apagar_titular'));
      expect(espia.corpo['p_entidade'], 'customer');
      expect(espia.corpo['p_entidade_id'], 'cli-prova-998368');
      expect(espia.corpo['p_motivo'], 'pedido do titular');
    });

    test('a empresa continua a não ir no corpo', () async {
      await servico.apagar(entidade: 'lead', entidadeId: 'lead-9');

      expect(
        espia.corpo.keys.any((k) => k.contains('empresa')),
        isFalse,
        reason: 'a empresa sai da sessão, nunca do pedido',
      );
    });

    test('conta os registos que ficaram sem dados pessoais', () async {
      final linhas = await servico.apagar(
        entidade: 'customer',
        entidadeId: 'cli-1',
      );

      // 3 operações redigidas + 2 reservas projectadas.
      expect(linhas, 5);
    });
  });

  group('histórico', () {
    test('pede o que já foi apagado com limite', () async {
      await servico.feitos();

      expect(espia.caminho, endsWith('/punho_apagamentos'));
      expect(espia.consulta['limit'], '50');
      expect(espia.consulta['order'], contains('feito_em'));
    });
  });

  group('como se lê uma ficha', () {
    FichaDeTitular ficha(Map<String, dynamic> extra) =>
        FichaDeTitular.fromJson({
          'entidade': 'customer',
          'entidade_id': 'cli-1',
          'revisoes': 3,
          'ja_apagado': false,
          ...extra,
        });

    test('sem nome mostra-se o id — nunca um espaço em branco', () {
      expect(ficha({'nome': null}).comoSeChama, 'Ficha sem nome (cli-1)');
      expect(ficha({'nome': '   '}).comoSeChama, 'Ficha sem nome (cli-1)');
    });

    test('o que a ficha é diz-se em português, não em jargão da base', () {
      expect(ficha({}).oQueE, 'Cliente');
      expect(
        FichaDeTitular.fromJson({
          'entidade': 'collaborator',
          'entidade_id': 'c1',
        }).oQueE,
        'Empregado',
      );
      expect(
        FichaDeTitular.fromJson({
          'entidade': 'lead',
          'entidade_id': 'l1',
        }).oQueE,
        'Contacto',
      );
    });
  });

  group('como se lê um apagamento feito', () {
    test('as linhas são as duas contagens somadas', () {
      final feito = ApagamentoFeito.fromJson({
        'entidade': 'customer',
        'entidade_id': 'cli-1',
        'operacoes_redigidas': 6,
        'reservas_redigidas': 2,
        'feito_em': '2026-08-11T09:30:00Z',
      });

      expect(feito.linhas, 8);
    });
  });
}

/// Um cliente HTTP que não fala com ninguém: guarda o caminho, a consulta e o
/// corpo do pedido que sairia para a rede.
class _ClienteQueAnota extends http.BaseClient {
  String caminho = '';
  Map<String, dynamic> corpo = const {};
  Map<String, String> consulta = const {};
  String resposta = '[]';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    caminho = request.url.path;
    consulta = request.url.queryParameters;
    if (request is http.Request && request.body.isNotEmpty) {
      final lido = jsonDecode(request.body);
      corpo = lido is Map<String, dynamic> ? lido : const {};
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(resposta)),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
