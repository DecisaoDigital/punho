import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> abrirClientes(WidgetTester tester, Size tamanho) =>
      montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const ClientsPage(),
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

    testWidgets('editar uma máquina existente guarda o nome novo', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      container
          .read(operationsProvider.notifier)
          .saveMachine(
            const Machine(
              id: 'maquina-7',
              name: 'Máquina 7',
              reference: '',
              category: 'Escavação',
              status: MachineStatus.available,
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

      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Mini escavadora 1.8T',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final guardada = container
          .read(operationsProvider)
          .machines
          .firstWhere((m) => m.id == 'maquina-7');
      expect(guardada.name, 'Mini escavadora 1.8T');
    });

    // Achado da auditoria: a célula "Utilização vs Rentabilidade"
    // (`sintese_slide.dart:95-124`) nunca saía de "Por apurar" porque nenhum
    // ecrã pedia o valor de compra da máquina, e o `acquiredOn` que já
    // existia no modelo nunca chegava ao `copyWith`.
    testWidgets(
      'guarda valor de compra e data de aquisição, os dois opcionais',
      (tester) async {
        final container = containerCom(estadoComMovimento());
        await montarLandscape(
          tester,
          container,
          const MachinesPage(),
          tamanho: const Size(1280, 800),
        );
        await tester.tap(find.text('Adicionar máquina'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Nome'),
          'Gerador novo',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Valor de compra (€) — opcional'),
          '18.500,00',
        );
        expect(find.text('Não indicada'), findsOneWidget);
        await tester.tap(find.text('Data de aquisição'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        final maquina = container
            .read(operationsProvider)
            .machines
            .firstWhere((m) => m.name == 'Gerador novo');
        expect(maquina.purchasePriceCents, 1850000);
        expect(maquina.acquiredOn, isNotNull);
      },
    );

    testWidgets(
      'sem valor de compra nem data, grava a máquina na mesma — quem não '
      'sabe não fica bloqueado',
      (tester) async {
        final container = containerCom(estadoComMovimento());
        await montarLandscape(
          tester,
          container,
          const MachinesPage(),
          tamanho: const Size(1280, 800),
        );
        await tester.tap(find.text('Adicionar máquina'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Nome'),
          'Máquina sem histórico de compra',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        final maquina = container
            .read(operationsProvider)
            .machines
            .firstWhere((m) => m.name == 'Máquina sem histórico de compra');
        expect(maquina.purchasePriceCents, isNull);
        expect(maquina.acquiredOn, isNull);
      },
    );
  });

  group('Diálogo de lead', () {
    testWidgets('fica largo e mantém o campo e Guardar acima do teclado', (
      tester,
    ) async {
      await abrirClientes(tester, const Size(900, 500));
      await tester.tap(find.text('Novo lead'));
      await tester.pumpAndSettle();
      abrirTeclado(tester, altura: 220);
      await tester.pumpAndSettle();

      final nome = find.widgetWithText(TextField, 'Nome');
      final telefone = find.widgetWithText(TextField, 'Telemóvel');
      final guardar = find.widgetWithText(FilledButton, 'Guardar');

      expect(find.byType(DialogoDeFormulario), findsOneWidget);
      expect(
        tester.getTopLeft(telefone).dx,
        greaterThan(tester.getTopLeft(nome).dx),
      );
      expect(
        (tester.getTopLeft(telefone).dy - tester.getTopLeft(nome).dy).abs(),
        lessThan(8),
        reason: 'em paisagem os dois campos devem caber lado a lado',
      );
      expect(tester.getRect(nome).bottom, lessThanOrEqualTo(500 - 220));
      expect(tester.getRect(guardar).bottom, lessThanOrEqualTo(500 - 220));
    });

    testWidgets('gravar fecha sem excepção e o lead aparece na lista', (
      tester,
    ) async {
      // Regressão: os controladores de nome/telemóvel viviam na função
      // `_leadDialog` e eram descartados logo a seguir ao `await showDialog`,
      // que devolve no instante do `Navigator.pop` enquanto a animação de
      // fecho ainda está a correr — a lista de leads por baixo reconstruía-se
      // a meio dela com controladores já mortos ("A TextEditingController was
      // used after being disposed"), e daí o ecrã vermelho ao gravar.
      await abrirClientes(tester, const Size(1280, 800));
      await tester.tap(find.text('Novo lead'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Obra Nova',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telemóvel'),
        '914 555 555',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DialogoDeFormulario), findsNothing);
      expect(find.text('Obra Nova'), findsOneWidget);
    });
  });

  group('Diálogo de confirmação de reserva', () {
    Future<void> abrirReservas(WidgetTester tester) => montarLandscape(
      tester,
      containerCom(estadoComMovimento()),
      const BookingsPage(),
      tamanho: const Size(1280, 800),
    );

    testWidgets('gravar fecha sem excepção e cria a reserva', (tester) async {
      // Regressão: `customerId`/`status`/`soSemReserva` viviam num
      // `StatefulBuilder` dentro de `_showCalendarBookingConfirmation`, e
      // `expectedValue`/`notes` eram descartados logo a seguir ao `await
      // showDialog` — a gravação mexe no calendário por baixo, que se
      // reconstrói a meio da animação de fecho com controladores já mortos.
      await abrirReservas(tester);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('PE-02').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reservar (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar reserva'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Gravar reserva'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Confirmar reserva'), findsNothing);
    });
  });

  group('Diálogo de nova marcação', () {
    testWidgets('gravar fecha sem excepção e cria a reserva', (tester) async {
      // Regressão: tal como na confirmação de reserva, `customerId`/
      // `machineId`/as datas/`collaboratorId` viviam num `StatefulBuilder`
      // dentro de `_showBookingForm`, e `expectedValue`/`notes` eram
      // descartados logo a seguir ao `await showDialog`.
      final container = containerCom(estadoComMovimento());
      await montarLandscape(
        tester,
        container,
        Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => showBookingForm(context, ref),
            child: const Text('abrir marcação'),
          ),
        ),
        tamanho: const Size(1280, 800),
      );

      await tester.tap(find.text('abrir marcação'));
      await tester.pumpAndSettle();
      expect(find.text('Nova marcação / reserva'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar marcação'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nova marcação / reserva'), findsNothing);
    });
  });
}
