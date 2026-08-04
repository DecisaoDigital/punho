import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// O diálogo dos veículos tinha os mesmos quatro defeitos do dos colaboradores,
/// apanhados pelo Cesar no smoke da v0.0.4.
void main() {
  Future<void> abrirVeiculos(WidgetTester tester, container) async {
    await montarLandscape(tester, container, const VehiclesPage());
    await tester.tap(find.text('Adicionar veículo').first);
    await tester.pumpAndSettle();
  }

  testWidgets('o título diz "Adicionar", não "Novo"', (tester) async {
    // "Novo veículo" lia-se como "veículo criado" — o mesmo mal-entendido dos
    // colaboradores.
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    expect(find.text('Adicionar veículo'), findsWidgets);
    expect(find.text('Novo veículo'), findsNothing);
  });

  testWidgets('guardar sem matrícula avisa e não grava', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Indica a matrícula do veículo.'), findsOneWidget);
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      isNot(contains('')),
    );
    // O diálogo fica aberto para se corrigir, em vez de fechar e perder tudo.
    expect(find.text('Adicionar veículo'), findsWidgets);
  });

  testWidgets('com matrícula guarda e fecha', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.enterText(find.byType(TextField).first, 'ZZ-99-XX');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // O controller relê do repositório depois de gravar, por isso confirma-se
    // pela presença da matrícula e não pela contagem.
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      contains('ZZ-99-XX'),
    );
    expect(find.byType(EcraDeFormulario), findsNothing);
  });

  testWidgets('a matrícula ganha foco e escreve-se em maiúsculas', (
    tester,
  ) async {
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    final campo = tester.widget<TextField>(find.byType(TextField).first);
    expect(campo.autofocus, isTrue);
    expect(campo.textCapitalization, TextCapitalization.characters);
  });

  testWidgets('sair com texto escrito pede confirmação', (tester) async {
    // Era "não fecha ao tocar fora": o diálogo tinha `barrierDismissible:
    // false` porque um toque ao lado deitava fora o formulário todo. Num ecrã
    // completo não há lado nenhum onde tocar — o que há é a seta de retorno e o
    // gesto do sistema, e é aí que a mesma perda passou a ser travada.
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('Sair sem guardar?'), findsOneWidget);
    await tester.tap(find.text('Continuar a preencher'));
    await tester.pumpAndSettle();
    expect(find.byType(EcraDeFormulario), findsOneWidget);
  });

  testWidgets('sair sem nada escrito não incomoda ninguém', (tester) async {
    await abrirVeiculos(tester, containerCom(estadoComMovimento()));

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('Sair sem guardar?'), findsNothing);
    expect(find.byType(EcraDeFormulario), findsNothing);
  });

  testWidgets('em retrato com o teclado aberto o Guardar continua visível', (
    tester,
  ) async {
    // Seis campos e um teclado de 320 dp: era isto que empurrava o Guardar para
    // fora do ecrã, sem o corpo rolar para se lá chegar.
    await montarLandscape(
      tester,
      containerCom(estadoComMovimento()),
      const VehiclesPage(),
      tamanho: const Size(420, 900),
    );
    await tester.tap(find.text('Adicionar veículo').first);
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(
      bottom: 320 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final guardar = find.widgetWithText(FilledButton, 'Guardar');
    expect(tester.getRect(guardar).bottom, lessThanOrEqualTo(900 - 320));
    // E o último campo alcança-se a rolar, em vez de não existir.
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<InsuranceFrequency>),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Periodicidade do seguro'), findsOneWidget);
  });

  testWidgets('sair sem guardar não grava', (tester) async {
    final container = containerCom(estadoComMovimento());
    await abrirVeiculos(tester, container);

    await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair sem guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(EcraDeFormulario), findsNothing);
    expect(
      container.read(operationsProvider).vehicles.map((v) => v.plate),
      isNot(contains('AA-11-BB')),
    );
  });

  // Tarefa 2 da auditoria: "o veículo não se edita nem se arquiva" — só
  // existia criação. `_confirmarEliminarVeiculo`/`_FormularioDeVeiculo`
  // ganharam o mesmo ciclo de vida do colaborador: editar por `onTap` e por
  // ícone, e eliminar com 6 segundos para anular.
  group('ciclo de vida (editar e arquivar)', () {
    Future<ProviderContainer> comUmVeiculo(WidgetTester tester) async {
      final container = containerCom(estadoComMovimento());
      await abrirVeiculos(tester, container);
      await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('tocar na linha abre "Editar veículo" com os campos preenchidos', (
      tester,
    ) async {
      await comUmVeiculo(tester);

      await tester.tap(find.text('AA-11-BB'));
      await tester.pumpAndSettle();

      expect(find.text('Editar veículo'), findsOneWidget);
      final campoMatricula = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(campoMatricula.controller?.text, 'AA-11-BB');
    });

    testWidgets('editar grava sem duplicar a linha', (tester) async {
      final container = await comUmVeiculo(tester);

      await tester.tap(find.text('AA-11-BB'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ZZ-99-XX');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final veiculos = container.read(operationsProvider).vehicles;
      expect(veiculos, hasLength(1));
      expect(veiculos.single.plate, 'ZZ-99-XX');
    });

    testWidgets('eliminar arquiva com 6 segundos para anular', (
      tester,
    ) async {
      final container = await comUmVeiculo(tester);

      await tester.tap(find.byTooltip('Eliminar veículo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('AA-11-BB'), findsNothing);
      expect(
        container.read(operationsProvider).vehicles.single.archived,
        isTrue,
      );

      await tester.tap(find.widgetWithText(SnackBarAction, 'Anular'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        container.read(operationsProvider).vehicles.single.archived,
        isFalse,
      );
      expect(find.text('AA-11-BB'), findsOneWidget);
    });
  });

  // Regressão do achado "valor gravado como zero, sem aviso"
  // (docs/AUDITORIA_EMPRESARIO_EXEMPLAR.md, achado 1): prestação e seguro
  // usavam `_cents`, que já devolvia `null` em vez de zero, mas engolia texto
  // ilegível em silêncio — sem tratar o milhar nem avisar quem escreveu.
  group('prestação e seguro (€) — separador de milhar', () {
    testWidgets('"1.500,00" na prestação grava 1500 €, não zero', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await abrirVeiculos(tester, container);
      await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
      final campoPrestacao = find.ancestor(
        of: find.text('Prestação mensal (€)'),
        matching: find.byType(TextField),
      );
      await tester.enterText(campoPrestacao, '1.500,00');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        container.read(operationsProvider).vehicles.single.monthlyPaymentCents,
        150000,
      );
    });

    testWidgets(
      'texto ilegível no seguro recusa a gravação com aviso visível',
      (tester) async {
        final container = containerCom(estadoComMovimento());
        await abrirVeiculos(tester, container);
        await tester.enterText(find.byType(TextField).first, 'AA-11-BB');
        final campoSeguro = find.ancestor(
          of: find.text('Seguro (€)'),
          matching: find.byType(TextField),
        );
        await tester.enterText(campoSeguro, '1.500.00');
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Não consigo ler o seguro'), findsOneWidget);
        expect(find.byType(EcraDeFormulario), findsOneWidget);
        expect(
          container.read(operationsProvider).vehicles.map((v) => v.plate),
          isNot(contains('AA-11-BB')),
        );
      },
    );
  });
}
