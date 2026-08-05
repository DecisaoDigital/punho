import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/features/workforce/presentation/ficha_fiscal_form.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// A ficha fiscal do colaborador, por vínculo.
///
/// A regra que estes testes protegem: **só se pede o que muda alguma coisa.** Em
/// recibos verdes os descontos são do prestador, portanto NISS, estado civil e
/// dependentes não aparecem — e, sobretudo, não ficam gravados se o vínculo
/// mudar.
void main() {
  ProviderContainer comRepoReal({List<Collaborator> equipa = const []}) {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(operationsProvider.notifier);
    notifier.updateCompanySettings(legalForm: 'Lda.');
    for (final pessoa in equipa) {
      notifier.saveCollaborator(pessoa);
    }
    return container;
  }

  Future<void> abrirLista(
    WidgetTester tester,
    ProviderContainer container, {
    Size tamanho = const Size(1280, 1000),
  }) => montarLandscape(
    tester,
    container,
    CollaboratorsPage(agora: agoraFixa),
    tamanho: tamanho,
  );

  Future<void> abrirDialogo(
    WidgetTester tester,
    ProviderContainer container, {
    Size tamanho = const Size(1280, 1000),
  }) async {
    await abrirLista(tester, container, tamanho: tamanho);
    await tester.tap(find.text('Adicionar colaborador').first);
    await tester.pumpAndSettle();
  }

  Future<void> escolherVinculo(WidgetTester tester, String rotulo) async {
    await tester.tap(find.text(rotulo));
    await tester.pumpAndSettle();
  }

  group('Campos condicionais pelo vínculo', () {
    testWidgets('contrato pede NISS, estado civil e dependentes', (
      tester,
    ) async {
      await abrirDialogo(tester, comRepoReal());

      // Contrato é o valor por omissão.
      expect(find.widgetWithText(TextField, 'NISS'), findsOneWidget);
      expect(find.text('Estado civil'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Nº de dependentes'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'NIF do prestador'), findsNothing);
    });

    testWidgets('recibos verdes pede NIF e mais nada do trabalhador', (
      tester,
    ) async {
      await abrirDialogo(tester, comRepoReal());
      await escolherVinculo(tester, 'Recibos verdes');

      expect(
        find.widgetWithText(TextField, 'NIF do prestador'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'NISS'), findsNothing);
      expect(find.text('Estado civil'), findsNothing);
      expect(find.widgetWithText(TextField, 'Nº de dependentes'), findsNothing);
    });

    testWidgets('alternar não perde o que já estava escrito', (tester) async {
      await abrirDialogo(tester, comRepoReal());
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Manuel Silva',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'NISS'),
        '12345678901',
      );

      await escolherVinculo(tester, 'Recibos verdes');
      await escolherVinculo(tester, 'Contrato de trabalho');

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Nome'))
            .controller!
            .text,
        'Manuel Silva',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'NISS'))
            .controller!
            .text,
        '12345678901',
      );
    });
  });

  group('Bloco de estimativa', () {
    testWidgets('em contrato mostra as três linhas e o custo em destaque', (
      tester,
    ) async {
      await abrirDialogo(tester, comRepoReal());
      await tester.enterText(
        find.widgetWithText(TextField, 'Custo estimado para a empresa (€)'),
        '1200',
      );
      await tester.pumpAndSettle();

      expect(find.text('Líquido para o trabalhador'), findsOneWidget);
      expect(find.text('TSU entidade patronal (23,75%)'), findsOneWidget);
      expect(find.text('Custo total para a empresa'), findsOneWidget);
      // 1.200 € + 23,75% = 1.485 €.
      expect(find.text('1485.00 €'), findsOneWidget);
      expect(find.text('+285.00 €'), findsOneWidget);
      expect(
        find.textContaining('Confirma com o teu contabilista'),
        findsOneWidget,
      );
    });

    testWidgets('em recibos verdes diz a frase, não os números', (
      tester,
    ) async {
      await abrirDialogo(tester, comRepoReal());
      await tester.enterText(
        find.widgetWithText(TextField, 'Custo estimado para a empresa (€)'),
        '800',
      );
      await escolherVinculo(tester, 'Recibos verdes');

      expect(
        find.textContaining('o valor pago é o custo total'),
        findsOneWidget,
      );
      expect(find.text('TSU entidade patronal (23,75%)'), findsNothing);
    });

    testWidgets('sem bruto declarado diz por apurar, não zero', (tester) async {
      await abrirDialogo(tester, comRepoReal());

      expect(find.text('por apurar'), findsWidgets);
      expect(find.text('0.00 €'), findsNothing);
    });

    testWidgets('regime não modelado não estima', (tester) async {
      final container = comRepoReal();
      // Pelo caminho real: é o onboarding que fixa a forma jurídica, e é de lá
      // que o regime é lido.
      container
          .read(operationsProvider.notifier)
          .completeOnboarding(
            companyName: 'Alugueres SA',
            legalForm: 'S.A.',
            hasFleet: false,
            collaborators: 0,
            totalMachinesDeclared: 0,
            insertMachinesNow: false,
          );
      await abrirDialogo(tester, container);

      expect(
        find.textContaining('Estimativa não disponível para este regime'),
        findsOneWidget,
      );
    });
  });

  group('Avisos que não bloqueiam', () {
    testWidgets('NISS com 10 dígitos avisa mas deixa gravar', (tester) async {
      final container = comRepoReal();
      await abrirDialogo(tester, container);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Manuel Silva',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'NISS'),
        '1234567890',
      );
      await tester.pumpAndSettle();

      expect(find.text('NISS parece incompleto'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final guardado = container
          .read(operationsProvider)
          .collaborators
          .firstWhere((c) => c.name == 'Manuel Silva');
      expect(guardado.socialSecurityNumber, '1234567890');
    });
  });

  group('Gravar só o que o vínculo usa', () {
    testWidgets('passar a recibos verdes limpa o NISS', (tester) async {
      // Sentinela no copyWith: com `?? this` o NISS ficava lá, guardado num
      // prestador de serviços a quem nunca foi pedido.
      final container = comRepoReal(
        equipa: const [
          Collaborator(
            id: 'co1',
            name: 'Manuel Silva',
            status: CollaboratorStatus.active,
            costCents: 100000,
            socialSecurityNumber: '12345678901',
          ),
        ],
      );
      await abrirLista(tester, container);
      await tester.tap(find.byTooltip('Editar colaborador').first);
      await tester.pumpAndSettle();
      await escolherVinculo(tester, 'Recibos verdes');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final guardado = container
          .read(operationsProvider)
          .collaborators
          .firstWhere((c) => c.id == 'co1');
      expect(guardado.employmentType, EmploymentType.recibosVerdes);
      expect(guardado.socialSecurityNumber, isNull);
    });
  });

  group('Lista', () {
    testWidgets('cada vínculo tem a sua sub-linha', (tester) async {
      await abrirLista(
        tester,
        comRepoReal(
          equipa: const [
            Collaborator(
              id: 'co1',
              name: 'Com contrato',
              status: CollaboratorStatus.active,
              costCents: 100000,
              socialSecurityNumber: '12345678901',
            ),
            Collaborator(
              id: 'co2',
              name: 'Prestador',
              status: CollaboratorStatus.active,
              costCents: 80000,
              employmentType: EmploymentType.recibosVerdes,
              taxId: '123456789',
            ),
          ],
        ),
      );

      // Contrato: custo real com a TSU somada.
      expect(
        find.textContaining(
          'Contrato de trabalho · Solteiro · custo real 1237.50 €/mês',
        ),
        findsOneWidget,
      );
      // Recibos verdes: o que se paga é o custo.
      expect(
        find.textContaining('Recibos verdes · custo 800.00 €/mês'),
        findsOneWidget,
      );
    });

    testWidgets('chip âmbar por dado em falta, um por vínculo', (tester) async {
      await abrirLista(
        tester,
        comRepoReal(
          equipa: const [
            Collaborator(
              id: 'co1',
              name: 'Sem NISS',
              status: CollaboratorStatus.active,
              costCents: 100000,
            ),
            Collaborator(
              id: 'co2',
              name: 'Sem NIF',
              status: CollaboratorStatus.active,
              costCents: 80000,
              employmentType: EmploymentType.recibosVerdes,
            ),
            Collaborator(
              id: 'co3',
              name: 'Completo',
              status: CollaboratorStatus.active,
              costCents: 90000,
              socialSecurityNumber: '12345678901',
            ),
          ],
        ),
      );

      expect(find.text('NISS em falta'), findsOneWidget);
      expect(find.text('NIF em falta'), findsOneWidget);
    });
  });

  group('Tarefas', () {
    test('uma linha por pessoa, com o nome', () {
      // Agregar em "3 fichas incompletas" não diz de quem se trata, e quem tem
      // de agir precisa disso.
      final estado = estadoComMovimento().copyWith(
        collaborators: const [
          Collaborator(
            id: 'co1',
            name: 'Ana',
            status: CollaboratorStatus.active,
          ),
          Collaborator(
            id: 'co2',
            name: 'Bruno',
            status: CollaboratorStatus.active,
            employmentType: EmploymentType.recibosVerdes,
          ),
          Collaborator(
            id: 'co3',
            name: 'Carla',
            status: CollaboratorStatus.active,
            socialSecurityNumber: '12345678901',
          ),
        ],
      );

      final fichas = tarefasPendentes(
        estado,
        agoraFixa,
      ).where((t) => t.id.startsWith('ficha-')).toList();

      expect(fichas, hasLength(2));
      expect(fichas.map((t) => t.titulo), contains('Ana — NISS em falta'));
      expect(fichas.map((t) => t.titulo), contains('Bruno — NIF em falta'));
      expect(fichas.every((t) => t.cta == 'Abrir ficha'), isTrue);
    });

    test('arquivados não geram tarefa', () {
      final estado = estadoComMovimento().copyWith(
        collaborators: const [
          Collaborator(
            id: 'co1',
            name: 'Saiu',
            status: CollaboratorStatus.active,
            archived: true,
          ),
        ],
      );

      expect(
        tarefasPendentes(
          estado,
          agoraFixa,
        ).where((t) => t.id.startsWith('ficha-')),
        isEmpty,
      );
    });
  });

  group('Reutilização pela sprint do self-service', () {
    test('os campos são um conjunto, não uma lista fixa', () {
      // O colaborador vai preencher a ficha dele no telemóvel. Se os campos
      // estivessem cravados no widget, essa sprint tinha de o reabrir.
      expect(
        camposDaFicha(EmploymentType.contrato),
        containsAll([
          CampoDaFichaFiscal.niss,
          CampoDaFichaFiscal.estadoCivil,
          CampoDaFichaFiscal.dependentes,
        ]),
      );
      expect(
        camposDaFicha(EmploymentType.recibosVerdes),
        isNot(contains(CampoDaFichaFiscal.niss)),
      );
      expect(
        camposDaFicha(EmploymentType.recibosVerdes),
        contains(CampoDaFichaFiscal.nif),
      );
    });
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
