import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';

/// `Lead → Customer → Booking`: a cadeia que diz o que a origem rendeu.
///
/// **Porque existe.** `LeadStatus.converted` dizia que a lead se tornou
/// cliente, e mais nada — não dizia em quem. A cadeia partia-se logo no
/// primeiro elo, e por isso a pergunta que interessa a quem gasta em
/// publicidade — *quanto é que o Facebook me trouxe?* — só se podia responder
/// em contagens de leads, nunca em euros.
///
/// Fechada a cadeia, `Receipt.bookingId` faz o resto: a soma dos recebimentos
/// do trabalho que a lead originou é o que aquela origem rendeu.
void main() {
  ProviderContainer containerVazio() {
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);
    return container;
  }

  Lead lead({String id = 'l1', String telefone = '913 000 001'}) => Lead(
    id: id,
    name: 'Obra do Porto',
    phone: telefone,
    status: LeadStatus.newLead,
    createdAt: DateTime(2026, 8, 1),
    source: LeadSource.facebook,
  );

  test('converter uma lead deixa escrito em que cliente ela se tornou', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addLead(lead());

    final cliente = notifier.convertLead(lead());

    final convertida = c.read(operationsProvider).leads.single;
    expect(convertida.status, LeadStatus.converted);
    expect(convertida.convertedCustomerId, cliente.id);
  });

  test('converter duas vezes não parte o elo nem duplica o cliente', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addLead(lead());

    final primeira = notifier.convertLead(lead());
    final segunda = notifier.convertLead(c.read(operationsProvider).leads.single);

    expect(segunda.id, primeira.id);
    expect(c.read(operationsProvider).customers.length, 1);
    expect(
      c.read(operationsProvider).leads.single.convertedCustomerId,
      primeira.id,
    );
  });

  test('a lead que bate num cliente existente aponta para esse cliente', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addCustomer(
      const Customer(id: 'c-ja-existe', name: 'Obra do Porto', phone: '913 1'),
    );
    notifier.addLead(lead(telefone: '913 1'));

    // A conversão recusa-se — mas a origem daquele cliente ficou a saber-se
    // aqui, e é esse o elo que interessa guardar.
    expect(() => notifier.convertLead(lead(telefone: '913 1')), throwsStateError);
    expect(
      c.read(operationsProvider).leads.single.convertedCustomerId,
      'c-ja-existe',
    );
  });

  test('o primeiro trabalho do cliente fecha a cadeia, sozinho', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addLead(lead());
    final cliente = notifier.convertLead(lead());
    notifier.saveMachine(
      const Machine(
        id: 'm1',
        name: 'Mini escavadora',
        reference: 'ME-01',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );

    final conflito = notifier.addBooking(
      Booking(
        id: 'b1',
        customerId: cliente.id,
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 8, 10, 8),
        endsAt: DateTime(2026, 8, 12, 18),
        status: BookingStatus.confirmed,
      ),
    );

    expect(conflito, isNull);
    // Ninguém carregou num botão a dizer "esta reserva veio do Facebook": a
    // app já tinha o dado em mãos e ligou-o sozinha.
    expect(c.read(operationsProvider).leads.single.bookingId, 'b1');
  });

  test('só o primeiro trabalho conta — os seguintes são da relação', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addLead(lead());
    final cliente = notifier.convertLead(lead());
    notifier.saveMachine(
      const Machine(
        id: 'm1',
        name: 'Mini escavadora',
        reference: 'ME-01',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );

    for (final (id, dia) in [('b1', 10), ('b2', 20)]) {
      notifier.addBooking(
        Booking(
          id: id,
          customerId: cliente.id,
          machineIds: const ['m1'],
          startsAt: DateTime(2026, 8, dia, 8),
          endsAt: DateTime(2026, 8, dia + 2, 18),
          status: BookingStatus.confirmed,
        ),
      );
    }

    // Contar o segundo inflacionaria o retorno de quem trouxe o cliente uma
    // vez: a partir do segundo trabalho o mérito é da relação, não da campanha.
    expect(c.read(operationsProvider).leads.single.bookingId, 'b1');
  });

  test('uma reserva de um cliente sem lead não inventa cadeia nenhuma', () {
    final c = containerVazio();
    final notifier = c.read(operationsProvider.notifier);
    notifier.addLead(lead());
    notifier.addCustomer(
      const Customer(id: 'c-directo', name: 'Cliente de rua', phone: '913 9'),
    );
    notifier.saveMachine(
      const Machine(
        id: 'm1',
        name: 'Mini escavadora',
        reference: 'ME-01',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );

    notifier.addBooking(
      Booking(
        id: 'b1',
        customerId: 'c-directo',
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 8, 10, 8),
        endsAt: DateTime(2026, 8, 12, 18),
        status: BookingStatus.confirmed,
      ),
    );

    expect(c.read(operationsProvider).leads.single.bookingId, isNull);
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
