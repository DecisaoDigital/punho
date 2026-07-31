import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sem isto o texto sai em caixas e os ícones em quadrados: o `flutter test` não
/// carrega tipos de letra reais. Como as imagens de golden servem para comparar
/// com o mockup, tem de se ler o que está escrito.
///
/// Vivia dentro de `test/features/dashboard/screenshots_test.dart`. Quando esse
/// ficheiro foi apagado no refactor do painel, levou o carregador com ele e
/// deixou a suite inteira sem compilar — um teste que continuava a importá-lo
/// ficou a apontar para um ficheiro inexistente. Um helper partilhado não pode
/// morar dentro de um teste.
Future<void> carregarTiposDeLetra() async {
  await _carregar('Roboto', const [
    r'C:\Windows\Fonts\segoeui.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ]);
  // O peso forte à parte: sem ele os rótulos dos botões (w800) saíam em caixas.
  await _carregar('Roboto', const [
    r'C:\Windows\Fonts\segoeuib.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ]);
  // Os ícones do Material vivem no cache do SDK; sem isto ficam quadrados.
  final sdk = File(Platform.resolvedExecutable).parent.path;
  await _carregar('MaterialIcons', [
    r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    '$sdk/../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

Future<void> _carregar(String familia, List<String> caminhos) async {
  for (final caminho in caminhos) {
    final ficheiro = File(caminho);
    if (!ficheiro.existsSync()) continue;
    final bytes = await ficheiro.readAsBytes();
    await (FontLoader(
      familia,
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    return;
  }
}
