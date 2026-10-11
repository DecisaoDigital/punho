import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/armazenamento/prefs_windows_diferido.dart';

void main() {
  late Directory dir;
  late File ficheiro;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('prefs_diferido');
    ficheiro = File('${dir.path}/shared_preferences.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PrefsWindowsDiferido novo() => PrefsWindowsDiferido(
    espera: const Duration(milliseconds: 40),
    esperaMaxima: const Duration(milliseconds: 200),
    ficheiro: () async => ficheiro,
  );

  test('lê o ficheiro que o plugin oficial já tinha escrito', () async {
    ficheiro.writeAsStringSync(jsonEncode({'flutter.a': 'x', 'flutter.n': 3}));
    final s = novo();
    final tudo = await s.getAll();
    expect(tudo['flutter.a'], 'x');
    expect(tudo['flutter.n'], 3);
  });

  test('muitas gravações seguidas dão uma escrita só e ficam no disco', () async {
    final s = novo();
    for (var i = 0; i < 500; i++) {
      await s.setValue('String', 'flutter.k', 'v$i');
    }
    // Nada foi ao disco ainda (debounce), mas a leitura já vê o último valor.
    expect(ficheiro.existsSync(), isFalse);
    expect((await s.getAll())['flutter.k'], 'v499');
    await s.descarregar();
    expect(jsonDecode(ficheiro.readAsStringSync())['flutter.k'], 'v499');
    expect(File('${ficheiro.path}.tmp').existsSync(), isFalse);
  });

  test('remove e clear respeitam o prefixo', () async {
    final s = novo();
    await s.setValue('String', 'flutter.a', '1');
    await s.setValue('String', 'outra.b', '2');
    await s.remove('flutter.a');
    expect((await s.getAll()).containsKey('flutter.a'), isFalse);
    await s.clear();
    expect((await s.getAllWithPrefix('outra.'))['outra.b'], '2');
  });

  test('a escrita temporizada acaba sozinha', () async {
    final s = novo();
    await s.setValue('Int', 'flutter.n', 7);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(jsonDecode(ficheiro.readAsStringSync())['flutter.n'], 7);
  });
}
