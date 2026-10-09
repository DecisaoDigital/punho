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
