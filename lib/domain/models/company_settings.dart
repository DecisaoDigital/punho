/// Configuração local da empresa. Será obtida do backend numa fase futura.
class CompanySettings {
  const CompanySettings({
    required this.hasFleet,
    required this.activeCollaboratorLimit,
  });

  final bool hasFleet;
  final int activeCollaboratorLimit;
}
