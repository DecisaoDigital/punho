import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/orientacao/orientacao_do_contexto.dart';

/// O cadeado impõe retrato por cima de um shell que está em landscape e tem de
/// devolver o landscape ao sair. Sem memória da escolha anterior, desbloquear
/// deixava a app de pé — o `initState` do shell não volta a correr.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pedidos = <List<String>>[];

  setUp(() {
    pedidos.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
          if (chamada.method == 'SystemChrome.setPreferredOrientations') {
            pedidos.add(List<String>.from(chamada.arguments as List));
          }
          return null;
        });
  });

  test('guarda a última escolha', () async {
    await OrientacaoDoContexto.forcarLandscape();
    expect(OrientacaoDoContexto.actual, Orientacao.landscape);

    await OrientacaoDoContexto.forcarPortrait();
    expect(OrientacaoDoContexto.actual, Orientacao.portrait);

    await OrientacaoDoContexto.libertar();
    expect(OrientacaoDoContexto.actual, Orientacao.livre);
  });

  test('portrait pede só portraitUp', () async {
    await OrientacaoDoContexto.forcarPortrait();

    expect(pedidos.single, ['DeviceOrientation.portraitUp']);
  });

  test('landscape pede os dois lados', () async {
    await OrientacaoDoContexto.forcarLandscape();

    expect(pedidos.single, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  test('repor devolve exactamente o que o ecrã de baixo tinha', () async {
    // A sequência do cadeado: o shell manda deitar, o cadeado guarda, impõe
    // retrato, e ao desbloquear repõe.
    await OrientacaoDoContexto.forcarLandscape();
    final anterior = OrientacaoDoContexto.actual;

    await OrientacaoDoContexto.forcarPortrait();
    await OrientacaoDoContexto.aplicar(anterior);

    expect(OrientacaoDoContexto.actual, Orientacao.landscape);
    expect(pedidos.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });
}
