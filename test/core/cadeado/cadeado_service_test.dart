import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:punho/core/cadeado/cadeado_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O cadeado entrou na v0.0.15 sem um único teste e a v0.0.16 saiu com a
/// biometria partida. Estes testes cobrem as decisões que levaram lá.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PIN', () {
    test('guardar e validar', () async {
      final svc = CadeadoService(auth: _AuthFalso());

      expect(await svc.temPinDefinido(), isFalse);
      await svc.guardarPin('1234');

      expect(await svc.temPinDefinido(), isTrue);
      expect(await svc.validarPin('1234'), isTrue);
      expect(await svc.validarPin('4321'), isFalse);
    });

    test('o mesmo PIN em dois telemóveis não dá o mesmo hash', () async {
      // O salt é por instalação: sem isso, uma tabela de hashes de PINs de 4
      // dígitos abria qualquer instalação.
      final a = CadeadoService(auth: _AuthFalso());
      await a.guardarPin('1234');
      final hashA = await const FlutterSecureStorage().read(
        key: 'cadeado.pin_hash_v1',
      );

      FlutterSecureStorage.setMockInitialValues({});
      final b = CadeadoService(auth: _AuthFalso());
      await b.guardarPin('1234');
      final hashB = await const FlutterSecureStorage().read(
        key: 'cadeado.pin_hash_v1',
      );

      expect(hashA, isNotNull);
      expect(hashA, isNot(hashB));
    });

    test('apagar o PIN desactiva o cadeado', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.guardarPin('123456');

      await svc.apagarPin();

      expect(await svc.temPinDefinido(), isFalse);
      expect(await svc.validarPin('123456'), isFalse);
    });
  });

  group('pedirBiometria', () {
    test('não usa stickyAuth nem device credential', () async {
      // Foi esta combinação que encravou o ecrã de bloqueio na v0.0.16: com
      // `stickyAuth` o plugin engole o cancelamento e o Future nunca completa;
      // com `biometricOnly: false` o prompt fica sem botão de cancelar.
      final auth = _AuthFalso(resposta: true);
      await CadeadoService(auth: auth).pedirBiometria();

      expect(auth.opcoesUsadas!.stickyAuth, isFalse);
      expect(auth.opcoesUsadas!.biometricOnly, isTrue);
    });

    test('sucesso', () async {
      final r = await CadeadoService(
        auth: _AuthFalso(resposta: true),
      ).pedirBiometria();

      expect(r.autenticado, isTrue);
      expect(r.erro, isNull);
    });

    test('desistir não produz mensagem de erro', () async {
      final r = await CadeadoService(
        auth: _AuthFalso(resposta: false),
      ).pedirBiometria();

      expect(r.autenticado, isFalse);
      expect(r.erro, isNull);
    });

    test('sem digitais registadas explica o que fazer', () async {
      final r = await CadeadoService(
        auth: _AuthFalso(atira: PlatformException(code: 'NotEnrolled')),
      ).pedirBiometria();

      expect(r.autenticado, isFalse);
      expect(r.erro, contains('Regista uma nas definições'));
    });

    test('erro desconhecido não fica calado', () async {
      final r = await CadeadoService(
        auth: _AuthFalso(atira: PlatformException(code: 'seja_o_que_for')),
      ).pedirBiometria();

      expect(r.autenticado, isFalse);
      expect(r.erro, isNotNull);
    });

    test('a marca de "prompt à frente" levanta-se e volta a baixar', () async {
      // O CadeadoGate lê isto para não contar o prompt como saída da app.
      final svc = CadeadoService(
        auth: _AuthFalso(atira: PlatformException(code: 'NotAvailable')),
      );

      expect(svc.aPedirBiometria, isFalse);
      await svc.pedirBiometria();
      // Mesmo tendo rebentado, a marca não pode ficar levantada: se ficasse, o
      // gate deixava de bloquear a app para sempre.
      expect(svc.aPedirBiometria, isFalse);
    });
  });

  group('bloquear ao retomar', () {
    test('"nunca" não bloqueia mesmo depois de horas fora', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.setThresholdMinutos(-1);
      await svc.registarPaused();

      expect(await svc.deveBloquearAoRetomar(), isFalse);
    });

    test('"sempre" bloqueia', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.setThresholdMinutos(0);

      expect(await svc.deveBloquearAoRetomar(), isTrue);
    });

    test('dentro do limite não bloqueia', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.setThresholdMinutos(5);
      await svc.registarPaused();

      expect(await svc.deveBloquearAoRetomar(), isFalse);
    });

    test('passado o limite bloqueia', () async {
      SharedPreferences.setMockInitialValues({
        'cadeado.threshold_minutes': 5,
        'cadeado.ultimo_paused_ms': DateTime.now()
            .subtract(const Duration(minutes: 6))
            .millisecondsSinceEpoch,
      });

      expect(
        await CadeadoService(auth: _AuthFalso()).deveBloquearAoRetomar(),
        isTrue,
      );
    });

    test('sem registo de saída não bloqueia', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.setThresholdMinutos(5);

      expect(await svc.deveBloquearAoRetomar(), isFalse);
    });
  });

  group('biometria activada', () {
    test('sem escolha gravada segue o que o dispositivo tem', () async {
      final semLeitor = CadeadoService(auth: _AuthFalso(biometrias: const []));
      expect(await semLeitor.biometriaActivada(), isFalse);

      final comLeitor = CadeadoService(auth: _AuthFalso());
      expect(await comLeitor.biometriaActivada(), isTrue);
    });

    test('a escolha do utilizador manda sobre o default', () async {
      final svc = CadeadoService(auth: _AuthFalso());
      await svc.setBiometriaActivada(false);

      expect(await svc.biometriaActivada(), isFalse);
    });
  });
}

class _AuthFalso implements LocalAuthentication {
  _AuthFalso({
    this.resposta = false,
    this.atira,
    this.biometrias = const [BiometricType.fingerprint],
  });

  final bool resposta;
  final Object? atira;
  final List<BiometricType> biometrias;
  AuthenticationOptions? opcoesUsadas;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    opcoesUsadas = options;
    if (atira != null) throw atira!;
    return resposta;
  }

  @override
  Future<bool> get canCheckBiometrics async => biometrias.isNotEmpty;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrias;

  @override
  Future<bool> stopAuthentication() async => true;
}
