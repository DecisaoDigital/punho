import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/dialogo_de_formulario.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// "Abro o diálogo no telemóvel, o teclado sobe e o Guardar desaparece."
///
/// Os três diálogos de registo passaram a usar o [DialogoDeFormulario]: rodapé
/// fora do scroll e altura a descontar o teclado. Estes testes fixam as duas
/// propriedades que interessam — o Guardar está sempre visível e cabe dentro do
/// ecrã — em retrato com teclado e em paisagem sem ele.
void main() {
  /// Simula o teclado aberto: é isto que o sistema faz ao focar um campo.
  void abrirTeclado(WidgetTester tester, {double altura = 320}) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: altura * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> abrirMaquinas(WidgetTester tester, Size tamanho) =>
      montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const MachinesPage(),
        tamanho: tamanho,
      );

  group('Diálogo da máquina', () {
    testWidgets('em paisagem parte os campos em duas colunas', (tester) async {
      await abrirMaquinas(tester, const Size(1280, 800));
      await tester.tap(find.text('Adicionar máquina'));
      await tester.pumpAndSettle();

      expect(find.byType(DialogoDeFormulario), findsOneWidget);
      // Duas colunas: as notas ficam ao lado do nome, não abaixo.
      final nome = tester.getTopLeft(find.widgetWithText(TextField, 'Nome'));
      final notas = tester.getTopLeft(
        find.widgetWithText(TextField, 'Notas / manutenção'),
      );
      expect(notas.dx, greaterThan(nome.dx));
      expect(
        (notas.dy - nome.dy).abs(),
        lessThan(8),
        reason: 'as duas colunas arrancam à mesma altura',
      );
    });

    testWidgets('em retrato com teclado o Guardar continua visível', (
      tester,
    ) async {
      await abrirMaquinas(tester, const Size(420, 900));
      await tester.tap(find.text('Adicionar máquina'));
      await tester.pumpAndSettle();
      abrirTeclado(tester);
      await tester.pumpAndSettle();

      final guardar = find.widgetWithText(FilledButton, 'Guardar');
      expect(guardar, findsOneWidget);
      final caixa = tester.getRect(guardar);
      // O teclado ocupa os 320 dp de baixo dos 900: o botão tem de estar acima.
      expect(
        caixa.bottom,
        lessThanOrEqualTo(900 - 320),
        reason: 'o Guardar está debaixo do teclado',
      );
      // E numa coluna só, senão os campos ficariam com 200 dp de largura.
      final nome = tester.getTopLeft(find.widgetWithText(TextField, 'Nome'));
      final notas = tester.getTopLeft(
        find.widgetWithText(TextField, 'Notas / manutenção'),
      );
      expect(notas.dy, greaterThan(nome.dy));
    });

    testWidgets('não fecha ao tocar fora', (tester) async {
      await abrirMaquinas(tester, const Size(1280, 800));
      await tester.tap(find.text('Adicionar máquina'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(
        find.byType(DialogoDeFormulario),
        findsOneWidget,
        reason: 'um toque ao lado deitava fora o formulário todo',
      );
    });

    testWidgets('o estado escolhível não inclui "Parada"', (tester) async {
      await abrirMaquinas(tester, const Size(1280, 800));
      await tester.tap(find.text('Adicionar máquina'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<MachineStatus>));
      await tester.pumpAndSettle();

      expect(find.text('Parada'), findsNothing);
      for (final estado in estadosEscolhiveisDeMaquina) {
        expect(find.text(machineStatusLabel(estado)), findsWidgets);
      }
    });

    testWidgets('guardar sem nome avisa e não fecha', (tester) async {
      await abrirMaquinas(tester, const Size(1280, 800));
      await tester.tap(find.text('Adicionar máquina'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Indica o nome da máquina.'), findsOneWidget);
      expect(find.byType(DialogoDeFormulario), findsOneWidget);
    });

    testWidgets('uma máquina por identificar guarda-se e identifica-se', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      container.read(operationsProvider.notifier).saveMachine(
        const Machine(
          id: 'placeholder-7',
          name: 'Máquina 7',
          reference: '',
          category: 'Por identificar',
          status: MachineStatus.available,
          placeholder: true,
        ),
      );
      await montarLandscape(
        tester,
        container,
        const MachinesPage(),
        tamanho: const Size(1280, 1200),
      );

      await tester.tap(find.byTooltip('Editar máquina').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Guardar e identificar'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Mini escavadora 1.8T',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar e identificar'),
      );
      await tester.pumpAndSettle();

      final guardada = container
          .read(operationsProvider)
          .machines
          .firstWhere((m) => m.id == 'placeholder-7');
      expect(guardada.name, 'Mini escavadora 1.8T');
      expect(guardada.placeholder, isFalse);
    });
  });
}
