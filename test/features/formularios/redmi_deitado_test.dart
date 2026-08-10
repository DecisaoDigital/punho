import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// Os seis formulários no ecrã em que vão ser usados.
///
/// Não é um tamanho escolhido: é o Redmi Note 10 Pro deitado, medido — 872,7 ×
/// 392,7 dp, o teclado leva 200,4 e sobram 192,3 de altura para 761,6 de
/// largura de corpo. Todos os testes de formulário que existiam corriam a
/// 1280×800 ou a 900×500, onde tudo cabe. A altura é que mata, e nenhum a
/// exercitava.
///
/// Cada teste aqui é uma afirmação que tem de ser verdade no aparelho dele.
/// Falhar aqui é o objectivo: é mais barato do que falhar na mão de um cliente.
void main() {
  // O ecrã em dp. `devicePixelRatio` a 1.0 porque o que se mede é layout, e em
  // dp os números lêem-se — 2400 físicos a 2.75 são estes 872,7.
  const ecra = Size(872.7, 392.7);
  const teclado = 200.4;
  const alturaUtil = 392.7 - teclado; // 192,3 dp

  /// O entalhe de um lado e a barra de gestos do outro. O total é o que conta:
  /// 81,1 dp que a `SafeArea` come antes das margens de 15 do canvas, e é daí
  /// que saem os 761,6 dp de corpo.
  const bordas = FakeViewPadding(left: 40.6, right: 40.5);

  Future<void> montarNoRedmi(
    WidgetTester tester,
    ProviderContainer container,
    Widget child,
  ) async {
    tester.view.physicalSize = ecra;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = bordas;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PunhoTheme.light,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// O que o sistema faz quando um campo ganha o foco.
  void abrirTeclado(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: teclado);
    addTearDown(tester.view.resetViewInsets);
  }

  /// Abre um dos seis, pelo caminho por onde ele se abre na app.
  ///
  /// A lista abre-se sem teclado — é o estado real: primeiro toca-se em
  /// "Adicionar", só depois num campo. O teclado sobe a seguir, em cada teste.
  Future<ProviderContainer> abrir(WidgetTester tester, String qual) async {
    final container = containerCom(estadoComMovimento());
    final (Widget pagina, String botao) = switch (qual) {
      'máquina' => (const MachinesPage(), 'Adicionar máquina'),
      'cliente' => (const ClientsPage(), 'Novo cliente'),
      'lead' => (const ClientsPage(), 'Novo lead'),
      'colaborador' => (const CollaboratorsPage(), 'Adicionar colaborador'),
      'veículo' => (const VehiclesPage(), 'Adicionar veículo'),
      'marcação' => (
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showBookingForm(context, ref),
            child: const Text('abrir marcação'),
          ),
        ),
        'abrir marcação',
      ),
      _ => throw ArgumentError('formulário desconhecido: $qual'),
    };
    await montarNoRedmi(tester, container, pagina);
    await tester.ensureVisible(find.text(botao).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(botao).first);
    await tester.pumpAndSettle();
    expect(
      find.byType(EcraDeFormulario),
      findsOneWidget,
      reason: 'o formulário de $qual não abriu',
    );
    return container;
  }

  /// O último campo de texto de cada formulário — o que fica mais longe do topo
  /// e portanto o primeiro a desaparecer por baixo do teclado.
  const ultimoCampo = {
    'máquina': 'Notas / manutenção',
    'cliente': 'Notas',
    'lead': 'Telemóvel',
    'colaborador': 'Horas semanais previstas',
    'veículo': 'Manutenção prevista — valor anual (€)',
    'marcação': 'Notas',
  };

  const todos = [
    'máquina',
    'cliente',
    'lead',
    'colaborador',
    'veículo',
    'marcação',
  ];

  // ---------------------------------------------------------------------
  // 1. O campo em foco fica visível quando o teclado abre.
  //
  // O que se prova é o que se vê a escrever, não a moldura do campo. A
  // diferença é real e foi medida: no formulário da máquina, com as notas
  // vazias e o teclado a abrir, a caixa acaba 12,7 dp abaixo do teclado — o
  // `EditableText` sobe o cursor e pára aí. À primeira tecla o campo sobe
  // inteiro. Exigir a moldura seria exigir uma coisa que ninguém vive; exigir
  // que se veja o que se escreve é a afirmação que interessa.
  // ---------------------------------------------------------------------
  group('vê-se o que se está a escrever', () {
    for (final qual in todos) {
      testWidgets('$qual — o último campo, com o teclado por cima', (
        tester,
      ) async {
        await abrir(tester, qual);
        final campo = find.widgetWithText(TextField, ultimoCampo[qual]!).last;

        // Tocar no campo é o que abre o teclado. A ordem importa: primeiro o
        // foco, depois os `viewInsets` — é assim que o sistema o faz, e é essa
        // ordem que já partiu isto antes.
        await tester.ensureVisible(campo);
        await tester.pumpAndSettle();
        await tester.tap(campo);
        await tester.pump();
        abrirTeclado(tester);
        await tester.pumpAndSettle();
        await tester.enterText(campo, 'a escrever aqui');
        await tester.pumpAndSettle();

        // A linha onde o cursor está — é essa que tem de se ver, e não a
        // moldura toda. Num campo de três linhas ainda vazio, as duas de baixo
        // podem estar tapadas: quando se lá chegar, sobem.
        final estado = tester.state<EditableTextState>(
          find.descendant(of: campo, matching: find.byType(EditableText)),
        );
        final desenho = estado.renderEditable;
        final cursor = desenho.getLocalRectForCaret(
          TextPosition(offset: estado.textEditingValue.text.length),
        );
        final origem = desenho.localToGlobal(Offset.zero);
        final fundo = origem.dy + cursor.bottom;
        final topo = origem.dy + cursor.top;
        expect(
          fundo,
          lessThanOrEqualTo(alturaUtil),
          reason:
              'a linha que se escreve em "${ultimoCampo[qual]}" acaba a '
              '${fundo.toStringAsFixed(1)} dp, e o teclado começa aos '
              '${alturaUtil.toStringAsFixed(1)}',
        );
        expect(
          topo,
          greaterThanOrEqualTo(0),
          reason: 'o campo subiu para fora do ecrã pelo topo',
        );
      });
    }
  });

  // ---------------------------------------------------------------------
  // 2. O botão de gravar é sempre alcançável com o teclado aberto.
  // ---------------------------------------------------------------------
  group('o Guardar está sempre alcançável', () {
    for (final qual in todos) {
      testWidgets('$qual — com o teclado aberto', (tester) async {
        await abrir(tester, qual);
        abrirTeclado(tester);
        await tester.pumpAndSettle();

        final guardar = find
            .descendant(
              of: find.byType(EcraDeFormulario),
              matching: find.byType(FilledButton),
            )
            .first;
        final caixa = tester.getRect(guardar);
        expect(
          caixa.bottom,
          lessThanOrEqualTo(alturaUtil),
          reason: 'o botão de guardar nasce debaixo do teclado',
        );
        // Alcançável não é só estar à vista: tem de responder ao toque.
        await tester.tap(guardar);
        await tester.pumpAndSettle();
      });
    }
  });

  // ---------------------------------------------------------------------
  // 3. Rodar a meio do preenchimento não perde o que já foi escrito.
  // ---------------------------------------------------------------------
  group('rodar não deita fora o que já se escreveu', () {
    for (final qual in todos) {
      testWidgets('$qual — deitado, em pé, deitado outra vez', (tester) async {
        await abrir(tester, qual);
        final primeiro = find
            .descendant(
              of: find.byType(EcraDeFormulario),
              matching: find.byType(TextField),
            )
            .first;
        await tester.enterText(primeiro, 'Escrito antes de rodar');
        await tester.pumpAndSettle();

        // Em pé.
        tester.view.physicalSize = const Size(392.7, 872.7);
        await tester.pumpAndSettle();
        expect(
          find.text('Escrito antes de rodar'),
          findsOneWidget,
          reason: 'rodar para retrato perdeu o texto',
        );

        // E de volta.
        tester.view.physicalSize = ecra;
        await tester.pumpAndSettle();
        expect(find.text('Escrito antes de rodar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---------------------------------------------------------------------
  // 4. Zero overflow com o teclado aberto — o teste que corre todos os campos.
  // ---------------------------------------------------------------------
  group('nenhum rebenta com o teclado aberto', () {
    for (final qual in todos) {
      testWidgets('$qual — a percorrer campo a campo', (tester) async {
        await abrir(tester, qual);
        abrirTeclado(tester);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'rebentou logo ao abrir com o teclado',
        );

        // Um overflow pode só aparecer com um campo específico à vista: é o
        // scroll que muda o que está montado. Percorre-se o formulário até ao
        // fim, como quem preenche.
        final campos = find.descendant(
          of: find.byType(EcraDeFormulario),
          matching: find.byType(TextField),
        );
        for (var i = 0; i < campos.evaluate().length; i++) {
          await tester.ensureVisible(campos.at(i));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'rebentou ao chegar ao campo $i',
          );
        }
      });
    }
  });

  // ---------------------------------------------------------------------
  // 5. A validação aparece onde ele a vê.
  // ---------------------------------------------------------------------
  group('a recusa aparece acima do teclado', () {
    const comValidacao = {
      'máquina': 'Indica o nome da máquina.',
      'cliente': 'O nome é obrigatório.',
      'colaborador': 'Indica o nome do colaborador.',
    };

    for (final entrada in comValidacao.entries) {
      testWidgets('${entrada.key} — guardar em branco avisa à vista', (
        tester,
      ) async {
        await abrir(tester, entrada.key);
        abrirTeclado(tester);
        await tester.pumpAndSettle();

        final guardar = find
            .descendant(
              of: find.byType(EcraDeFormulario),
              matching: find.byType(FilledButton),
            )
            .first;
        await tester.tap(guardar);
        await tester.pumpAndSettle();

        final aviso = find.text(entrada.value);
        expect(
          aviso,
          findsOneWidget,
          reason: 'guardar em branco não recusou, ou recusou em silêncio',
        );
        expect(
          tester.getRect(aviso).bottom,
          lessThanOrEqualTo(alturaUtil),
          reason: 'o aviso nasceu debaixo do teclado — é o mesmo que não haver',
        );
        expect(find.byType(EcraDeFormulario), findsOneWidget);
      });
    }
  });

  // ---------------------------------------------------------------------
  // 6. Voltar atrás não deita fora em silêncio.
  // ---------------------------------------------------------------------
  group('sair com coisas escritas pergunta primeiro', () {
    for (final qual in todos) {
      testWidgets('$qual — o X pergunta antes de deitar fora', (tester) async {
        await abrir(tester, qual);
        final primeiro = find
            .descendant(
              of: find.byType(EcraDeFormulario),
              matching: find.byType(TextField),
            )
            .first;
        await tester.enterText(primeiro, 'Meio preenchido');
        await tester.pumpAndSettle();
        abrirTeclado(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();

        expect(
          find.text('Sair sem guardar?'),
          findsOneWidget,
          reason: 'um toque no X deitou fora o formulário sem avisar',
        );
      });
    }
  });

  // ---------------------------------------------------------------------
  // 7. `1.250,00` grava 1250 euros — não `null`, não 1,25.
  // ---------------------------------------------------------------------
  testWidgets('o preço escrito à portuguesa grava o valor certo', (
    tester,
  ) async {
    final container = await abrir(tester, 'máquina');
    abrirTeclado(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome'),
      'Escavadora de teste',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Preço diário de aluguer (€)'),
      '1.250,00',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor de compra (€) — opcional'),
      '18.500',
    );
    await tester.tap(
      find
          .descendant(
            of: find.byType(EcraDeFormulario),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final maquina = container
        .read(operationsProvider)
        .machines
        .firstWhere((m) => m.name == 'Escavadora de teste');
    expect(maquina.dailyRateCents, 125000, reason: '1.250,00 são 1250 €');
    // Sem casas decimais e com ponto: quem escreve isto em Portugal está a
    // escrever dezoito mil e quinhentos, não dezoito euros e meio.
    expect(maquina.purchasePriceCents, 1850000);
  });

  // ---------------------------------------------------------------------
  // 8. O teclado que abre é o do campo.
  // ---------------------------------------------------------------------
  group('cada campo abre o teclado certo', () {
    /// Um campo de dinheiro sem `decimal: true` abre o teclado de inteiros do
    /// Android: não tem vírgula nenhuma. O campo aceita cêntimos e o teclado
    /// não deixa escrevê-los — e quem está a preencher não tem como saber que
    /// o problema é o teclado.
    void exigeDecimal(WidgetTester tester, String rotulo) {
      final campo = tester.widget<TextField>(
        find.widgetWithText(TextField, rotulo).last,
      );
      expect(
        campo.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
        reason: 'o campo "$rotulo" é de dinheiro e precisa da vírgula',
      );
    }

    void exigeTeclado(
      WidgetTester tester,
      String rotulo,
      TextInputType esperado,
    ) {
      final campo = tester.widget<TextField>(
        find.widgetWithText(TextField, rotulo).last,
      );
      expect(campo.keyboardType, esperado, reason: 'campo "$rotulo"');
    }

    testWidgets('máquina — os dois campos de euros aceitam cêntimos', (
      tester,
    ) async {
      await abrir(tester, 'máquina');
      exigeDecimal(tester, 'Preço diário de aluguer (€)');
      exigeDecimal(tester, 'Valor de compra (€) — opcional');
    });

    testWidgets('veículo — prestação, seguro e manutenção aceitam cêntimos', (
      tester,
    ) async {
      await abrir(tester, 'veículo');
      exigeDecimal(tester, 'Prestação mensal (€)');
      exigeDecimal(tester, 'Seguro (€)');
      exigeDecimal(tester, 'Manutenção prevista — valor anual (€)');
      exigeTeclado(tester, 'Dia do débito', TextInputType.number);
    });

    testWidgets('colaborador — o custo é dinheiro, não é uma contagem', (
      tester,
    ) async {
      await abrir(tester, 'colaborador');
      exigeDecimal(tester, 'Custo estimado para a empresa (€)');
      exigeTeclado(tester, 'Telemóvel', TextInputType.phone);
      exigeTeclado(tester, 'Horas semanais previstas', TextInputType.number);
    });

    testWidgets('cliente — telefone, NIF e email cada um com o seu', (
      tester,
    ) async {
      await abrir(tester, 'cliente');
      // 'Telemóvel *': o contacto do cliente é obrigatório desde 10 de Agosto
      // de 2026. O do colaborador e o da lead continuam sem asterisco.
      exigeTeclado(tester, 'Telemóvel *', TextInputType.phone);
      exigeTeclado(tester, 'NIF', TextInputType.number);
      exigeTeclado(tester, 'Email', TextInputType.emailAddress);
    });

    testWidgets('lead — o telemóvel abre o teclado de telefone', (
      tester,
    ) async {
      await abrir(tester, 'lead');
      exigeTeclado(tester, 'Telemóvel', TextInputType.phone);
    });

    testWidgets('marcação — o valor previsto aceita cêntimos', (tester) async {
      await abrir(tester, 'marcação');
      exigeDecimal(tester, 'Valor previsto (€)');
    });
  });
}
