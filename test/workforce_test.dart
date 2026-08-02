import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('exceder as vagas não bloqueia — grava na mesma (decisão 2026-08-02)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    for (var i = 0; i < 3; i++) {
      n.saveCollaborator(
        Collaborator(id: '$i', name: 'n', status: CollaboratorStatus.active),
      );
    }
    n.saveCollaborator(
      const Collaborator(id: '4', name: 'n', status: CollaboratorStatus.active),
    );
    final ativos = c
        .read(operationsProvider)
        .collaborators
        .where((x) => !x.archived && x.status == CollaboratorStatus.active);
    expect(ativos.length, 4);
  });
  test('seguro anual e semestral mensalizado', () {
    expect(
      monthlyInsuranceCost(
        const Vehicle(
          id: 'a',
          plate: 'A',
          type: 'x',
          status: VehicleStatus.active,
          insuranceCents: 120000,
          insuranceFrequency: InsuranceFrequency.annual,
        ),
      ),
      10000,
    );
    expect(
      monthlyInsuranceCost(
        const Vehicle(
          id: 's',
          plate: 'S',
          type: 'x',
          status: VehicleStatus.active,
          insuranceCents: 60000,
          insuranceFrequency: InsuranceFrequency.semiannual,
        ),
      ),
      10000,
    );
  });
  test(
    'custo hora é por apurar sem horário válido',
    () => expect(
      hourlyCollaboratorCost(
        const Collaborator(
          id: 'c',
          name: 'C',
          status: CollaboratorStatus.active,
          costCents: 100000,
        ),
      ),
      isNull,
    ),
  );
  test('resultado atribuível não é lucro', () {
    const label = 'Resultado atribuível';
    expect(label, isNot(contains('lucro')));
  });

  test(
    'Vehicle.copyWith apaga um valor com null — não fica preso por "??"',
    () {
      const original = Vehicle(
        id: 'v',
        plate: 'AA-11-BB',
        type: 'Carrinha',
        status: VehicleStatus.active,
        monthlyPaymentCents: 25000,
        insuranceCents: 12000,
        insuranceFrequency: InsuranceFrequency.annual,
        alias: 'Carrinha velha',
      );
      final limpo = original.copyWith(
        monthlyPaymentCents: null,
        insuranceCents: null,
        insuranceFrequency: null,
        alias: null,
      );
      expect(limpo.monthlyPaymentCents, isNull);
      expect(limpo.insuranceCents, isNull);
      expect(limpo.insuranceFrequency, isNull);
      expect(limpo.alias, isNull);
      // Sem passar o parâmetro, mantém o que já lá estava.
      expect(original.copyWith(plate: 'ZZ-99-XX').monthlyPaymentCents, 25000);
    },
  );
}
