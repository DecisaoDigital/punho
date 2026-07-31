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

  test('sair da sobreposição devolve o que o ecrã de baixo pediu', () async {
    await OrientacaoDoContexto.forcarLandscape();

    await OrientacaoDoContexto.sobrepor(Orientacao.portrait);
    expect(OrientacaoDoContexto.actual, Orientacao.portrait);

    await OrientacaoDoContexto.largarSobreposicao();

    expect(OrientacaoDoContexto.actual, Orientacao.landscape);
    expect(pedidos.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  test(
    'um ecrã que decide com o cadeado à frente não roda por baixo',
    () async {
      // É este o bug da v0.0.18. No arranque com cadeado, quem está montado
      // quando o ecrã de bloqueio aparece é o AuthGate (retrato). O AppShell só
      // monta quando o acesso resolve, muitas vezes já com o cadeado à frente —
      // e é ele que pede landscape.
      await OrientacaoDoContexto.forcarPortrait();
      await OrientacaoDoContexto.sobrepor(Orientacao.portrait);
      pedidos.clear();

      // O AppShell monta por baixo e pede landscape.
      await OrientacaoDoContexto.forcarLandscape();

      // Nada foi pedido ao sistema: o cadeado está à frente e não pode rodar.
      expect(pedidos, isEmpty);

      await OrientacaoDoContexto.largarSobreposicao();

      // Ao desbloquear, vale o que o AppShell pediu enquanto esteve tapado.
      expect(OrientacaoDoContexto.actual, Orientacao.landscape);
      expect(pedidos.single, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    },
  );

  test('largar sem sobreposição activa não mexe em nada', () async {
    await OrientacaoDoContexto.forcarLandscape();
    pedidos.clear();

    await OrientacaoDoContexto.largarSobreposicao();

    expect(pedidos, isEmpty);
    expect(OrientacaoDoContexto.actual, Orientacao.landscape);
  });
}
