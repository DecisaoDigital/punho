import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// A semana toda de uma vez, sem rolar em duas direcções.
///
/// O calendário forçava 860 dp de largura mínima e vivia dentro de dois
/// SingleChildScrollView. Resultado: a linha da Tarde ficava abaixo da dobra e
/// metade da semana à direita. Escolher a máquina custava mais 64 dp de fila de
/// chips por cima disso.
void main() {
  Future<void> abrirReservas(
    WidgetTester tester, {
    Size tamanho = const Size(1280, 800),
  }) => montarLandscape(
    tester,
    containerCom(estadoComMovimento()),
    const BookingsPage(),
    tamanho: tamanho,
  );

  testWidgets('o botão diz Reservar, e "Marcações" não aparece em sítio nenhum', (
    tester,
  ) async {
    await abrirReservas(tester);

    expect(find.text('Reservar'), findsOneWidget);
    expect(find.text('Adicionar reserva'), findsNothing);
    // O cabeçalho do _PageFrame já não se desenha desde a v0.0.5 (o item da
    // barra lateral é que diz em que ecrã se está, e diz "Reservas"), mas o
    // título continua no construtor — vale a pena não deixar lá "Marcações /
    // Reservas" à espera de voltar a aparecer.
    expect(find.textContaining('Marcações'), findsNothing);
  });

  testWidgets('a máquina escolhe-se num dropdown na própria barra', (
    tester,
  ) async {
    await abrirReservas(tester);

    final dropdown = find.byType(DropdownButton<String>);
    expect(dropdown, findsOneWidget);
    expect(tester.getSize(dropdown).width, 240);
    // A fila de ChoiceChips desapareceu.
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('as duas metades do dia e os sete dias cabem sem rolar', (
    tester,
  ) async {
    await abrirReservas(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PE-02').last);
    await tester.pumpAndSettle();

    expect(find.text('Manhã'), findsOneWidget);
    expect(find.text('Tarde'), findsOneWidget);
    // Sete colunas de dia, todas dentro do ecrã.
    final celulas = find.byIcon(Icons.add_circle_outline);
    expect(celulas, findsNWidgets(14));
    for (final celula in celulas.evaluate()) {
      final caixa = tester.getRect(find.byWidget(celula.widget));
      expect(caixa.right, lessThanOrEqualTo(1280));
      expect(caixa.bottom, lessThanOrEqualTo(800));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem máquina escolhida diz o que falta, sem buraco no meio', (
    tester,
  ) async {
    await abrirReservas(tester);

    expect(
      find.text('Escolhe uma máquina para marcar os períodos livres.'),
      findsOneWidget,
    );
  });

  testWidgets('escolher períodos muda o rótulo do botão para Reservar (N)', (
    tester,
  ) async {
    await abrirReservas(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PE-02').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Reservar (1)'), findsOneWidget);
    expect(find.text('Limpar seleção'), findsOneWidget);
  });
}
