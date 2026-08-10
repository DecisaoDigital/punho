import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/dashboard/presentation/widgets/kpi_grid_2x2.dart';

/// **A célula deitada** — a da bancada, onde é uma por linha e a largura é toda
/// dela.
///
/// O que estes testes guardam é uma medida, não um gosto. A 10 de Agosto de
/// 2026 a bancada mostrava a célula da grelha 2×2 esticada à largura toda:
/// doze das catorze do catálogo enchiam entre **47% e 65%** dos 555 dp, com
/// 150 dp de altura para conteúdo que precisa de 62. Deitada, o rótulo e o
/// número partilham a primeira linha e o número encosta à direita — é assim que
/// a largura passa a ser usada em vez de sobrar.
void main() {
  const largura = 555.0;

  // `find.byType(RichText)` apanha também o rótulo — um `Text` é um `RichText`
  // por dentro. O número identifica-se pelo que diz.
  final oNumero = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains('12 480'),
  );

  Future<void> montar(WidgetTester tester, CelulaSemaforo celula) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: largura,
                height: AlturaDoKpi.deitado,
                child: celula.deitada(),
              ),
            ),
          ),
        ),
      );

  const comValor = CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Dinheiros que entraram',
    valor: '12 480',
    unidade: '€ este mês',
    subtexto: 'Hoje: 320 € · ▲ 18% previsto vs mesmo mês do ano passado',
  );

  testWidgets('o rótulo e o número dividem a primeira linha', (tester) async {
    await montar(tester, comValor);

    final rotulo = tester.getRect(find.text('DINHEIROS QUE ENTRARAM'));
    final numero = tester.getRect(oNumero);

    // Sobrepõem-se na vertical: é isso que faz disto uma linha e não duas.
    expect(
      numero.top < rotulo.bottom && rotulo.top < numero.bottom,
      isTrue,
      reason: 'o número voltou a descer para debaixo do rótulo',
    );
    // E o número está à direita do rótulo, não por baixo dele.
    expect(numero.left, greaterThan(rotulo.left));
  });

  testWidgets('o número encosta à direita — a largura é usada', (tester) async {
    await montar(tester, comValor);

    final caixa = tester.getRect(find.byType(CelulaSemaforo));
    final numero = tester.getRect(oNumero);

    // 14 dp de margem interior à direita, mais um dedo de tolerância. Se o
    // número parar a meio da célula, voltámos aos 50%.
    expect(
      caixa.right - numero.right,
      lessThan(20),
      reason: 'o número deixou de encostar à direita',
    );
  });

  testWidgets('deitar não deita nada fora: texto e subtexto viajam juntos', (
    tester,
  ) async {
    // As células à espera de dados têm a instrução no `texto` («Regista um
    // recebimento») e o caminho no `subtexto` («Toca para abrir Finanças»).
    // Deitar a célula não é razão para deixar cair metade da instrução.
    await montar(
      tester,
      const CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: 'Dinheiros que entraram',
        texto: 'Regista um recebimento',
        subtexto: 'Toca para abrir Finanças',
      ),
    );

    expect(
      find.text('Regista um recebimento · Toca para abrir Finanças'),
      findsOneWidget,
    );
  });

  testWidgets('cabe na altura medida, e num cartão estreito também', (
    tester,
  ) async {
    for (final w in [largura, 300.0, 200.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: w,
                height: AlturaDoKpi.deitado,
                child: comValor.deitada(),
              ),
            ),
          ),
        ),
      );
      // Sem transbordo: o rótulo e o número encolhem os dois em vez de um
      // deles empurrar o outro para fora. Já transbordou 7,5 px a 300 dp.
      expect(tester.takeException(), isNull, reason: 'transbordou a $w dp');
    }
  });

  testWidgets('de pé continua de pé — a grelha não muda', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 250,
              height: AlturaDoKpi.normal,
              child: comValor,
            ),
          ),
        ),
      ),
    );

    final rotulo = tester.getRect(find.text('DINHEIROS QUE ENTRARAM'));
    final numero = tester.getRect(oNumero);

    expect(
      numero.top,
      greaterThanOrEqualTo(rotulo.bottom),
      reason: 'a célula da grelha 2×2 é empilhada, e assim tem de ficar',
    );
  });
}
