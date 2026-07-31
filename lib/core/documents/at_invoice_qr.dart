import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Dados úteis extraídos do QR das faturas portuguesas.
/// Os dados apenas pré-preenchem a despesa: o utilizador confirma-os sempre.
class AtInvoiceQrData {
  const AtInvoiceQrData({
    required this.raw,
    this.supplierTaxId,
    this.buyerTaxId,
    this.documentType,
    this.documentDate,
    this.documentNumber,
    this.atcud,
    this.taxCents,
    this.totalCents,
  });

  final String raw;
  final String? supplierTaxId, buyerTaxId, documentType, documentNumber, atcud;
  final DateTime? documentDate;
  final int? taxCents, totalCents;

  String get summary => [
    if (supplierTaxId != null) 'NIF fornecedor: $supplierTaxId',
    if (documentNumber != null) 'Documento: $documentNumber',
    if (atcud != null) 'ATCUD: $atcud',
  ].join(' · ');
}

abstract final class AtInvoiceQrReader {
  static Future<AtInvoiceQrData?> readFromImage(String imagePath) async {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final codes = await scanner.processImage(
        InputImage.fromFilePath(imagePath),
      );
      for (final code in codes) {
        final raw = code.rawValue;
        if (raw == null) continue;
        final parsed = parse(raw);
        if (parsed != null) return parsed;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  static AtInvoiceQrData? parse(String raw) {
    final fields = <String, String>{};
    for (final part in raw.split('*')) {
      final colon = part.indexOf(':');
      if (colon <= 0) continue;
      fields[part.substring(0, colon)] = part.substring(colon + 1);
    }
    if (!fields.containsKey('A') ||
        !fields.containsKey('F') ||
        !fields.containsKey('O'))
      return null;
    return AtInvoiceQrData(
      raw: raw,
      supplierTaxId: fields['A'],
      buyerTaxId: fields['B'],
      documentType: fields['D'],
      documentDate: _date(fields['F']),
      documentNumber: fields['G'],
      atcud: fields['H'],
      taxCents: _cents(fields['N']),
      totalCents: _cents(fields['O']),
    );
  }

  static DateTime? _date(String? value) {
    if (value == null || !RegExp(r'^\d{8}$').hasMatch(value)) return null;
    return DateTime.tryParse(
      '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}',
    );
  }

  static int? _cents(String? value) {
    final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
    return amount == null ? null : (amount * 100).round();
  }
}
