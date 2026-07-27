import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o arranque pede landscape e só landscape', () async {
    final chamadas = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
          chamadas.add(chamada);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await bloquearLandscape();

    final orientacoes = chamadas.firstWhere(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(orientacoes.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    // Portrait não é suportado: o painel de 4 KPIs lado a lado não cabe.
    expect(
      orientacoes.arguments,
      isNot(contains('DeviceOrientation.portraitUp')),
    );
  });
}
