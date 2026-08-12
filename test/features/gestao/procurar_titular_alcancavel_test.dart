import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/gestao/presentation/dados_pessoais_screen.dart';

/// **O botão de procurar tem de ter tamanho, e o campo um nome só.**
///
/// Nasceu de um susto e de um erro meu. A 12/8/2026, a ler o despejo de
/// `uiautomator` no Redmi, li «Procurar» com um rectângulo de zero por zero e
/// dei o botão por inalcançável para um leitor de ecrã. Não era: o `grep`
/// apanhou primeiro um nó fantasma que o `Tooltip` cria, e não o botão. Medido
/// aqui, o botão tem 48×48 — com o `Semantics` que eu culpava e sem ele.
///
/// O que ficou de verdadeiro foi outra coisa, mais pequena e mais real: o
/// `Semantics(textField: true, label: …)` que envolvia o campo produzia **dois
/// nós encaixados com o mesmo rectângulo**, e quem ouve o ecrã ouvia o campo
/// duas vezes com nomes diferentes. Isso corrigiu-se.
///
/// Estes testes guardam as duas coisas — a geometria do botão e o nome único do
/// campo — porque nenhuma delas aparece num teste que só procure widgets:
/// `find.byTooltip('Procurar')` encontra-o e `tester.tap` acerta, porque um
/// teste toca em coordenadas e não em nós de acessibilidade.
void main() {
  /// Monta o ecrã com a árvore de semântica ligada e devolve o punho que a
  /// mantém viva. Fecha-se sempre no fim — uma árvore que fica de pé estraga
  /// os testes seguintes, e foi assim que estes três passaram sozinhos e
  /// falharam na suite inteira.
  Future<void> comSemantica(
    WidgetTester tester,
    Future<void> Function() corpo,
  ) async {
    final punho = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DadosPessoaisScreen())),
      );
      await tester.pump();
      await corpo();
    } finally {
      // `finally` e não `addTearDown`: o teardown corre **depois** da
      // verificação que se queixa de punhos por fechar, portanto um teste que
      // falhasse deixava a árvore de pé e estragava os seguintes.
      punho.dispose();
    }
  }

  testWidgets('o botão de procurar tem área para um leitor de ecrã', (
    tester,
  ) async {
    await comSemantica(tester, () async {
      // `getSemantics` e não um passeio pela árvore a partir da raiz: é a API
      // que o Flutter suporta, e não depende de quem é o dono do pipeline nesse
      // momento — que muda conforme a suite corre sozinha ou inteira.
      final botao = tester.getSemantics(find.byTooltip('Procurar'));

      expect(
        botao.rect.isEmpty,
        isFalse,
        reason: 'um nó sem área não se pode focar nem activar',
      );
      expect(botao.rect.width, greaterThanOrEqualTo(48));
      expect(botao.rect.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('o campo de procura anuncia-se uma vez, não duas', (tester) async {
    // Era isto que o `Semantics` a mais fazia: dois nós encaixados com o mesmo
    // rectângulo, um a dizer «Quem procurar» e outro a dizer o resto. Quem ouve
    // o ecrã ouvia o campo duas vezes, com nomes diferentes.
    await comSemantica(tester, () async {
      expect(find.bySemanticsLabel(RegExp('Quem procurar')), findsOneWidget);
    });
  });

  testWidgets('o nome que o `Semantics` dava não se perdeu', (tester) async {
    // A correcção tirou o embrulho que dizia «Quem procurar». O nome passou
    // para o rótulo, que é onde já devia estar — sem isto, corrigir uma coisa
    // partia outra em silêncio.
    await comSemantica(tester, () async {
      expect(
        find.bySemanticsLabel(
          RegExp('Quem procurar — nome, contribuinte, telefone ou email'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('começa por dizer que nada se apaga sem procurar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DadosPessoaisScreen())),
    );
    await tester.pump();

    expect(find.textContaining('Comece por procurar'), findsOneWidget);
    expect(find.text('Apagar'), findsNothing);
  });
}
