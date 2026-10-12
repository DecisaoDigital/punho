// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:fist/core/validacao_de_contacto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telemóvel', () {
    for (final ok in [
      '912345678',
      '912 345 678',
      '+351 912 345 678',
      '00351912345678',
      '+34 612345678',
      '253 123 456',
    ]) {
      expect(erroDeTelemovel(ok), isNull, reason: ok);
    }
    for (final mau in ['a@b.pt', '12345', '812345678', 'abc', '91234567']) {
      expect(erroDeTelemovel(mau), isNotNull, reason: mau);
    }
  });
  test('email', () {
    expect(erroDeEmail(''), isNull);
    expect(erroDeEmail('a@b.pt'), isNull);
    expect(erroDeEmail('912345678'), isNotNull);
    expect(erroDeEmail('a@b'), isNotNull);
  });
  test('nif', () {
    expect(erroDeNif(''), isNull);
    expect(erroDeNif('123456789'), isNull);
    expect(erroDeNif('12345'), isNotNull);
  });
}
