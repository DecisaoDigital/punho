import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/layout/escala_de_desktop.dart';

void main() {
  test('janela do tamanho do telemóvel não é ampliada', () {
    expect(EscalaDeDesktop.escalaPara(const Size(820, 392)), 1.0);
    expect(EscalaDeDesktop.escalaPara(const Size(700, 300)), 1.0);
  });

  test('1920x1010 amplia até ao máximo e mantém o espaço lógico >= referência', () {
    const janela = Size(1920, 1010);
    final s = EscalaDeDesktop.escalaPara(janela);
    expect(s, 1.6);
    expect(janela.width / s, greaterThanOrEqualTo(820));
    expect(janela.height / s, greaterThanOrEqualTo(392));
  });

  test('1280x720 amplia sem passar a altura de referência', () {
    const janela = Size(1280, 720);
    final s = EscalaDeDesktop.escalaPara(janela);
    expect(s, closeTo(1.56, 0.01));
    expect(janela.height / s, greaterThanOrEqualTo(392));
  });
}
