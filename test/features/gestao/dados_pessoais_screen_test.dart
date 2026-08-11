import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/gestao/data/dados_pessoais_service.dart';
import 'package:punho/features/gestao/presentation/dados_pessoais_screen.dart';

/// **Apagar uma ficha de três não é ter respondido ao pedido.**
///
/// Na prova de 11/8, «Casa Ferreira» estava três vezes na mesma empresa. Quem
/// recebe o pedido não sabe disso — vê um nome. Se o ecrã mostrasse as três em
/// lista, sem dizer nada, o gestor apagava a primeira, via a confirmação, e ia
/// à vida dele convencido de que estava feito.
///
/// O aviso é a peça que impede essa resposta falsa. Estes testes são sobre ele.
void main() {
  Widget comFichas(List<FichaDeTitular> fichas, {String termo = 'Ferreira'}) =>
      ProviderScope(
        overrides: [
          termoDeProcuraProvider.overrideWith((ref) => termo),
          fichasEncontradasProvider.overrideWith((ref) async => fichas),
          apagamentosFeitosProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: DadosPessoaisScreen()),
      );

  FichaDeTitular ficha(String id, {bool jaApagado = false}) => FichaDeTitular(
    entidade: 'customer',
    entidadeId: id,
    revisoes: 3,
    jaApagado: jaApagado,
    nome: 'Casa Ferreira',
    contacto: '913111111',
  );

  testWidgets('sem procurar não mostra fichas nenhumas', (tester) async {
    await tester.pumpWidget(comFichas(const [], termo: ''));
    await tester.pumpAndSettle();

    expect(find.text('Comece por procurar.'), findsOneWidget);
    expect(find.text('Apagar'), findsNothing);
  });

  testWidgets('três fichas da mesma pessoa avisam que são três', (
    tester,
  ) async {
    await tester.pumpWidget(comFichas([ficha('a'), ficha('b'), ficha('c')]));
    await tester.pumpAndSettle();

    expect(find.text('3 fichas desta pessoa.'), findsOneWidget);
    expect(
      find.text('Para o pedido ficar respondido, tem de apagar as 3.'),
      findsOneWidget,
    );
    expect(find.text('Apagar'), findsNWidgets(3));
  });

  testWidgets('uma ficha só não inventa aviso nenhum', (tester) async {
    await tester.pumpWidget(comFichas([ficha('a')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('fichas desta pessoa'), findsNothing);
    expect(find.text('Apagar'), findsOneWidget);
  });

  testWidgets('quem já foi apagado não se apaga outra vez', (tester) async {
    await tester.pumpWidget(
      comFichas([ficha('a', jaApagado: true), ficha('b')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Já apagado'), findsOneWidget);
    // Duas fichas, mas só uma por apagar — e por isso sem aviso de várias.
    expect(find.text('Apagar'), findsOneWidget);
    expect(find.textContaining('fichas desta pessoa'), findsNothing);
  });

  testWidgets('o botão de apagar cumpre o alvo de toque de 48 dp', (
    tester,
  ) async {
    await tester.pumpWidget(comFichas([ficha('a')]));
    await tester.pumpAndSettle();

    final alvo = tester.getSize(find.widgetWithText(TextButton, 'Apagar'));
    expect(alvo.height, greaterThanOrEqualTo(48));
  });

  testWidgets('nada é apagado só por se procurar', (tester) async {
    await tester.pumpWidget(comFichas([ficha('a')]));
    await tester.pumpAndSettle();

    // O apagamento passa sempre por uma confirmação que diz o que sai e que
    // avisa que não tem volta.
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.text('Apagar os dados de Casa Ferreira?'), findsOneWidget);
    expect(find.textContaining('Não tem volta.'), findsOneWidget);
    expect(find.text('Não apagar'), findsOneWidget);
  });
}
