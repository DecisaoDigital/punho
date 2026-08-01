import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:punho/core/cadeado/cadeado_gate.dart';
import 'package:punho/core/cadeado/cadeado_service.dart';
import 'package:punho/core/cadeado/lock_screen.dart';
import 'package:punho/core/orientacao/orientacao_do_contexto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O `CadeadoGate` é o orquestrador do cadeado e não tinha um único teste.
///
/// Os dois bugs que o Cesar apanhou no telemóvel viviam exactamente aqui: sair
/// da app e voltar deixou de pedir o PIN, e o ecrã dava voltas entre landscape
/// e retrato enquanto tentava ler a digital. Nenhum era apanhável testando as
/// peças isoladas — é o mecanismo que tem de ser exercitado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rotacoes = <List<String>>[];

  setUp(() {
    rotacoes.clear();
    FlutterSecureStorage.setMockInitialValues({});
    LockScreen.rearmar();
    OrientacaoDoContexto.largarSobreposicao();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
          if (chamada.method == 'SystemChrome.setPreferredOrientations') {
            rotacoes.add(List<String>.from(chamada.arguments as List));
          }
          return null;
        });
  });

  /// `threshold` em minutos: -1 nunca, 0 sempre.
  Future<ProviderContainer> montar(
    WidgetTester tester, {
    required int threshold,
    bool comPin = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'cadeado.threshold_minutes': threshold,
      'cadeado.biometria': false,
    });
    final servico = CadeadoService(auth: _SemBiometria());
    if (comPin) await servico.guardarPin('1234');

    final container = ProviderContainer(
      overrides: [cadeadoServiceProvider.overrideWithValue(servico)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CadeadoGate(child: Scaffold(body: Text('a app'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  bool bloqueado(ProviderContainer c) => c.read(cadeadoBloqueadoProvider);

  Future<void> sairEVoltar(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  group('ciclo de vida', () {
    testWidgets('arranque com PIN definido bloqueia', (tester) async {
      final c = await montar(tester, threshold: 0);

      expect(bloqueado(c), isTrue);
    });

    testWidgets('sem PIN não bloqueia nunca', (tester) async {
      final c = await montar(tester, threshold: 0, comPin: false);

      await sairEVoltar(tester);

      expect(bloqueado(c), isFalse);
    });

    testWidgets('sair e voltar volta a pedir o PIN', (tester) async {
      // O bug do Cesar. O gate ignorava o ciclo de vida enquanto uma marca no
      // serviço estivesse levantada; presa a `true`, desligava o cadeado para
      // sempre.
      final c = await montar(tester, threshold: 0);
      c.read(cadeadoBloqueadoProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(bloqueado(c), isFalse, reason: 'desbloqueou');

      await sairEVoltar(tester);

      expect(bloqueado(c), isTrue);
    });

    testWidgets('volta a bloquear tantas vezes quantas as que se sai', (
      tester,
    ) async {
      // Uma vez não chega: o que falhou foi o cadeado deixar de armar depois
      // do primeiro desbloqueio.
      final c = await montar(tester, threshold: 0);
      for (var volta = 0; volta < 3; volta++) {
        c.read(cadeadoBloqueadoProvider.notifier).state = false;
        await tester.pumpAndSettle();
        await sairEVoltar(tester);
        expect(bloqueado(c), isTrue, reason: 'volta $volta');
      }
    });

    testWidgets('"nunca" não bloqueia ao voltar', (tester) async {
      final c = await montar(tester, threshold: -1);
      c.read(cadeadoBloqueadoProvider.notifier).state = false;
      await tester.pumpAndSettle();

      await sairEVoltar(tester);

      expect(bloqueado(c), isFalse);
    });
  });

  group('orientação', () {
    testWidgets('bloquear e abrir dá uma rotação em cada sentido', (
      tester,
    ) async {
      final c = await montar(tester, threshold: 0);
      expect(
        rotacoes.where((r) => r.length == 1),
        hasLength(1),
        reason: 'uma só ida a retrato ao bloquear',
      );

      rotacoes.clear();
      c.read(cadeadoBloqueadoProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(rotacoes, hasLength(1), reason: 'uma só reposição ao abrir');
    });

    testWidgets('redesenhar com o cadeado à frente não roda nada', (
      tester,
    ) async {
      // É esta a causa das voltas que o Cesar viu: a orientação estava presa ao
      // ciclo de vida do ecrã de bloqueio, que remonta muito mais do que
      // parece. Agora está presa ao estado.
      await montar(tester, threshold: 0);
      rotacoes.clear();

      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(rotacoes, isEmpty);
    });

    testWidgets('a app não aparece antes de se saber se fica bloqueada', (
      tester,
    ) async {
      // A corrida que deixava o Cesar sem entrar pela digital: saber se há PIN
      // é uma leitura de armazenamento, e é assíncrona. A app desenhava o
      // primeiro frame desbloqueada, a shell pedia landscape, o telemóvel
      // rodava — e o cadeado chegava logo a seguir a mandar rodar de volta. O
      // `BiometricPrompt` do Android não sobrevive a essa segunda rotação.
      SharedPreferences.setMockInitialValues({
        'cadeado.threshold_minutes': 0,
        'cadeado.biometria': false,
      });
      final servico = CadeadoService(auth: _SemBiometria());
      await servico.guardarPin('1234');

      final container = ProviderContainer(
        overrides: [cadeadoServiceProvider.overrideWithValue(servico)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CadeadoGate(child: Scaffold(body: Text('a app'))),
          ),
        ),
      );

      // Primeiro frame, antes de a leitura responder.
      expect(
        find.text('a app'),
        findsNothing,
        reason: 'a app apareceu antes de se saber se devia estar bloqueada',
      );
      // Sem filho montado não há quem peça orientação — é daqui que vinha a
      // primeira das duas rotações. Não se afirma aqui sobre `rotacoes` porque
      // o `OrientacaoDoContexto` é estático e arrasta estado entre testes; o
      // que fixa a regressão é o filho não existir.
      await tester.pumpAndSettle();
      expect(find.text('a app'), findsOneWidget);
    });
  });
}

class _SemBiometria implements LocalAuthentication {
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async => false;

  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [];

  @override
  Future<bool> stopAuthentication() async => true;
}
