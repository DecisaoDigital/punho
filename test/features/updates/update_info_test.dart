import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/updates/update_info.dart';

/// O cache local do banner (`punho_update.cache_v2`) grava e relê isto. Se o
/// `toJson` deixar de bater certo com o `fromJson`, o cache passa a rebentar em
/// silêncio no arranque e o banner volta ao bug de só aparecer à segunda vez.
void main() {
  const info = PunhoUpdateInfo(
    version: '0.0.16',
    buildNumber: 16,
    downloadUrl: 'https://exemplo/punho.apk',
    mandatory: true,
    releaseNotes: 'Notas',
  );

  test('sobrevive à ida e volta por JSON', () {
    final volta = PunhoUpdateInfo.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(info.toJson())) as Map),
    );

    expect(volta.version, info.version);
    expect(volta.buildNumber, info.buildNumber);
    expect(volta.downloadUrl, info.downloadUrl);
    expect(volta.mandatory, isTrue);
    expect(volta.releaseNotes, info.releaseNotes);
  });

  test('as chaves são as mesmas que a Edge Function devolve', () {
    // O `fromJson` lê a resposta da `versao-mais-recente`. Se o `toJson`
    // inventasse nomes próprios, o cache gravava num dialecto que só ele lia.
    expect(info.toJson().keys.toSet(), {
      'versao_actual',
      'build_number',
      'url_download',
      'obrigatoria',
      'notas_lancamento',
    });
  });

  test('sem notas de lançamento a chave não vai vazia', () {
    const semNotas = PunhoUpdateInfo(
      version: '0.0.16',
      buildNumber: 16,
      downloadUrl: 'https://exemplo/punho.apk',
      mandatory: false,
    );

    expect(semNotas.toJson().containsKey('notas_lancamento'), isFalse);
    expect(PunhoUpdateInfo.fromJson(semNotas.toJson()).releaseNotes, isNull);
  });

  test('semBloqueio tira o obrigatório e não mexe em mais nada', () {
    // Um `obrigatoria: true` vindo do cache prendia o utilizador fora da app
    // para sempre se a linha fosse retirada de `versoes_apps`.
    final cache = info.semBloqueio();

    expect(cache.mandatory, isFalse);
    expect(cache.version, info.version);
    expect(cache.buildNumber, info.buildNumber);
    expect(cache.downloadUrl, info.downloadUrl);
    expect(cache.releaseNotes, info.releaseNotes);
  });
}
