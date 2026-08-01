import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/telemetria/pings.dart';

/// A linha que diz ao Control que esta app está viva.
///
/// O Punho já se registava e já validava licença, mas isso acontece uma vez:
/// no Control via-se o terminal e o estado da licença, e nunca o último acesso
/// nem a versão que lá está agora. A tabela `pings` é partilhada com o POS e já
/// distinguia as duas apps pela coluna `app` — só faltava o Punho escrever lá.
void main() {
  late List<Map<String, dynamic>> enviados;
  late PunhoPings pings;

  setUp(() {
    enviados = [];
    pings = PunhoPings.com((linha) async => enviados.add(linha));
  });

  test('identifica-se como punho, e não como pos', () async {
    await pings.enviar(machineId: 'm1', origem: 'arranque');

    // A coluna é `NOT NULL` e partilhada: um ping sem isto ou não entra, ou
    // entra a fingir que é do POS.
    expect(enviados.single['app'], 'punho');
    expect(enviados.single['machine_id'], 'm1');
    expect(enviados.single['origem'], 'arranque');
  });

  test('sem NIF não manda a chave, em vez de mandar vazio', () async {
    // Nos primeiros arranques ainda não há empresa criada. Uma string vazia
    // ficaria no Control indistinguível de um NIF por preencher.
    await pings.enviar(machineId: 'm1', origem: 'arranque');
    expect(enviados.single.containsKey('nif'), isFalse);

    await pings.enviar(machineId: 'm1', origem: 'arranque', nif: '');
    expect(enviados.last.containsKey('nif'), isFalse);
  });

  test('com NIF, leva-o', () async {
    await pings.enviar(machineId: 'm1', origem: 'timer_6h', nif: '501234567');

    expect(enviados.single['nif'], '501234567');
  });

  test('leva o estado dos termos e da licença quando se sabem', () async {
    await pings.enviar(
      machineId: 'm1',
      origem: 'arranque',
      termosAceites: true,
      estadoLicenca: 'activa',
    );

    expect(enviados.single['termos_aceites'], isTrue);
    expect(enviados.single['estado_licenca'], 'activa');
  });

  test('uma falha de rede não sobe ao chamador', () async {
    final rebenta = PunhoPings.com((_) async => throw Exception('sem rede'));

    // Um terminal sem rede continua a ser um terminal que trabalha. Se isto
    // atirasse, o arranque da app ficava dependente da telemetria.
    await expectLater(
      rebenta.enviar(machineId: 'm1', origem: 'arranque'),
      completes,
    );
  });

  test('o intervalo é o mesmo do POS', () {
    // Seis horas: o que se quer saber é "isto continua a ser usado", não o
    // minuto exacto. E o Control conta 120 pings por máquina — a esse ritmo,
    // 30 dias de histórico.
    expect(PunhoPings.intervalo, const Duration(hours: 6));
  });
}
