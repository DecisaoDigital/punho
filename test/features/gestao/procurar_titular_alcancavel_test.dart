import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  /// Percorre a árvore de semântica à procura de um nó com este nome.
  ///
  /// Olha para o `label` **e** para o `tooltip`: o texto de um `Tooltip` não vai
  /// para o rótulo, vai para um campo próprio. Um teste que só olhasse para o
  /// `label` não encontrava o botão nem quando ele está bem — e concluía que
  /// estava sempre partido.
  SemanticsNode? procurarNo(SemanticsNode raiz, String rotulo) {
    SemanticsNode? achado;
    void visitar(SemanticsNode no) {
      if (achado != null) return;
      final dados = no.getSemanticsData();
      if (dados.label.contains(rotulo) || dados.tooltip.contains(rotulo)) {
        achado = no;
        return;
      }
      no.visitChildren((filho) {
        visitar(filho);
        return achado == null;
      });
    }

    visitar(raiz);
    return achado;
  }

  testWidgets('o botão de procurar tem geometria na árvore de acessibilidade', (
    tester,
  ) async {
    // Sem isto a árvore nem sequer é construída, e o teste passa sempre.
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DadosPessoaisScreen()),
      ),
    );
    await tester.pump();

    final raiz = tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final botao = procurarNo(raiz, 'Procurar');

    expect(botao, isNotNull, reason: 'o botão de procurar não está na árvore');
    expect(
      botao!.rect.isEmpty,
      isFalse,
      reason:
          'o «Procurar» tem ${botao.rect.width}×${botao.rect.height} — um nó '
          'sem área não se pode focar nem activar com um leitor de ecrã',
    );
    // 48 é o mínimo do Material. Aqui não é só conforto: é a diferença entre
    // conseguir e não conseguir.
    expect(botao.rect.width, greaterThanOrEqualTo(48));
    expect(botao.rect.height, greaterThanOrEqualTo(48));
    semantica.dispose();
  });

  testWidgets('o campo de procura anuncia-se uma vez, não duas', (tester) async {
    // Era isto que o `Semantics` a mais fazia: dois nós encaixados, com o mesmo
    // rectângulo e nomes diferentes. Conta-se quantos nós têm rótulo e a mesma
    // área do campo — se voltar a haver mais do que um, alguém voltou a embrulhar.
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DadosPessoaisScreen()),
      ),
    );
    await tester.pump();

    final raiz = tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final campo = procurarNo(raiz, 'Quem procurar')!;

    var comAMesmaArea = 0;
    void contar(SemanticsNode no) {
      final dados = no.getSemanticsData();
      if (dados.label.isNotEmpty && no.rect == campo.rect) comAMesmaArea++;
      no.visitChildren((filho) {
        contar(filho);
        return true;
      });
    }

    contar(raiz);

    expect(
      comAMesmaArea,
      1,
      reason: 'o campo de procura está a ser anunciado $comAMesmaArea vezes',
    );
    semantica.dispose();
  });

  testWidgets('o campo continua a dizer o que quer', (tester) async {
    // A correcção tirou o `Semantics` que dava o nome «Quem procurar». O nome
    // não se perdeu — passou para o rótulo, que é onde já devia estar. Sem
    // isto, a correcção de um problema criava outro em silêncio.
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DadosPessoaisScreen()),
      ),
    );
    await tester.pump();

    final raiz = tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode!;

    expect(procurarNo(raiz, 'Quem procurar'), isNotNull);
    semantica.dispose();
  });

  testWidgets('começa por dizer que nada se apaga sem procurar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DadosPessoaisScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Comece por procurar'), findsOneWidget);
    expect(find.text('Apagar'), findsNothing);
  });
}
