import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// Regressão do achado mais grave da auditoria de 2026-08-02: um valor
/// escrito à portuguesa com separador de milhar, "1.500,00", era gravado como
/// zero, calado — `((double.tryParse(texto.replaceAll(',', '.')) ?? 0) *
/// 100).round()` só troca a vírgula pelo ponto, não remove o separador de
/// milhar, e o `?? 0` inventava um zero em vez de recusar a gravação.
///
/// A correcção usa `centsDeTexto` (o mesmo ajudante do onboarding e das
/// Definições) nos dois formulários que pedem "Valor previsto (€)":
/// confirmação de reserva (a partir do calendário) e nova marcação. Texto que
/// não se consegue ler já não vira zero silencioso — recusa a gravação com um
/// aviso visível, via `EcraDeFormulario.aviso`.
void main() {
  Future<void> abrirConfirmacaoDeReserva(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await montarLandscape(tester, container, const BookingsPage());
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PE-02').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reservar (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar reserva'), findsOneWidget);
  }

  Future<void> abrirNovaMarcacao(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await montarLandscape(
      tester,
      container,
      Consumer(
        builder: (context, ref, _) => ElevatedButton(
          onPressed: () => showBookingForm(context, ref),
          child: const Text('abrir marcação'),
        ),
      ),
    );
    await tester.tap(find.text('abrir marcação'));
    await tester.pumpAndSettle();
    expect(find.text('Nova marcação / reserva'), findsOneWidget);
  }

  group('Confirmação de reserva — "Valor previsto (€)"', () {
    for (final caso in [
      ('1.500,00', 150000),
      ('1 500,00', 150000),
      ('1500', 150000),
      ('1500,5', 150050),
    ]) {
      testWidgets('"${caso.$1}" grava ${caso.$2} cêntimos, não zero', (
        tester,
      ) async {
        final container = containerCom(estadoComMovimento());
        await abrirConfirmacaoDeReserva(tester, container);

        await tester.enterText(
          find.widgetWithText(TextField, 'Valor previsto (€)'),
          caso.$1,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Gravar reserva'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Confirmar reserva'), findsNothing);
        expect(
          container.read(operationsProvider).bookings.last.expectedValueCents,
          caso.$2,
        );
      });
    }

    testWidgets('vazio é legítimo: grava sem valor previsto e sem aviso', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await abrirConfirmacaoDeReserva(tester, container);

      await tester.tap(find.widgetWithText(FilledButton, 'Gravar reserva'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Confirmar reserva'), findsNothing);
      expect(
        container.read(operationsProvider).bookings.last.expectedValueCents,
        isNull,
      );
    });

    testWidgets('texto ilegível recusa a gravação com aviso, não grava zero', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      final antes = container.read(operationsProvider).bookings.length;
      await abrirConfirmacaoDeReserva(tester, container);

      await tester.enterText(
        find.widgetWithText(TextField, 'Valor previsto (€)'),
        'abc',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Gravar reserva'));
      await tester.pumpAndSettle();

      // O diálogo continua aberto, com o aviso visível — não fecha, não
      // grava, e não inventa um zero.
      expect(find.text('Confirmar reserva'), findsOneWidget);
      expect(find.textContaining('não percebi "abc"'), findsOneWidget);
      expect(container.read(operationsProvider).bookings.length, antes);
    });
  });

  group('Nova marcação — "Valor previsto (€)"', () {
    testWidgets('"1.500,00" grava 150000 cêntimos, não zero', (tester) async {
      final container = containerCom(estadoComMovimento());
      await abrirNovaMarcacao(tester, container);

      await tester.enterText(
        find.widgetWithText(TextField, 'Valor previsto (€)'),
        '1.500,00',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar marcação'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nova marcação / reserva'), findsNothing);
      expect(
        container.read(operationsProvider).bookings.last.expectedValueCents,
        150000,
      );
    });

    testWidgets('texto ilegível recusa a gravação com aviso, não grava zero', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      final antes = container.read(operationsProvider).bookings.length;
      await abrirNovaMarcacao(tester, container);

      await tester.enterText(
        find.widgetWithText(TextField, 'Valor previsto (€)'),
        'lixo',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar marcação'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nova marcação / reserva'), findsOneWidget);
      expect(find.textContaining('não percebi "lixo"'), findsOneWidget);
      expect(container.read(operationsProvider).bookings.length, antes);
    });
  });
}
