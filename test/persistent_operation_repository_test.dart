import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
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
    },
  );
}
