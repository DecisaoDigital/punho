enum AccessProfile { mainManager, collaborator }

extension AccessProfileLabel on AccessProfile {
  String get label => switch (this) {
    AccessProfile.mainManager => 'Main / Gestor',
    AccessProfile.collaborator => 'Colaborador',
  };
}
