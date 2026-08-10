import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/features/gestao/data/pedidos_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **O que se pede ao servidor, e não só o que ele responde.**
///
/// A hipótese "Já está na lista" no ecrã de decisão nunca funcionou. Não havia
/// erro no ecrã, nem no serviço, nem na função do servidor lida à parte: o
/// defeito estava na fronteira entre os dois — a app mandava o id **local** da
/// ficha (`col-do-telemovel-42`) para um parâmetro declarado `uuid`, e o
/// Postgres respondia `22P02` com a mensagem crua à frente do gestor.
///
/// Um teste que só olhasse para a resposta passava com o defeito lá dentro.
/// Estes olham para o corpo do pedido que sai para a rede.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ClienteQueAnotaOCorpo espia;
  late PedidosService servico;

  setUp(() {
    espia = _ClienteQueAnotaOCorpo();
    servico = PedidosService(
      SupabaseClient(
        'https://exemplo.supabase.co',
        'chave',
        httpClient: espia,
      ),
    );
  });

  group('aprovar', () {
    test('manda o id local da ficha tal como a app o conhece', () async {
      await servico.aprovar('ped-1', colaboradorId: 'col-do-telemovel-42');

      expect(espia.corpo['p_pedido_id'], 'ped-1');
      expect(espia.corpo['p_decisao'], 'aprovar');
      // O ponto todo: vai o id local, cru. Traduzi-lo aqui obrigava o cliente
      // a saber a fórmula do servidor — e a ficar preso a ela para sempre.
      expect(espia.corpo['p_colaborador_id'], 'col-do-telemovel-42');
    });

    test('ficha nova continua a ser o id em branco', () async {
      await servico.aprovar('ped-1');

      expect(espia.corpo['p_decisao'], 'aprovar');
      expect(espia.corpo['p_colaborador_id'], isNull);
    });

    test('vai à função do gestor, não à do Control', () async {
      await servico.aprovar('ped-1');

      // `punho_decidir_pedido` é a do admin global e exige `is_admin()`.
      expect(espia.caminho, endsWith('/rpc/punho_gestor_decidir_pedido'));
    });
  });

  group('o caminho de volta', () {
    test('reabrir devolve o pedido à fila', () async {
      await servico.reabrir('ped-1');

      expect(espia.corpo['p_decisao'], 'reabrir');
      expect(espia.corpo['p_pedido_id'], 'ped-1');
    });

    test('revogar tira o acesso a quem o tinha', () async {
      await servico.revogar('ped-1');

      expect(espia.corpo['p_decisao'], 'revogar');
    });

    test('recusar continua a ser recusar', () async {
      await servico.recusar('ped-1');

      expect(espia.corpo['p_decisao'], 'recusar');
    });

    test('os decididos vêm da função própria, não da dos pendentes', () async {
      await servico.decididos();

      // Se lesse `punho_pedidos_da_minha_empresa` trazia só pendentes — e a
      // lista de quem ficou de fora nascia sempre vazia.
      expect(
        espia.caminho,
        endsWith('/rpc/punho_pedidos_decididos_da_minha_empresa'),
      );
    });
  });

  group('como se lê um pedido decidido', () {
    PedidoDecidido comEstado(String estado) => PedidoDecidido.fromJson({
      'pedido_id': 'p1',
      'email': 'joana@empresa.pt',
      'estado': estado,
      'nome': 'Joana',
      'decidido_em': '2026-08-10T09:00:00Z',
    });

    test('quem está de fora é quem tem caminho de volta', () {
      expect(comEstado('recusado').estaDeFora, isTrue);
      expect(comEstado('revogado').estaDeFora, isTrue);
      expect(comEstado('aprovado').estaDeFora, isFalse);
    });

    test('só quem tem acesso o pode perder', () {
      expect(comEstado('aprovado').temAcesso, isTrue);
      expect(comEstado('recusado').temAcesso, isFalse);
    });

    test('o estado é dito em português, não em jargão da base', () {
      expect(comEstado('revogado').comoSeLe, 'Acesso retirado');
      expect(comEstado('recusado').comoSeLe, 'Recusado');
      expect(comEstado('aprovado').comoSeLe, 'Com acesso');
    });

    test('sem nome fica o email — nunca um espaço em branco', () {
      final semNome = PedidoDecidido.fromJson({
        'pedido_id': 'p1',
        'email': 'joana@empresa.pt',
        'estado': 'recusado',
      });

      expect(semNome.comoSeChama, 'joana@empresa.pt');
    });
  });
}

/// Um cliente HTTP que não fala com ninguém: guarda o caminho e o corpo do
/// pedido que sairia para a rede, e devolve uma lista vazia.
class _ClienteQueAnotaOCorpo extends http.BaseClient {
  String caminho = '';
  Map<String, dynamic> corpo = const {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    caminho = request.url.path;
    if (request is http.Request && request.body.isNotEmpty) {
      // Uma RPC sem parâmetros vai com o corpo a `null` — não é um mapa.
      final lido = jsonDecode(request.body);
      corpo = lido is Map<String, dynamic> ? lido : const {};
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
