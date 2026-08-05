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

  OperacaoPendente op(
    String id, {
    String entidade = 'machine',
    String entidadeId = 'm1',
    String nome = 'Mini escavadora',
  }) => OperacaoPendente(
    id: id,
    entidade: entidade,
    entidadeId: entidadeId,
    payload: {'id': entidadeId, 'name': nome},
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

  test('ao encher, comprime em vez de deitar fora', () async {
    // O caso real: um mês na obra sem rede a corrigir as mesmas poucas
    // máquinas. Antes, isto descartava as 5 primeiras em silêncio; agora
    // percebe que são todas a mesma entidade e fica com a última — sem perder
    // uma única alteração do empresário.
    // Num lote só, para a compressão cair sempre no mesmo sítio: a seguir a um
    // `acrescentar` à peça, o que sobra depende de onde o tecto foi passado.
    await registo.acrescentarVarias([
      for (var i = 0; i < RegistoDeOperacoes.maximoNaFila + 5; i++)
        op('op$i', nome: 'Escavadora v$i'),
    ]);

    final fila = registo.pendentes;

    expect(fila, hasLength(1), reason: 'é tudo a mesma máquina');
    expect(
      fila.single.payload['name'],
      'Escavadora v${RegistoDeOperacoes.maximoNaFila + 4}',
      reason:
          'fica a última versão, que contém tudo o que as anteriores diziam',
    );
    expect(registo.operacoesPerdidas, 0, reason: 'comprimir não perde nada');
  });

  test('a compressão respeita a ordem de criação', () async {
    // Se o cliente foi criado antes da reserva que o refere, tem de continuar
    // a sair primeiro — senão o servidor recebe uma reserva órfã.
    await registo.acrescentar(
      op('c1', entidade: 'customer', entidadeId: 'cli1'),
    );
    await registo.acrescentar(
      op('b1', entidade: 'booking', entidadeId: 'res1'),
    );
    await registo.acrescentarVarias([
      for (var i = 0; i < RegistoDeOperacoes.maximoNaFila; i++)
        op('c$i-edit', entidade: 'customer', entidadeId: 'cli1'),
    ]);

    final fila = registo.pendentes;

    expect(fila, hasLength(2));
    expect(fila.first.entidade, 'customer');
    expect(fila.last.entidade, 'booking');
  });

  test(
    'só descarta quando nem comprimida a fila cabe — e regista a perda',
    () async {
      // Entidades todas diferentes: não há nada para comprimir. Aqui há mesmo
      // perda, e o que não pode acontecer é ela passar despercebida.
      await registo.acrescentarVarias([
        for (var i = 0; i < RegistoDeOperacoes.maximoNaFila + 5; i++)
          op('op$i', entidadeId: 'm$i'),
      ]);

      final fila = registo.pendentes;

      expect(fila, hasLength(RegistoDeOperacoes.maximoNaFila));
      expect(fila.first.id, 'op5', reason: 'as cinco primeiras caíram');
      expect(fila.last.id, 'op${RegistoDeOperacoes.maximoNaFila + 4}');
      expect(
        registo.operacoesPerdidas,
        5,
        reason: 'trabalho perdido tem de ficar contado',
      );
    },
  );

  test('a perda persiste entre arranques até ser reconhecida', () async {
    await registo.acrescentarVarias([
      for (var i = 0; i < RegistoDeOperacoes.maximoNaFila + 3; i++)
        op('op$i', entidadeId: 'm$i'),
    ]);

    final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());
    expect(outro.operacoesPerdidas, 3);

    await outro.esquecerPerdas();
    expect(outro.operacoesPerdidas, 0);
  });
}
