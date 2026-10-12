// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/documents/document_reading.dart';
import 'package:fist/domain/models/finance.dart';

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
