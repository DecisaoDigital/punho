import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/updates/instalador_de_update.dart';
import 'package:punho/core/updates/update_info.dart';

/// O instalador só corre sobre um ficheiro que confere com o hash publicado.
///
/// O `url_download` vem de uma coluna editável em `versoes_apps`. Sem esta
/// verificação, uma linha errada faria a app instalar outra coisa qualquer com
/// a confiança de ser uma actualização legítima.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory pasta;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('punho-instalador');
  });
  tearDown(() async {
    if (await pasta.exists()) await pasta.delete(recursive: true);
  });

  PunhoUpdateInfo info({String? sha, String url = 'https://exemplo/p.apk'}) =>
      PunhoUpdateInfo(
        version: '0.0.20',
        buildNumber: 20,
        downloadUrl: url,
        mandatory: false,
        sha256: sha,
      );

  test('versão sem hash publicado não é descarregada', () async {
    // Recusar é a decisão certa: sem forma de verificar, o caminho antigo pelo
    // browser é mais honesto do que instalar às cegas.
    final caminho = await InstaladorDeUpdate().descarregar(info());

    expect(caminho, isNull);
  });

  test('hash vazio conta como não publicado', () async {
    expect(await InstaladorDeUpdate().descarregar(info(sha: '   ')), isNull);
  });

  test('o modelo transporta o hash de ida e volta', () {
    const original = PunhoUpdateInfo(
      version: '0.0.20',
      buildNumber: 20,
      downloadUrl: 'https://exemplo/p.apk',
      mandatory: false,
      sha256: 'abc123',
    );

    final volta = PunhoUpdateInfo.fromJson(original.toJson());

    expect(volta.sha256, 'abc123');
    // E sobrevive ao `semBloqueio`, que é o que o cache guarda: sem isso, uma
    // app que lesse do cache perdia a capacidade de instalar sozinha.
    expect(original.semBloqueio().sha256, 'abc123');
  });

  test('uma resposta antiga sem sha256 não rebenta a leitura', () {
    // O servidor pode ser mais antigo do que a app. Falta de campo é ausência
    // de instalação automática, não erro.
    final info = PunhoUpdateInfo.fromJson({
      'versao_actual': '0.0.20',
      'build_number': 20,
      'url_download': 'https://exemplo/p.apk',
      'obrigatoria': false,
    });

    expect(info.sha256, isNull);
  });

  test(
    'sem canal nativo, instalar falha em silêncio em vez de rebentar',
    () async {
      // Windows e testes não têm o canal. A app não pode estoirar por isso.
      expect(await InstaladorDeUpdate().podeInstalar(), isFalse);
      expect(await InstaladorDeUpdate().instalar('/nao/existe.apk'), isNull);
    },
  );
}
