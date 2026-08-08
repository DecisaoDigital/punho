import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:punho/core/cadeado/cadeado_service.dart';

/// **O cadeado continua a funcionar com o `allowBackup="false"`.**
///
/// Corre no aparelho, e tem de correr no aparelho: o PIN vive em
/// `flutter_secure_storage`, que no Android é `EncryptedSharedPreferences` com
/// a chave no **Android Keystore**. Num teste de unidade nada disso existe — o
/// plugin é substituído por um mapa em memória, e o teste passaria à mesma se a
/// cifra estivesse partida.
///
/// A pergunta a que este ficheiro responde é a do commit `70998e5`: ao desligar
/// o Auto Backup e a transferência entre aparelhos, partiu-se o cadeado? O
/// raciocínio diz que não — `allowBackup` decide o que sai do telemóvel, não o
/// que a app consegue ler enquanto está instalada. Mas raciocínio não é prova.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const armazem = FlutterSecureStorage();

  setUp(() async {
    // Não deixar rasto entre corridas: um PIN esquecido aqui bloqueava a app
    // no arranque seguinte.
    await CadeadoService().apagarPin();
  });
  tearDown(() async {
    await CadeadoService().apagarPin();
  });

  testWidgets('o Keystore está mesmo a funcionar neste APK', (_) async {
    // Antes de falar de PINs: se o `flutter_secure_storage` não escrevesse,
    // tudo o resto abaixo falharia por uma razão que não é o cadeado.
    await armazem.write(key: 'prova.keystore', value: 'lá e de volta');
    expect(await armazem.read(key: 'prova.keystore'), 'lá e de volta');
    await armazem.delete(key: 'prova.keystore');
    expect(await armazem.read(key: 'prova.keystore'), isNull);
  });

  testWidgets('guardar um PIN, e ele passa a existir', (_) async {
    final cadeado = CadeadoService();
    expect(await cadeado.temPinDefinido(), isFalse);

    await cadeado.guardarPin('4917');

    expect(await cadeado.temPinDefinido(), isTrue);
  });

  testWidgets('o PIN certo abre e o errado não', (_) async {
    final cadeado = CadeadoService();
    await cadeado.guardarPin('4917');

    expect(await cadeado.validarPin('4917'), isTrue);
    expect(await cadeado.validarPin('4918'), isFalse);
    expect(await cadeado.validarPin(''), isFalse);
  });

  testWidgets('o PIN sobrevive a uma instância nova do serviço', (_) async {
    // O caso que interessa: quem valida o PIN ao reabrir a app não é o mesmo
    // objecto que o guardou. Se a leitura do Keystore estivesse partida, era
    // aqui que se via — e o utilizador ficava fora da própria app.
    await CadeadoService().guardarPin('4917');

    final outroServico = CadeadoService();
    expect(await outroServico.temPinDefinido(), isTrue);
    expect(await outroServico.validarPin('4917'), isTrue);
  });

  testWidgets('o PIN não fica em claro no armazenamento', (_) async {
    await CadeadoService().guardarPin('4917');

    // Guarda-se um sha256 com salt, não o PIN. Se algum dia isto mudar, é
    // melhor um teste vermelho do que descobrir pelo lado de fora.
    final tudo = await armazem.readAll();
    expect(tudo.values, isNot(contains('4917')));
    expect(tudo.keys, contains('cadeado.pin_hash_v1'));
    expect(tudo.keys, contains('cadeado.pin_salt_v1'));
  });

  testWidgets('apagar o PIN volta a deixar a app aberta', (_) async {
    final cadeado = CadeadoService();
    await cadeado.guardarPin('4917');
    expect(await cadeado.temPinDefinido(), isTrue);

    await cadeado.apagarPin();

    expect(await cadeado.temPinDefinido(), isFalse);
    expect(await cadeado.validarPin('4917'), isFalse);
  });
}
