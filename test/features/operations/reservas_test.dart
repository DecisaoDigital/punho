import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
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

  testWidgets(
    'o botão diz Reservar, e "Marcações" não aparece em sítio nenhum',
    (tester) async {
      await abrirReservas(tester);

      expect(find.text('Reservar'), findsOneWidget);
      expect(find.text('Adicionar reserva'), findsNothing);
      // O cabeçalho do _PageFrame já não se desenha desde a v0.0.5 (o item da
      // barra lateral é que diz em que ecrã se está, e diz "Reservas"), mas o
      // título continua no construtor — vale a pena não deixar lá "Marcações /
      // Reservas" à espera de voltar a aparecer.
      expect(find.textContaining('Marcações'), findsNothing);
    },
  );

  testWidgets('máquina, datas e Reservar partilham a linha do topo', (
    tester,
  ) async {
    // O Cesar pediu: "máquina e data devem estar na mesma linha e alinhados
    // pelo topo do botão + Reservar". Antes viviam numa segunda barra que, num
    // telemóvel deitado, partia em duas ou três linhas e roubava altura ao
    // calendário.
    await abrirReservas(tester);

    final dropdown = find.byType(DropdownButton<String>);
    expect(dropdown, findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    // Alinhados pelo topo: o dropdown e o botão começam à mesma altura.
    final botao = find.widgetWithText(FilledButton, 'Reservar');
    expect(botao, findsOneWidget);
    expect(
      (tester.getTopLeft(dropdown).dy - tester.getTopLeft(botao).dy).abs(),
      lessThan(24),
    );
  });

  testWidgets('as duas metades do dia e os sete dias cabem sem rolar', (
    tester,
  ) async {
    await abrirReservas(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PE-02').last);
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
      find.text(
        'A ver todas as máquinas. Escolhe uma para marcar '
        'períodos livres.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('escolher períodos muda o rótulo do botão para Reservar (N)', (
    tester,
  ) async {
    await abrirReservas(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PE-02').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Reservar (1)'), findsOneWidget);
    expect(find.text('Limpar seleção'), findsOneWidget);
  });

  testWidgets('o cliente escolhe-se no diálogo, e pode criar-se ali mesmo', (
    tester,
  ) async {
    // O Cesar carregou em "+ Reservar" e concluiu que não havia campo de
    // cliente. Havia — mas quando a empresa ainda não tinha clientes o diálogo
    // nem chegava a abrir: mostrava um aviso e desistia. Agora abre sempre, e
    // o cliente cria-se sem sair do calendário.
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
    // 'Cliente *': obrigatório desde que ninguém vem escolhido de fábrica.
    expect(find.text('Cliente *'), findsOneWidget);

    // E a saída para criar um cliente novo está na própria lista.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Novo cliente…'), findsWidgets);
  });

  testWidgets('tocar num período sem máquina põe o aviso a vermelho', (
    tester,
  ) async {
    await abrirReservas(tester);

    Color? corDoAviso() => tester
        .widget<Text>(find.textContaining('Escolhe uma para marcar'))
        .style
        ?.color;

    // Antes de tocar, é uma frase como outra qualquer.
    expect(corDoAviso(), isNot(const Color(0xFFB3261E)));

    // A célula tem de responder ao toque mesmo sem máquina escolhida: estava
    // com `onTap: null` e quem tocasse não recebia sinal nenhum.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    // Passada a piscadela, fica vermelho — o problema não desapareceu só
    // porque a animação acabou.
    expect(corDoAviso(), const Color(0xFFB3261E));
    // E não marcou nada: sem máquina não há reserva para fazer.
    expect(find.textContaining('Reservar ('), findsNothing);
  });

  testWidgets('escolher a máquina devolve o aviso ao normal', (tester) async {
    await abrirReservas(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PE-02').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Escolhe uma para marcar'), findsNothing);
  });

  _todasAsMaquinas();
}

/// **«Todas as máquinas»** — a vista de entrada do calendário desde 10 de
/// Agosto de 2026, e durante um dia mostrou um calendário em branco: o filtro
/// devolvia lista vazia quando não havia máquina escolhida. O César, no
/// telemóvel: «"Todas as máquinas" não mostra todas as reservas da semana de
/// todas as máquinas — ou do mês».
void _todasAsMaquinas() {
  // Esta semana, para caírem na vista que abre por omissão.
  final segunda = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).subtract(Duration(days: DateTime.now().weekday - DateTime.monday));

  OperationsState comDuasReservas() => estadoComMovimento().copyWith(
    bookings: [
      Booking(
        id: 'b-m1',
        customerId: 'c1',
        customerNameSnapshot: 'Construções Silva',
        machineIds: const ['m1'],
        startsAt: segunda.add(const Duration(days: 1)),
        endsAt: segunda.add(const Duration(days: 2)),
        status: BookingStatus.confirmed,
      ),
      Booking(
        id: 'b-m2',
        customerId: 'c2',
        customerNameSnapshot: 'João Pereira',
        machineIds: const ['m2'],
        startsAt: segunda.add(const Duration(days: 3)),
        endsAt: segunda.add(const Duration(days: 4)),
        status: BookingStatus.confirmed,
      ),
    ],
  );

  group('Todas as máquinas', () {
    testWidgets('a semana mostra as reservas de todas as máquinas', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(comDuasReservas()),
        const BookingsPage(),
      );

      // Nenhuma máquina escolhida: é a vista «Todas».
      expect(find.textContaining('ME-01'), findsWidgets);
      expect(find.textContaining('PE-02'), findsWidgets);
      expect(find.textContaining('Construções Silva'), findsWidgets);
      expect(find.textContaining('João Pereira'), findsWidgets);
    });

    testWidgets('o mês também', (tester) async {
      await montarLandscape(
        tester,
        containerCom(comDuasReservas()),
        const BookingsPage(),
      );

      await tester.tap(find.text('Mês'));
      await tester.pumpAndSettle();

      // Pelo nome do cliente, e não pela referência da máquina: essa também
      // vive no selector do topo, e o teste passaria com o calendário vazio.
      expect(find.textContaining('Construções Silva'), findsWidgets);
      expect(find.textContaining('João Pereira'), findsWidgets);
    });

    /// «pelo menos as células deveriam estar de outra cor» — com o parque todo
    /// à vista, as etiquetas dizem *o quê* mas não dão a leitura de relance de
    /// *onde há trabalho*.
    testWidgets('escolher uma máquina volta a mostrar só a dela', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(comDuasReservas()),
        const BookingsPage(),
      );

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ME-01').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('João Pereira'), findsNothing);
      expect(find.textContaining('Construções Silva'), findsWidgets);
    });
  });

  group('a cor da célula', () {
    const cores = ColorScheme.light();

    test('ocupada distingue-se de vazia', () {
      expect(
        corDeCelula(cores: cores, seleccionada: false, ocupada: true),
        isNot(corDeCelula(cores: cores, seleccionada: false, ocupada: false)),
      );
      expect(
        corDeCelula(cores: cores, seleccionada: false, ocupada: false),
        isNull,
        reason: 'a célula livre é o fundo do ecrã, e é isso que a convida',
      );
    });

    test('escolher para marcar manda sobre estar ocupada', () {
      expect(
        corDeCelula(cores: cores, seleccionada: true, ocupada: true),
        cores.primaryContainer,
      );
    });

    test('fora do mês não se confunde com ocupada', () {
      expect(
        corDeCelula(
          cores: cores,
          seleccionada: false,
          ocupada: false,
          foraDoMes: true,
        ),
        cores.surfaceContainerHighest,
      );
      expect(
        corDeCelula(
          cores: cores,
          seleccionada: false,
          ocupada: true,
          foraDoMes: true,
        ),
        cores.surfaceContainerHighest,
        reason: 'um dia de outro mês é ruído, mesmo com reservas lá dentro',
      );
    });
  });
}
