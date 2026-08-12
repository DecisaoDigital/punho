import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **O travão do convite tem de chegar a quem está a escrever o código.**
///
/// Achado 3.5: o `punho_validar_convite` é a única função ainda executável pelo
/// anónimo, porque é chamada antes de haver sessão. Ganhou um limite de
/// tentativas por origem, e com ele um estado novo — `bloqueado`.
///
/// O caso que interessa é o que **não** se vê num teste de servidor: se a app
/// não conhecer o estado novo, o `_ =>` do `switch` engole-o como `invalido` e
/// o utilizador lê «código de convite inválido» quando o código está bom. Ia
/// pedir um convite novo ao gestor, o novo também não passava, e ninguém
/// perceberia porquê.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ValidacaoConvite> comRespostaDoServidor(String estado) async {
    final cliente = SupabaseClient(
      'https://exemplo.supabase.co',
      'chave',
      httpClient: _ClienteQueResponde(estado),
    );
    return SupabaseAcessoService(cliente).validarConvite('SEJA-O-QUE-FOR');
  }

  test('bloqueado não é confundido com inválido', () async {
    expect(
      await comRespostaDoServidor('bloqueado'),
      ValidacaoConvite.bloqueado,
    );
  });

  test('os outros estados continuam a ser lidos como antes', () async {
    expect(await comRespostaDoServidor('valido'), ValidacaoConvite.valido);
    expect(await comRespostaDoServidor('expirado'), ValidacaoConvite.expirado);
    expect(await comRespostaDoServidor('usado'), ValidacaoConvite.usado);
    expect(await comRespostaDoServidor('invalido'), ValidacaoConvite.invalido);
  });

  test('um estado que a app não conheça continua a cair em inválido', () async {
    // A rede de segurança tem de ficar: um servidor mais novo do que a app não
    // pode fazer o ecrã de registo rebentar.
    expect(
      await comRespostaDoServidor('coisa-que-ainda-nao-existe'),
      ValidacaoConvite.invalido,
    );
  });

  test('bloqueado diz o que fazer, e não fala de limites', () {
    final texto = ValidacaoConvite.bloqueado.mensagem!;
    expect(texto, contains('15 minutos'));
    // Quem lê isto não fez nada de mal — na maioria dos casos está só a
    // partilhar a rede. A mensagem não pode soar a acusação.
    expect(texto.toLowerCase(), isNot(contains('excedeu')));
    expect(texto.toLowerCase(), isNot(contains('inválido')));
  });

  test('todos os estados têm mensagem, menos o válido', () {
    for (final estado in ValidacaoConvite.values) {
      if (estado == ValidacaoConvite.valido) {
        expect(estado.mensagem, isNull);
      } else {
        expect(
          estado.mensagem,
          isNotNull,
          reason: '$estado ficou sem nada para dizer ao utilizador',
        );
      }
    }
  });
}

/// Responde sempre o mesmo estado, sem falar com ninguém.
class _ClienteQueResponde extends http.BaseClient {
  _ClienteQueResponde(this.estado);
  final String estado;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(estado))),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
}
