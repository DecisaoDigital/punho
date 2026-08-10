import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:punho/core/sync/sincronizacao_entre_dispositivos.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **A armadilha da inversão.**
///
/// Ao passar de «lista fechada de códigos definitivos» para «tudo o que traz
/// decisão do servidor é definitivo», há um erro que muda de lado sem se dar
/// por isso: o **token expirado**. Vem numa `PostgrestException`, como as
/// outras, e se for classificado por conteúdo manda a fila **inteira** para a
/// quarentena de uma assentada — o trabalho de um dia numa obra sem rede,
/// perdido em silêncio e sem forma de o recuperar.
///
/// Por isso este teste existe à parte e corre primeiro: a sessão renova-se e
/// repete-se, e não se perde uma única operação.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OperacaoPendente op(String id) => OperacaoPendente(
    id: id,
    entidade: 'booking',
    entidadeId: id,
    payload: {'id': id},
    feitoEm: DateTime(2026, 8, 10, 9),
  );

  Future<
    ({
      SincronizacaoEntreDispositivos motor,
      RegistoDeOperacoes registo,
      _ServidorComSessao servidor,
    })
  >
  montar({required int recusasDeSessao}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registo = RegistoDeOperacoes(prefs);
    final servidor = _ServidorComSessao(recusasDeSessao: recusasDeSessao);
    final motor = SincronizacaoEntreDispositivos(
      repositorio: await PersistentOperationRepository.create(),
      registo: registo,
      cliente: SupabaseClient(
        'https://exemplo.supabase.co',
        'chave',
        httpClient: servidor,
      ),
      empresaId: 'e1',
    );
    return (motor: motor, registo: registo, servidor: servidor);
  }

  test('PGRST301 (JWT expirado) renova a sessão e reenvia tudo', () async {
    final m = await montar(recusasDeSessao: 1);
    var renovacoes = 0;
    m.motor.renovarSessao = () async {
      renovacoes++;
      m.servidor.sessaoBoa = true;
      return true;
    };
    await m.registo.acrescentar(op('res-1'));
    await m.registo.acrescentar(op('res-2'));
    await m.registo.acrescentar(op('res-3'));

    final resultado = await m.motor.sincronizar();

    expect(renovacoes, 1, reason: 'renovou uma vez, não em ciclo');
    expect(resultado.enviadas, 3, reason: 'nada se perdeu pelo caminho');
    expect(m.registo.pendentes, isEmpty);
    // O que este teste existe para provar:
    expect(
      m.registo.quarentena,
      isEmpty,
      reason: 'um token expirado NUNCA é recusa de conteúdo',
    );
    expect(m.registo.conflitosDeReserva, isEmpty);
  });

  test('401 sem corpo também é sessão, não conteúdo', () async {
    final m = await montar(recusasDeSessao: 1);
    m.motor.renovarSessao = () async {
      m.servidor.sessaoBoa = true;
      return true;
    };
    m.servidor.comCorpo = false;
    await m.registo.acrescentar(op('res-1'));

    await m.motor.sincronizar();

    expect(m.registo.quarentena, isEmpty);
    expect(m.registo.pendentes, isEmpty);
  });

  test('se a renovação falhar, a fila fica intacta — não vai para a quarentena',
      () async {
    final m = await montar(recusasDeSessao: 99); // nunca melhora
    m.motor.renovarSessao = () async => false; // e não se consegue renovar
    await m.registo.acrescentar(op('res-1'));
    await m.registo.acrescentar(op('res-2'));

    final resultado = await m.motor.sincronizar();

    expect(resultado.correu, isFalse, reason: 'a sincronização não passou');
    expect(
      m.registo.pendentes.map((o) => o.id),
      ['res-1', 'res-2'],
      reason: 'fica tudo para a próxima, com sessão boa',
    );
    expect(m.registo.quarentena, isEmpty);
  });

  test('renovação por ciclo: um servidor sempre a 401 não põe isto em roda '
      'livre', () async {
    final m = await montar(recusasDeSessao: 99);
    var renovacoes = 0;
    m.motor.renovarSessao = () async {
      renovacoes++;
      return true; // diz que renovou, mas o servidor continua a recusar
    };
    await m.registo.acrescentar(op('res-1'));

    await m.motor.sincronizar();

    expect(renovacoes, 1, reason: 'uma renovação por ciclo e mais nada');
    expect(m.registo.pendentes, hasLength(1));
    expect(m.registo.quarentena, isEmpty);

    // O ciclo seguinte tem direito à sua tentativa.
    await m.motor.sincronizar();
    expect(renovacoes, 2);
  });
}

/// Servidor que recusa as primeiras [recusasDeSessao] escritas com JWT
/// expirado, e aceita a partir do momento em que [sessaoBoa] passa a `true`.
class _ServidorComSessao extends http.BaseClient {
  _ServidorComSessao({required this.recusasDeSessao});

  final int recusasDeSessao;
  bool sessaoBoa = false;
  bool comCorpo = true;
  int recusadas = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') return _resposta(request, 200, '[]');
    if (!sessaoBoa && recusadas < recusasDeSessao) {
      recusadas++;
      return _resposta(
        request,
        401,
        comCorpo
            ? jsonEncode({
                'code': 'PGRST301',
                'message': 'JWT expired',
                'details': null,
                'hint': null,
              })
            : '',
      );
    }
    return _resposta(request, 201, '[]');
  }

  http.StreamedResponse _resposta(
    http.BaseRequest request,
    int status,
    String corpo,
  ) => http.StreamedResponse(
    Stream.value(utf8.encode(corpo)),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}
