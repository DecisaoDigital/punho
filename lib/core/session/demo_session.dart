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
