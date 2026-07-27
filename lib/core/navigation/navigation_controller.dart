import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/company_settings_repository.dart';
import '../../domain/models/company_settings.dart';
import '../operations/operations_controller.dart';
import 'app_destination.dart';

final companySettingsRepositoryProvider = Provider<CompanySettingsRepository>(
  (ref) => const LocalDemoCompanySettingsRepository(),
);

final companySettingsProvider = Provider<CompanySettings>(
  (ref) => ref.watch(companySettingsRepositoryProvider).getSettings(),
);

final navigationProvider =
    NotifierProvider<NavigationController, AppDestination>(
      NavigationController.new,
    );

class NavigationController extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.management;

  void goTo(AppDestination destination) => state = destination;
}

List<AppDestination> visibleDestinations(CompanySettings settings) => [
  AppDestination.management,
  AppDestination.employees,
  AppDestination.machines,
  AppDestination.clients,
  AppDestination.bookings,
  if (settings.hasFleet) AppDestination.vehicles,
];

List<AppDestination> visibleOperationalDestinations(OperationsState state) => [
  AppDestination.management,
  AppDestination.machines,
  AppDestination.clients,
  AppDestination.bookings,
  AppDestination.finances,
  if (state.declaredCollaboratorCount > 0) AppDestination.employees,
  if (state.hasFleet) AppDestination.vehicles,
  AppDestination.tasks,
];
