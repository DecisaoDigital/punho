import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:punho/features/contabilista/data/contabilista_service.dart';
import 'package:punho/features/leads/data/leads_entrada_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **As leituras que crescem com o cliente levam tecto — e prova-se no pedido.**
///
/// Achado 5.2 da auditoria de 11/8: dez sítios a chamar `.select()` sem limite.
/// Sete não eram nada — dois eram `select` do Riverpod, o sincronizador de
/// operações já tem cursor e lote, e os catálogos são pequenos por desenho.
/// Ficaram três leituras que só crescem: a conversa com o contabilista, a caixa
/// de entrada de leads e a lista de convites.
///
/// Estes testes olham para o **pedido que sai**, não para a resposta que entra,
/// pela mesma razão que o `cursor_na_consulta_test.dart` existe: um teste que
/// devolve três linhas de mentira passa na mesma com o `limit` esquecido. O que
/// se afirma aqui é que o tecto chega ao servidor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ClienteQueAnota espia;
  late SupabaseClient cliente;

  setUp(() {
    espia = _ClienteQueAnota();
    cliente = SupabaseClient(
      'https://exemplo.supabase.co',
      'chave',
      httpClient: espia,
    );
  });

  test(
    'a conversa com o contabilista pede tecto e a mais recente primeiro',
    () async {
      await SupabaseContabilistaService(cliente).mensagens();

      expect(espia.caminho, endsWith('/punho_mensagens_contabilista'));
      expect(espia.consulta['limit'], '500');
      expect(espia.consulta['order'], contains('criado_em'));
      expect(espia.consulta['order'], contains('desc'));
    },
  );

  test(
    'a caixa de entrada de leads pede tecto, e a mais antiga primeiro',
    () async {
      await LeadsEntradaService(cliente).porProcessar();

      expect(espia.caminho, endsWith('/punho_leads_entrada'));
      expect(espia.consulta['limit'], '200');
      // Da mais antiga para a mais nova: é o que faz o tecto não perder nada —
      // o que fica de fora volta a aparecer quando as primeiras saírem da fila.
      expect(espia.consulta['order'], contains('recebida_em'));
      expect(espia.consulta['order'], isNot(contains('desc')));
    },
  );

  test('a lista de convites pede tecto', () async {
    await SupabaseAcessoService(cliente).listarConvites();

    expect(espia.caminho, endsWith('/punho_convites'));
    expect(espia.consulta['limit'], '200');
    expect(espia.consulta['order'], contains('criado_em'));
  });

  test('o catálogo de rubricas continua a vir inteiro', () async {
    // Contraprova. O catálogo tem umas dezenas de linhas e é fechado por
    // desenho — pôr-lhe tecto seria esconder rubricas ao contabilista para
    // resolver um problema que ele não tem.
    await SupabaseContabilistaService(cliente).catalogo();

    expect(espia.caminho, endsWith('/punho_rubricas_contabilista'));
    expect(espia.consulta.containsKey('limit'), isFalse);
  });
}

/// Um cliente HTTP que não fala com ninguém: guarda o caminho e a consulta do
/// pedido que sairia para a rede.
class _ClienteQueAnota extends http.BaseClient {
  String caminho = '';
  Map<String, String> consulta = const {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    caminho = request.url.path;
    consulta = request.url.queryParameters;
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
