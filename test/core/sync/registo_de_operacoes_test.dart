import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fila de saída é o que torna a app utilizável sem rede: numa obra não há
/// sinal, e o trabalho não pode ficar à espera dele.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegistoDeOperacoes registo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registo = RegistoDeOperacoes(await SharedPreferences.getInstance());
  });

  OperacaoPendente op(String id, {String entidade = 'machine'}) =>
      OperacaoPendente(
        id: id,
        entidade: entidade,
        entidadeId: 'm1',
        payload: const {'id': 'm1', 'name': 'Mini escavadora'},
        feitoEm: DateTime(2026, 7, 15, 10),
      );

  test('o que entra na fila sai igual', () async {
    await registo.acrescentar(op('a'));

    final fila = registo.pendentes;

    expect(fila, hasLength(1));
    expect(fila.single.id, 'a');
    expect(fila.single.entidade, 'machine');
    expect(fila.single.payload['name'], 'Mini escavadora');
    expect(fila.single.feitoEm, DateTime(2026, 7, 15, 10));
  });

  test('a fila sobrevive a fechar a app', () async {
    await registo.acrescentar(op('a'));
    await registo.acrescentar(op('b'));

    // Uma instância nova, como no arranque seguinte.
    final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());

    expect(outro.pendentes.map((o) => o.id), ['a', 'b']);
  });

  test('só se remove o que o servidor aceitou', () async {
    await registo.acrescentar(op('a'));
    await registo.acrescentar(op('b'));

    await registo.remover({'a'});

    expect(registo.pendentes.map((o) => o.id), ['b']);
  });

  test('uma linha corrompida não bloqueia a fila toda', () async {
    // Sem isto, um registo mal gravado deixava o telemóvel sem conseguir
    // enviar mais nada, para sempre.
    SharedPreferences.setMockInitialValues({
      'punho_sync.fila_v1': ['isto não é json', '{"id":"boa"}'],
    });
    final comLixo = RegistoDeOperacoes(await SharedPreferences.getInstance());

    expect(comLixo.pendentes, isEmpty, reason: 'a segunda também é inválida');
  });

  test('o cursor guarda-se e retoma de onde ficou', () async {
    expect(registo.cursor, 0);

    await registo.guardarCursor(42);
    final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());

    expect(outro.cursor, 42);
  });

  test('o identificador do dispositivo é estável entre arranques', () async {
    // É por ele que o telemóvel sabe ignorar o eco do que foi ele a enviar.
    final primeiro = registo.dispositivo;
    final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());

    expect(outro.dispositivo, primeiro);
  });

  test('a fila tem tecto e descarta as mais antigas', () async {
    // Meses sem rede não podem encher o armazenamento do telemóvel. As antigas
    // são as que já foram substituídas por edições posteriores.
    for (var i = 0; i < RegistoDeOperacoes.maximoNaFila + 5; i++) {
      await registo.acrescentar(op('op$i'));
    }

    final fila = registo.pendentes;

    expect(fila, hasLength(RegistoDeOperacoes.maximoNaFila));
    expect(fila.first.id, 'op5', reason: 'as cinco primeiras caíram');
    expect(fila.last.id, 'op${RegistoDeOperacoes.maximoNaFila + 4}');
  });
}
