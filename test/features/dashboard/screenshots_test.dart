import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';

import 'fixtura.dart';

/// Sem isto o texto sai em caixas e os ícones em quadrados: o `flutter test` não
/// carrega tipos de letra reais. Como estas imagens servem para comparar com o
/// mockup, tem de se ler o que está escrito.
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
    await (FontLoader(familia)
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    return;
  }
}

/// Capturas dos cinco slides, gravadas em `docs/design/screenshots/v005/`.
///
/// São testes de golden: gerar/actualizar com
/// `flutter test --update-goldens test/features/dashboard/screenshots_test.dart`.
/// Valem sobretudo como documentação — é o que se confronta com o mockup — e de
/// caminho apanham mudanças de layout não intencionais.
///
/// Nota: uma imagem de golden depende da versão do Flutter e da máquina que a
/// gerou. Se falharem numa máquina diferente, não é a app que está mal: é a
/// renderização que difere. Actualizar as imagens é a resposta certa.
void main() {
  setUpAll(carregarTiposDeLetra);

  final slides = [
    (indice: 0, nome: '1-dinheiro', tab: null),
    (indice: 1, nome: '2-pipeline', tab: 'Pipeline'),
    (indice: 2, nome: '3-maquinas', tab: 'Máquinas'),
    (indice: 3, nome: '4-custos', tab: 'Custos'),
    (indice: 4, nome: '5-semana', tab: 'Semana'),
  ];

  for (final slide in slides) {
    testWidgets('captura do slide ${slide.nome}', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        DashboardPage(agora: agoraFixa),
        tamanho: const Size(1280, 800),
      );
      if (slide.tab != null) {
        await tester.tap(find.widgetWithText(TextButton, slide.tab!));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(
          '../../../docs/design/screenshots/v005/${slide.nome}.png',
        ),
      );
    });
  }

  testWidgets('captura do painel de uma empresa sem movimentos', (tester) async {
    await montarLandscape(
      tester,
      containerCom(estadoSemMovimento()),
      DashboardPage(agora: agoraFixa),
      tamanho: const Size(1280, 800),
    );

    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v005/0-sem-movimentos.png',
      ),
    );
  });
}
