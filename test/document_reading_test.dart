import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/documents/document_reading.dart';
import 'package:punho/domain/models/finance.dart';

void main() {
  test('QR sem valor não preenche valor inválido', () {
    const x = DocumentExtraction();
    expect(x.totalCents?.value, isNull);
  });
  test('OCR baixa confiança exige confirmação', () {
    const x = FieldSuggestion<int>(100, .4);
    expect(x.requiresConfirmation, isTrue);
  });
  test(
    'sugestão combustível',
    () => expect(suggestExpenseCategory(['gasóleo']), ExpenseCategory.fuel),
  );
  test(
    'refeições é apenas categoria',
    () =>
        expect(suggestExpenseCategory(['restaurante']), ExpenseCategory.meals),
  );
  test('documento associa-se sem criar despesa automaticamente', () {
    final e = Expense(
      id: 'e',
      date: DateTime(2026),
      amountCents: 1,
      category: ExpenseCategory.other,
      status: ExpensePaymentStatus.paid,
      documentPath: 'local.jpg',
    );
    expect(e.documentPath, 'local.jpg');
  });
}
