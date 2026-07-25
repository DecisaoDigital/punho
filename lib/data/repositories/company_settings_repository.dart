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
