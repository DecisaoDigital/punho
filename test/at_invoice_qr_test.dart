import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/documents/at_invoice_qr.dart';

void main() {
  test('lê os campos essenciais do QR de uma fatura AT', () {
    final value = AtInvoiceQrReader.parse(
      'A:500000000*B:999999990*C:PT*D:FT*E:N*F:20260726*G:FT A/123*H:ABC12345-123*I1:PT*N:2.30*O:12.30*Q:abcd*R:1234',
    );
    expect(value, isNotNull);
    expect(value!.supplierTaxId, '500000000');
    expect(value.totalCents, 1230);
    expect(value.taxCents, 230);
    expect(value.documentDate, DateTime(2026, 7, 26));
  });
}
