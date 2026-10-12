// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DemoRole { manager, collaboratorA, collaboratorB }

class DemoSession {
  const DemoSession(this.role);
  final DemoRole role;
  bool get isManager => role == DemoRole.manager;
  String? get collaboratorId => switch (role) {
    DemoRole.collaboratorA => 'collab-a',
    DemoRole.collaboratorB => 'collab-b',
    DemoRole.manager => null,
  };
  String get label => switch (role) {
    DemoRole.manager => 'Gestor',
    DemoRole.collaboratorA => 'Colaborador A',
    DemoRole.collaboratorB => 'Colaborador B',
  };
}

final demoSessionProvider =
    NotifierProvider<DemoSessionController, DemoSession>(
      DemoSessionController.new,
    );

class DemoSessionController extends Notifier<DemoSession> {
  @override
  DemoSession build() => const DemoSession(DemoRole.manager);
  void select(DemoRole role) => state = DemoSession(role);
}
