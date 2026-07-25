import '../../domain/models/finance.dart';

class FieldSuggestion<T> {
  const FieldSuggestion(this.value, this.confidence);
  final T? value;
  final double confidence;
  bool get requiresConfirmation => value == null || confidence < .8;
}

class DocumentExtraction {
  const DocumentExtraction({
    this.merchant,
    this.date,
    this.totalCents,
    this.currency = 'EUR',
    this.text = '',
    this.keywords = const [],
  });
  final FieldSuggestion<String>? merchant;
  final FieldSuggestion<DateTime>? date;
  final FieldSuggestion<int>? totalCents;
  final String currency, text;
  final List<String> keywords;
}

abstract interface class LeitorQrFatura {
  Future<String?> read(String documentPath);
}

abstract interface class ExtratorDadosDocumento {
  Future<DocumentExtraction> extract(String documentPath);
}

class UnsupportedLocalExtractor implements ExtratorDadosDocumento {
  const UnsupportedLocalExtractor();
  @override
  Future<DocumentExtraction> extract(String _) async =>
      const DocumentExtraction();
}

ExpenseCategory? suggestExpenseCategory(Iterable<String> words) {
  final text = words.join(' ').toLowerCase();
  if (RegExp(r'combustível|gasolineira|gasóleo').hasMatch(text)) {
    return ExpenseCategory.fuel;
  }
  if (RegExp(r'oficina|peça|reparação').hasMatch(text)) {
    return ExpenseCategory.machineMaintenance;
  }
  if (RegExp(r'restaurante|café|refeição').hasMatch(text)) {
    return ExpenseCategory.meals;
  }
  if (RegExp(r'meta|facebook|google ads|publicidade').hasMatch(text)) {
    return ExpenseCategory.advertising;
  }
  if (text.contains('seguradora')) return ExpenseCategory.vehicleInsurance;
  return null;
}
