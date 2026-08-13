import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/kpis/apreciacao.dart';

/// **A regra que transforma um número numa leitura.**
///
/// «cada KPI deve ter na sua frente as regras de apreciação do próprio. "Estás
/// com 50% de conversão, estás acima da média em 3%!" Se for inferior à média,
/// também deve ter uma frase para mostrar» — Cesar, 5/8/2026.
///
/// A regra é uma só para toda a app: se cada cartão inventasse a sua, "acima da
/// média" queria dizer coisas diferentes conforme o ecrã.
void main() {
  String euros(num cents) => '${(cents / 100).toStringAsFixed(2)} €';

  ApreciacaoDoKpi caso(
    num? valor,
    num? referencia, {
    bool maisEMelhor = true,
  }) => apreciar(
    valor: valor,
    referencia: referencia,
    nomeDaReferencia: 'a tua média',
    formatar: euros,
    maisEMelhor: maisEMelhor,
  );

  group('acima e abaixo', () {
    test('acima da média diz quanto, e diz que é acima', () {
      final a = caso(103, 100);

      expect(a.frase, 'Estás acima da tua média em 3%.');
      expect(a.tom, TomDaApreciacao.acima);
    });

    test('abaixo da média também tem frase — não fica em branco', () {
      // A metade do pedido que é fácil esquecer: má notícia também se diz.
      final a = caso(80, 100);

      expect(a.frase, 'Estás abaixo da tua média em 20%.');
      expect(a.tom, TomDaApreciacao.abaixo);
    });

    test('em custos, subir é a má notícia', () {
      final a = caso(120, 100, maisEMelhor: false);

      expect(a.tom, TomDaApreciacao.abaixo);
      expect(a.frase, contains('abaixo'));
    });
  });

  group('quando calar é mais honesto', () {
    test('sem referência não se inventa uma média', () {
      final a = caso(50, null);

      expect(a.tom, TomDaApreciacao.semTermo);
      expect(a.frase, 'Sem termo de comparação.');
    });

    test('sem valor também não há apreciação', () {
      expect(caso(null, 100).tom, TomDaApreciacao.semTermo);
    });

    test('diferença que arredonda a zero lê-se como "em linha"', () {
      // Meio por cento escrevia-se "acima da tua média em 0%" — uma frase que
      // ocupa a linha e não diz nada. Os 3% do exemplo dele passam.
      final a = caso(100.5, 100);

      expect(a.tom, TomDaApreciacao.emLinha);
      expect(a.frase, 'Em linha com a tua média.');
    });
  });

  group('percentagens que mentiriam', () {
    test('média a zero: diz-se a diferença, não uma divisão impossível', () {
      final a = caso(2500, 0);

      expect(a.frase, 'Estás acima da tua média em 25.00 €.');
      expect(a.tom, TomDaApreciacao.acima);
    });

    test('de prejuízo para lucro não se descreve com uma percentagem', () {
      // Média −500, mês +1000. A conta daria "+300%", que soa a crescimento
      // quando o que houve foi uma inversão de sinal.
      final a = caso(1000, -500);

      expect(a.frase, contains('15.00 €'));
      expect(a.frase, isNot(contains('%')));
    });

    test(
      'dois meses negativos comparam-se na mesma — perder menos é melhor',
      () {
        final a = caso(-200, -500);

        expect(a.tom, TomDaApreciacao.acima);
        expect(a.frase, 'Estás acima da tua média em 60%.');
      },
    );
  });
}
