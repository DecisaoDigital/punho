@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/operations/presentation/boas_vindas_screen.dart';
import 'package:punho/features/operations/presentation/mais_dados_screen.dart';

import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/dashboard/presentation/slides/custos_slide.dart';

import '../dashboard/fixtura.dart';
import '../dashboard/screenshots_test.dart' show carregarTiposDeLetra;

/// Capturas da v0.0.6, em `docs/design/screenshots/v006/`.
///
/// Gerar/actualizar com
/// `flutter test --update-goldens test/features/operations/screenshots_v006_test.dart`.
void main() {
  setUpAll(carregarTiposDeLetra);

  Future<void> montar(
    WidgetTester tester,
    Widget ecra, {
    Size tamanho = const Size(480, 960),
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: PunhoTheme.light, home: ecra),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('captura do KPI de custo real com pessoal', (tester) async {
    final estado = estadoComMovimento().copyWith(
      legalForm: 'Lda.',
      collaborators: const [
        Collaborator(
          id: 'co1',
          name: 'Ana',
          status: CollaboratorStatus.active,
          costCents: 110000,
        ),
        Collaborator(
          id: 'co2',
          name: 'Bruno',
          status: CollaboratorStatus.active,
          costCents: 80000,
          employmentType: EmploymentType.recibosVerdes,
        ),
      ],
    );
    await montarLandscape(
      tester,
      containerCom(estado),
      CustosSlide(agora: agoraFixa),
      tamanho: const Size(1280, 800),
    );

    await expectLater(
      find.byType(CustosSlide),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/dashboard_custo_real_pessoal.png',
      ),
    );
  });

  testWidgets('captura do ecrã Mais dados', (tester) async {
    await montar(tester, MaisDadosScreen(aoAvancar: () {}, aoVoltar: () {}));

    await expectLater(
      find.byType(MaisDadosScreen),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/onboarding_mais_dados.png',
      ),
    );
  });

  testWidgets('captura do ecrã Boas-vindas em retrato', (tester) async {
    await montar(tester, BoasVindasScreen(aoEntrar: () {}, aoVoltar: () {}));

    await expectLater(
      find.byType(BoasVindasScreen),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/onboarding_boas_vindas.png',
      ),
    );
  });

  testWidgets('captura do ecrã Boas-vindas depois de rodar', (tester) async {
    // O mesmo ecrã em paisagem: é o que o gestor vê se rodar o dispositivo
    // quando o rodapé lhe pede, antes de tocar em "Entrar na Punho".
    await montar(
      tester,
      BoasVindasScreen(aoEntrar: () {}, aoVoltar: () {}),
      tamanho: const Size(960, 480),
    );

    await expectLater(
      find.byType(BoasVindasScreen),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/onboarding_boas_vindas_landscape.png',
      ),
    );
  });
}
