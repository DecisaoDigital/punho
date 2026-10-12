// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import '../../domain/models/company_settings.dart';

abstract interface class CompanySettingsRepository {
  CompanySettings getSettings();
}

class LocalDemoCompanySettingsRepository implements CompanySettingsRepository {
  const LocalDemoCompanySettingsRepository();

  @override
  CompanySettings getSettings() =>
      const CompanySettings(hasFleet: true, activeCollaboratorLimit: 5);
}
