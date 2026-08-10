import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:punho/core/sync/sincronizacao_entre_dispositivos.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **Uma operação que o servidor recusa não pode prender as boas que vão a
/// seguir.**
///
/// `quarentena_test.dart` prova a classificação dos códigos e os baldes de
/// forma isolada — mas salta o motor. Este não o salta: põe o
/// [SincronizacaoEntreDispositivos] a sincronizar contra um servidor de mentira
/// que recusa uma marcação a meio do lote, e vai ver o que fica.
///
/// Reproduz o que se via na Faixa D: um lote inteiro falhava por causa de uma
/// linha só, nada saía da fila, e a app reenviava tudo a cada ciclo. Aqui o
/// lote rebenta na linha má (Postgres é transaccional), o motor passa a enviar
/// **uma a uma**, as boas sobem, e a recusada arruma-se no balde certo — o
/// visível para `23P01`, a quarentena silenciosa para `42501`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OperacaoPendente marcacao(String id) => OperacaoPendente(
    id: id,
    entidade: 'booking',
    entidadeId: id,
    payload: {'id': id},
    feitoEm: DateTime(2026, 8, 10, 9),
  );

  /// Monta motor + registo com um servidor que recusa [idMau] com [codigo].
  Future<
    ({
      SincronizacaoEntreDispositivos motor,
      RegistoDeOperacoes registo,
      _ServidorFalso servidor,
    })
  >
  montar(String idMau, String codigo) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registo = RegistoDeOperacoes(prefs);
    final servidor = _ServidorFalso(recusa: {idMau: codigo});
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

  test('23P01 a meio do lote vai para o balde de conflitos; as boas passam', () async {
    final m = await montar('res-2', '23P01');
    await m.registo.acrescentar(marcacao('res-1'));
    await m.registo.acrescentar(marcacao('res-2')); // a máquina já reservada
    await m.registo.acrescentar(marcacao('res-3'));

    final resultado = await m.motor.sincronizar();

    // A sincronização correu — não estoirou por causa da linha má.
    expect(resultado.correu, isTrue);
    expect(resultado.enviadas, 2, reason: 'as duas boas subiram');
    // O lote foi tentado inteiro, falhou, e depois foi uma a uma (3 tentativas).
    expect(m.servidor.upserts.first, ['res-1', 'res-2', 'res-3']);
    expect(m.servidor.upserts.length, 4);
    // A fila esvaziou — nada fica a bater à porta do servidor para sempre.
    expect(m.registo.pendentes, isEmpty);
    // A recusada foi para o balde visível, não para a quarentena silenciosa.
    expect(m.registo.conflitosDeReserva.map((c) => c.operacao.id), ['res-2']);
    expect(m.registo.quarentena, isEmpty, reason: 'não é lixo de payload');
  });

  test('42501 (RLS) a meio do lote vai para a quarentena; as boas passam', () async {
    final m = await montar('res-2', '42501');
    await m.registo.acrescentar(marcacao('res-1'));
    await m.registo.acrescentar(marcacao('res-2')); // política recusa
    await m.registo.acrescentar(marcacao('res-3'));

    final resultado = await m.motor.sincronizar();

    expect(resultado.correu, isTrue);
    expect(resultado.enviadas, 2);
    expect(m.registo.pendentes, isEmpty);
    // Recusa de permissão é definitiva: quarentena, e não o balde de conflitos.
    expect(m.registo.quarentena.map((q) => q.operacao.id), ['res-2']);
    expect(m.registo.conflitosDeReserva, isEmpty);
  });

  test('a frase do servidor chega inteira à quarentena', () async {
    // O servidor fala português e fala para uma pessoa: «Não podes alterar o
    // preço por dia da máquina. Isso é do gestor.» Se o cliente guardar só
    // «42501», a Fase 5 não tem nada para mostrar e quem usa a app fica sem
    // saber o que fez de errado.
    final m = await montar('res-2', '42501');
    m.servidor.frase =
        'Não podes alterar o preço por dia da máquina. Isso é do gestor.';
    await m.registo.acrescentar(marcacao('res-1'));
    await m.registo.acrescentar(marcacao('res-2'));

    await m.motor.sincronizar();

    final recusada = m.registo.quarentena.single;
    expect(recusada.codigo, '42501');
    expect(
      recusada.mensagemDoServidor,
      'Não podes alterar o preço por dia da máquina. Isso é do gestor.',
    );
    expect(
      recusada.paraPessoa,
      isNot(contains('42501')),
      reason: 'à pessoa mostra-se a frase, não o SQLSTATE',
    );
    // O motivo colado continua lá para quem estiver a depurar.
    expect(recusada.motivo, contains('42501'));
  });

  test('uma recusa que esta versão não conhece também sai da fila', () async {
    // O que a lista fechada fazia mal: um código novo do servidor prendia a
    // fila para sempre. Agora é definitivo por natureza, sem ninguém ter de o
    // acrescentar a lado nenhum.
    final m = await montar('res-2', '23Z01');
    await m.registo.acrescentar(marcacao('res-1'));
    await m.registo.acrescentar(marcacao('res-2'));
    await m.registo.acrescentar(marcacao('res-3'));

    final resultado = await m.motor.sincronizar();

    expect(resultado.enviadas, 2);
    expect(m.registo.pendentes, isEmpty, reason: 'a fila não ficou trancada');
    expect(m.registo.quarentena.map((q) => q.operacao.id), ['res-2']);
  });
}

/// Um servidor de mentira: responde `[]` ao que se pede (receber) e, ao que se
/// grava (upsert), recusa as linhas cujo `id` está em [recusa] — com o código
/// SQLSTATE indicado. Como Postgres, um lote que contenha uma linha recusada
/// rebenta inteiro.
class _ServidorFalso extends http.BaseClient {
  _ServidorFalso({required this.recusa});

  /// `id` da operação → código com que o servidor a recusa (`23P01`, `42501`…).
  final Map<String, String> recusa;

  /// O que o servidor diz, por palavras dele. É isto que tem de sobreviver até
  /// à quarentena.
  String? frase;

  /// Os lotes de ids que chegaram a cada upsert, pela ordem em que chegaram.
  final List<List<String>> upserts = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') {
      return _resposta(request, 200, '[]'); // nada de novo para receber
    }
    final corpo = request is http.Request ? request.body : '';
    final linhas = (jsonDecode(corpo) as List).cast<Map<String, dynamic>>();
    final ids = [for (final l in linhas) l['id'] as String];
    upserts.add(ids);
    for (final id in ids) {
      final codigo = recusa[id];
      if (codigo != null) return _recusa(request, codigo);
    }
    return _resposta(request, 201, '[]');
  }

  http.StreamedResponse _recusa(http.BaseRequest request, String codigo) =>
      _resposta(
        request,
        // O código vem do corpo; o estado é só realista (409 conflito, 403 RLS).
        codigo == '23P01' ? 409 : 403,
        jsonEncode({
          'code': codigo,
          'message': frase ?? 'linha recusada pelo servidor ($codigo)',
          'details': null,
          'hint': null,
        }),
      );

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
