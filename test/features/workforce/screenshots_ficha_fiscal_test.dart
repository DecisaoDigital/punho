@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/tarefas/presentation/tarefas_page.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../../tipos_de_letra.dart';
import '../dashboard/fixtura.dart';

/// Capturas da ficha fiscal do colaborador, em `docs/design/screenshots/v006/`.
void main() {
  setUpAll(carregarTiposDeLetra);

  ProviderContainer comEquipa(List<Collaborator> equipa) {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(operationsProvider.notifier);
    notifier.completeOnboarding(
      companyName: 'Alugueres Norte',
      legalForm: 'Lda.',
      hasFleet: false,
      collaborators: 5,
      totalMachinesDeclared: 0,
      insertMachinesNow: false,
    );
    for (final pessoa in equipa) {
      notifier.saveCollaborator(pessoa);
    }
    return container;
  }

  const comContrato = Collaborator(
    id: 'co1',
    name: 'Manuel Silva',
    status: CollaboratorStatus.active,
    costCents: 120000,
    role: 'Manobrador',
    socialSecurityNumber: '12345678901',
  );
  const prestador = Collaborator(
    id: 'co2',
    name: 'Rita Fonseca',
    status: CollaboratorStatus.active,
    costCents: 80000,
    role: 'Contabilidade',
    employmentType: EmploymentType.recibosVerdes,
    taxId: '123456789',
  );

  Future<void> abrirDialogoDe(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await montarLandscape(
      tester,
      container,
      CollaboratorsPage(agora: agoraFixa),
      tamanho: const Size(1280, 1000),
    );
    await tester.tap(find.byTooltip('Editar colaborador').first);
    await tester.pumpAndSettle();
  }

  testWidgets('captura do diálogo em contrato', (tester) async {
    await abrirDialogoDe(tester, comEquipa(const [comContrato]));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/funcionario_dialogo_contrato.png',
      ),
    );
  });

  testWidgets('captura do diálogo em recibos verdes', (tester) async {
    await abrirDialogoDe(tester, comEquipa(const [prestador]));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/funcionario_dialogo_recibos_verdes.png',
      ),
    );
  });

  testWidgets('captura da lista com os dois vínculos', (tester) async {
    await montarLandscape(
      tester,
      comEquipa(const [
        comContrato,
        prestador,
        // Sem NISS: para se ver o chip âmbar.
        Collaborator(
          id: 'co3',
          name: 'João Matos',
          status: CollaboratorStatus.active,
          costCents: 95000,
        ),
      ]),
      CollaboratorsPage(agora: agoraFixa),
      tamanho: const Size(1280, 800),
    );

    await expectLater(
      find.byType(CollaboratorsPage),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/funcionarios_lista_dois_tipos.png',
      ),
    );
  });

  testWidgets('captura das Tarefas com fichas incompletas', (tester) async {
    await montarLandscape(
      tester,
      comEquipa(const [
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
          costCents: 90000,
          employmentType: EmploymentType.recibosVerdes,
        ),
      ]),
      const TarefasPage(),
      tamanho: const Size(1280, 900),
    );

    await expectLater(
      find.byType(TarefasPage),
      matchesGoldenFile(
        '../../../docs/design/screenshots/v006/tarefas_niss_em_falta.png',
      ),
    );
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
