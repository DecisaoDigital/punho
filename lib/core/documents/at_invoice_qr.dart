// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:io';

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
  /// Só há leitor de QR em Android e iOS (ML Kit). No Windows devolve `null`,
  /// como uma foto sem código: a despesa fica com o documento anexado e o
  /// utilizador preenche os valores à mão, em vez de o fluxo rebentar com um
  /// `MissingPluginException`.
  static Future<AtInvoiceQrData?> readFromImage(String imagePath) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
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
        !fields.containsKey('O')) {
      return null;
    }
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
