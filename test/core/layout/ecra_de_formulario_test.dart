import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';

/// O que se prova aqui é o que não se consegue provar no telemóvel: a app
/// tranca paisagem no `AppShell`, por isso a coluna única de retrato nunca
/// aparece num Redmi. Aparece numa janela estreita — e é isso que se mede.
void main() {
  Future<void> montar(
    WidgetTester tester, {
    required Size ecra,
    required List<Widget> campos,
    VoidCallback? aoGuardar,
  }) async {
    tester.view.physicalSize = ecra;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: EcraDeFormulario(
          titulo: 'Teste',
          campos: campos,
          aoGuardar: aoGuardar ?? () {},
        ),
      ),
    );
  }

  List<Widget> quatroCampos(List<TextEditingController> cs) => [
    for (var i = 0; i < cs.length; i++)
      CampoDeTexto(controlador: cs[i], rotulo: 'Campo ${i + 1}'),
  ];

  testWidgets('numa janela estreita fica tudo numa coluna', (tester) async {
    final cs = List.generate(4, (_) => TextEditingController());
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
    });
    await montar(tester, ecra: const Size(400, 800), campos: quatroCampos(cs));

    final xs = <double>{
      for (var i = 1; i <= 4; i++)
        tester.getTopLeft(find.byType(TextField).at(i - 1)).dx,
    };
    // Uma coluna = todos os campos começam na mesma abcissa.
    expect(xs.length, 1);
  });

  testWidgets('numa janela larga reparte-se por colunas', (tester) async {
    final cs = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
    });
    await montar(tester, ecra: const Size(1000, 800), campos: quatroCampos(cs));

    final xs = <double>{
      for (var i = 0; i < 6; i++)
        tester.getTopLeft(find.byType(TextField).at(i)).dx,
    };
    // 1000 dp menos margens dá para três colunas de 250.
    expect(xs.length, 3);
  });

  testWidgets('não sobra coluna vazia a estreitar as outras', (tester) async {
    final cs = List.generate(4, (_) => TextEditingController());
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
    });
    await montar(tester, ecra: const Size(1000, 800), campos: quatroCampos(cs));

    // Quatro campos em três colunas dariam 2+2+0. A vazia não fica.
    final xs = <double>{
      for (var i = 0; i < 4; i++)
        tester.getTopLeft(find.byType(TextField).at(i)).dx,
    };
    expect(xs.length, 2);
  });

  testWidgets('um campo de várias linhas ocupa a largura toda', (tester) async {
    final curto = TextEditingController();
    final notas = TextEditingController();
    addTearDown(() {
      curto.dispose();
      notas.dispose();
    });
    final outros = List.generate(3, (_) => TextEditingController());
    addTearDown(() {
      for (final c in outros) {
        c.dispose();
      }
    });
    await montar(
      tester,
      ecra: const Size(1000, 800),
      campos: [
        CampoDeTexto(controlador: curto, rotulo: 'Curto'),
        for (var i = 0; i < 3; i++)
          CampoDeTexto(controlador: outros[i], rotulo: 'Outro $i'),
        CampoDeTexto(controlador: notas, rotulo: 'Notas', linhas: 3),
      ],
    );

    final larguraCurto = tester.getSize(find.byType(TextField).at(0)).width;
    final larguraNotas = tester.getSize(find.byType(TextField).at(4)).width;
    expect(larguraNotas, greaterThan(larguraCurto));
  });

  testWidgets('o Seguinte passa o foco pela ordem da lista', (tester) async {
    final cs = List.generate(3, (_) => TextEditingController());
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
    });
    await montar(tester, ecra: const Size(400, 800), campos: quatroCampos(cs));

    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(0))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    // O que a tecla *Seguinte* faz.
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('o último campo pede ✓ e não →', (tester) async {
    final cs = List.generate(2, (_) => TextEditingController());
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
    });
    await montar(tester, ecra: const Size(400, 800), campos: quatroCampos(cs));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).textInputAction,
      TextInputAction.next,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).textInputAction,
      TextInputAction.done,
    );
  });

  testWidgets('sair com texto por guardar pede confirmação', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Empurrado como rota, e não como `home`, porque é assim que a app o abre —
    // e é a rota que dá o botão de fecho na barra de topo.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => abrirFormulario<void>(
              context,
              (_) => EcraDeFormulario(
                titulo: 'Teste',
                campos: [CampoDeTexto(controlador: c, rotulo: 'Nome')],
                aoGuardar: () {},
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rui');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem guardar?'), findsOneWidget);

    // E continuar a preencher devolve o formulário, não a lista.
    await tester.tap(find.text('Continuar a preencher'));
    await tester.pumpAndSettle();
    expect(find.byType(EcraDeFormulario), findsOneWidget);
  });

  testWidgets('gravar não passa pelo aviso de saída', (tester) async {
    final c = TextEditingController();
    var gravou = false;
    addTearDown(c.dispose);
    await montar(
      tester,
      ecra: const Size(400, 800),
      campos: [CampoDeTexto(controlador: c, rotulo: 'Nome')],
      aoGuardar: () => gravou = true,
    );

    await tester.enterText(find.byType(TextField), 'Rui');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(gravou, isTrue);
    expect(find.text('Sair sem guardar?'), findsNothing);
  });
}
