import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/domain/models/company_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('a navegação começa em Gestão e muda para Clientes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navigationProvider), AppDestination.management);
    container.read(navigationProvider.notifier).goTo(AppDestination.clients);
    expect(container.read(navigationProvider), AppDestination.clients);
  });

  test('Veículos só é visível quando a empresa tem frota', () {
    const withFleet = CompanySettings(
      hasFleet: true,
      activeCollaboratorLimit: 5,
    );
    const withoutFleet = CompanySettings(
      hasFleet: false,
      activeCollaboratorLimit: 5,
    );

    expect(visibleDestinations(withFleet), contains(AppDestination.vehicles));
    expect(
      visibleDestinations(withoutFleet),
      isNot(contains(AppDestination.vehicles)),
    );
  });
}
