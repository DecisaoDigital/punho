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

/// Os destinos da barra lateral, **sempre os mesmos** (Decisão 2).
///
/// Deixou de haver destinos condicionais. Antes, "Funcionários" só aparecia com
/// colaboradores declarados e "Frota" só com frota — o que fazia a barra mudar
/// de forma consoante o estado dos dados, e o gestor aprendia uma navegação que
/// depois se mexia. Uma barra que muda não se decora.
///
/// Finanças e Veículos saíram da barra e são agora abas de **Empresa**.
///
/// Eram sete e passaram a oito a 4 de Agosto de 2026, com **A minha semana**
/// (Fase 0 do `docs/PLANO_DO_CICLO.md`). A Decisão 2 proibia destinos
/// *condicionais* — o mal era a barra mudar sozinha, não ter mais um item.
/// Entra a seguir ao Painel e não à frente dele: enquanto a carteira for curta
/// a lista aparece vazia, e uma lista vazia é uma péssima primeira coisa a ver
/// ao abrir a app. Passa a primeiro quando a Fase 1 estiver no terreno.
List<AppDestination> visibleOperationalDestinations(OperationsState state) =>
    const [
      AppDestination.management,
      AppDestination.semana,
      AppDestination.bookings,
      AppDestination.clients,
      AppDestination.machines,
      AppDestination.employees,
      AppDestination.empresa,
      AppDestination.tasks,
    ];
