import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'keeps onboarding and operational records after repository recreation',
    () async {
      final first = await PersistentOperationRepository.create();
      first.saveOnboarding(
        const OnboardingData(
          companyName: 'Alugueres Norte',
          legalForm: 'Lda.',
          hasFleet: true,
          collaborators: 2,
          totalMachinesDeclared: 4,
          insertMachinesNow: true,
        ),
      );
      first.saveMachine(
        const Machine(
          id: 'persisted-machine',
          name: 'Gerador',
          reference: 'G-01',
          category: 'Energia',
          status: MachineStatus.available,
          photoPaths: ['/dados/punho/maquina-gerador.jpg'],
        ),
      );
      first.saveHistoricalMonth(
        const HistoricalMonth(
          year: 2025,
          month: 5,
          revenueReceivedCents: 450000,
          leadsReceived: 80,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      final restored = await PersistentOperationRepository.create();

      expect(restored.onboarding?.companyName, 'Alugueres Norte');
      expect(
        restored.machines.any((machine) => machine.id == 'persisted-machine'),
        isTrue,
      );
      expect(
        restored.machines
            .firstWhere((machine) => machine.id == 'persisted-machine')
            .photoPaths,
        ['/dados/punho/maquina-gerador.jpg'],
      );
      expect(restored.historicalMonths, hasLength(1));
      expect(restored.historicalMonths.single.revenueReceivedCents, 450000);
    },
  );
}
