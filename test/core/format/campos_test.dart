import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/format/campos.dart';

void main() {
  group('centsDeTexto', () {
    // Estes casos são os mesmos de `euros_test.ts`, no portal do contabilista.
    // Têm de ser: o contabilista escreve pelo portal, o gestor escreve pela
    // app, e os dois escrevem no mesmo histórico. Um `1.200` que valha coisas
    // diferentes conforme quem o escreveu é o mesmo campo com dois
    // significados — e não rebenta, grava-se em silêncio.
    const casos = <String, int?>{
      '1234,56': 123456,
      '1.234,56': 123456,
      '1234.56': 123456, // decimal inglês, de quem copiou de uma folha de cálculo
      '1234': 123400,
      '1.200': 120000, // mil e duzentos euros, não um euro e vinte
      '12.345.678': 1234567800,
      '1 234,50 €': 123450,
      '0': 0, // zero declarado — diferente de não saber
      '': null,
      '   ': null,
      'abc': null,
      '0,05': 5,
      '1.2': 120,
    };

    test('lê euros como as pessoas os escrevem', () {
      casos.forEach((entrada, esperado) {
        expect(
          centsDeTexto(entrada),
          esperado,
          reason: 'a ler ${entrada.isEmpty ? '(vazio)' : entrada}',
        );
      });
    });

    test('o ponto de milhares já não vale um cêntimo do que valia', () {
      // Era este o bug: `1.200` dava 120 cêntimos. Quem escrevesse mil e
      // duzentos euros ficava com um euro e vinte, e só dava por isso quando o
      // painel mostrasse um número que não fazia sentido.
      expect(centsDeTexto('1.200'), 120000);
      expect(centsDeTexto('12.000'), 1200000);
      // Três dígitos exactos depois do ponto são milhares; um ou dois são
      // decimais. É o que distingue `1.200` de `1.20`.
      expect(centsDeTexto('1.20'), 120);
    });

    test('ida e volta pelo campo não perde cêntimos', () {
      for (final esperado in casos.values) {
        if (esperado == null) continue;
        expect(centsDeTexto(textoDeCents(esperado)), esperado);
      }
    });

    test('negativo é recusado por omissão', () {
      // Num preço, num salário ou num custo, um negativo é engano — e recusar
      // é melhor do que guardar.
      expect(centsDeTexto('-450,25'), isNull);
      expect(centsDeTexto('-1.200'), isNull);
    });

    test('negativo passa onde faz sentido', () {
      // No histórico contabilístico faz: uma nota de crédito faz um mês valer
      // menos que zero.
      expect(centsDeTexto('-450,25', permitirNegativo: true), -45025);
      expect(centsDeTexto('-1.200', permitirNegativo: true), -120000);
    });

    test('vazio e ilegível são ambos nulos, e nenhum é zero', () {
      expect(centsDeTexto(''), isNull);
      expect(centsDeTexto('  '), isNull);
      expect(centsDeTexto('abc'), isNull);
      // Zero escrito é uma resposta: quer dizer que não houve nada.
      expect(centsDeTexto('0'), 0);
    });
  });

  group('textoDeCents', () {
    test('escreve como o campo espera, sem separador de milhares', () {
      // Sem separador de propósito: o campo é para reescrever, e um espaço no
      // meio de um número faz o teclado do telemóvel tropeçar.
      expect(textoDeCents(123456), '1234,56');
      expect(textoDeCents(0), '0,00');
      expect(textoDeCents(null), '');
    });
  });

  group('textoOpcional', () {
    test('em branco é ausência, não string vazia', () {
      expect(textoOpcional('  '), isNull);
      expect(textoOpcional(' Ana '), 'Ana');
    });
  });

  group('contagemDeTexto', () {
    test('vazio ou inválido conta zero — são números declarados', () {
      expect(contagemDeTexto(''), 0);
      expect(contagemDeTexto('abc'), 0);
      expect(contagemDeTexto('-3'), 0);
      expect(contagemDeTexto('7'), 7);
    });
  });

  group('nifValido', () {
    test('exige nove dígitos, e só a forma', () {
      expect(nifValido('123456789'), isTrue);
      expect(nifValido(' 123456789 '), isTrue);
      expect(nifValido('12345678'), isFalse);
      expect(nifValido('1234567890'), isFalse);
      expect(nifValido('12345678A'), isFalse);
    });
  });
}
