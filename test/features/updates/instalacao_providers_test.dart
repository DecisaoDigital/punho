import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/orientacao/orientacao_do_contexto.dart';
import 'package:punho/core/updates/instalador_de_update.dart';
import 'package:punho/features/updates/instalacao_providers.dart';

/// O ecrã do Android para instalar — e o scan do Play Protect que o precede
/// na primeira vez — não está preparado para landscape: os botões de
/// confirmação ficam fora do ecrã e o gestor fica sem forma de os tocar.
/// Aconteceu a sério (v0.1.6, telemóvel do Cesar), no shell do gestor que a
/// Decisão 13 manda ficar em landscape.
class _InstaladorFalso extends InstaladorDeUpdate {
  _InstaladorFalso({this.resultado = 'pediu_confirmacao'});

  final String? resultado;
  final chamadas = <String>[];

  @override
  Future<bool> podeInstalar() async => true;

  @override
  Future<void> pedirPermissao() async {}

  @override
  Future<String?> instalar(String caminho) async {
    chamadas.add(caminho);
    return resultado;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rotacoes = <List<String>>[];

  setUp(() {
    rotacoes.clear();
    OrientacaoDoContexto.largarSobreposicao();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
          if (chamada.method == 'SystemChrome.setPreferredOrientations') {
            rotacoes.add(List<String>.from(chamada.arguments as List));
          }
          return null;
        });
  });

  ProviderContainer montar(WidgetTester tester, _InstaladorFalso instalador) {
    final container = ProviderContainer(
      overrides: [instaladorProvider.overrideWithValue(instalador)],
    );
    addTearDown(container.dispose);
    // Só para o `WidgetsBindingObserver` do controlador ter um binding activo
    // por trás — o próprio teste não olha para o que aqui se desenha.
    tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    return container;
  }

  testWidgets(
    'instalar força retrato antes de entregar o ficheiro ao Android',
    (tester) async {
      final instalador = _InstaladorFalso();
      final container = montar(tester, instalador);
      final notifier = container.read(estadoDoUpdateProvider.notifier);
      notifier.state = const EstadoDoUpdate(
        fase: FaseDoUpdate.pronta,
        caminho: '/tmp/punho.apk',
      );

      await notifier.instalar();

      expect(instalador.chamadas, ['/tmp/punho.apk']);
      expect(rotacoes, isNotEmpty);
      expect(rotacoes.last, ['DeviceOrientation.portraitUp']);
      expect(
        container.read(estadoDoUpdateProvider).fase,
        FaseDoUpdate.aguardaConfirmacao,
      );
    },
  );

  testWidgets(
    'voltar à app sem confirmar devolve a orientação e deixa tentar outra vez',
    (tester) async {
      final instalador = _InstaladorFalso();
      final container = montar(tester, instalador);
      final notifier = container.read(estadoDoUpdateProvider.notifier);
      notifier.state = const EstadoDoUpdate(
        fase: FaseDoUpdate.pronta,
        caminho: '/tmp/punho.apk',
      );
      await notifier.instalar();
      expect(
        container.read(estadoDoUpdateProvider).fase,
        FaseDoUpdate.aguardaConfirmacao,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      final estado = container.read(estadoDoUpdateProvider);
      expect(estado.fase, FaseDoUpdate.pronta);
      expect(estado.caminho, '/tmp/punho.apk');
      expect(rotacoes.last, isNot(['DeviceOrientation.portraitUp']));
    },
  );

  testWidgets('falha ao entregar o ficheiro também devolve a orientação', (
    tester,
  ) async {
    final instalador = _InstaladorFalso(resultado: null);
    final container = montar(tester, instalador);
    final notifier = container.read(estadoDoUpdateProvider.notifier);
    notifier.state = const EstadoDoUpdate(
      fase: FaseDoUpdate.pronta,
      caminho: '/tmp/punho.apk',
    );

    await notifier.instalar();

    expect(container.read(estadoDoUpdateProvider).fase, FaseDoUpdate.falhou);
    expect(rotacoes.last, isNot(['DeviceOrientation.portraitUp']));
  });
}
