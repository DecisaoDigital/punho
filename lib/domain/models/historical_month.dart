// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

/// Resumo de um mês anterior antes de existir importação automática.
class HistoricalMonth {
  const HistoricalMonth({
    required this.year,
    required this.month,
    this.revenueReceivedCents,
    this.paidExpensesCents,
    this.advertisingSpendCents,
    this.leadsReceived,
    this.convertedLeads,
    this.maintenanceCents,
  }) : assert(month >= 1 && month <= 12);

  final int year, month;
  final int? revenueReceivedCents, paidExpensesCents, advertisingSpendCents;
  final int? leadsReceived, convertedLeads, maintenanceCents;

  bool get hasAnyData => [
    revenueReceivedCents,
    paidExpensesCents,
    advertisingSpendCents,
    leadsReceived,
    convertedLeads,
    maintenanceCents,
  ].any((value) => value != null);
}
