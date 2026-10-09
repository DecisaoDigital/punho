import 'package:fist/core/operations/preco_da_reserva.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Exemplo do César: 1 dia 80 €, 3 dias 140 €, 1 mês 500 €.
  const tabela = [
    Tarifa(dias: 1, cents: 8000),
    Tarifa(dias: 3, cents: 14000),
    Tarifa(dias: 30, cents: 50000),
  ];

  test('pacote exacto', () {
    expect(precoDaTabelaPorPeriodo(tabela, 1), 8000);
    expect(precoDaTabelaPorPeriodo(tabela, 3), 14000);
    expect(precoDaTabelaPorPeriodo(tabela, 30), 50000);
  });

  test('períodos intermédios: o conjunto mais barato que cobre', () {
    // 2 dias: 2×1 dia = 160 € ou 1 pacote de 3 = 140 € → 140 €.
    expect(precoDaTabelaPorPeriodo(tabela, 2), 14000);
    // 4 dias: 3+1 = 220 € (não há pacote de 4).
    expect(precoDaTabelaPorPeriodo(tabela, 4), 22000);
    // 20 dias: 6×3 dias = 840 € contra 1 mês 500 € → 500 €.
    expect(precoDaTabelaPorPeriodo(tabela, 20), 50000);
    // 31 dias: mês + 1 dia.
    expect(precoDaTabelaPorPeriodo(tabela, 31), 58000);
  });

  test('sem tabela não há preço', () {
    expect(precoDaTabelaPorPeriodo(const [], 3), isNull);
  });

  Machine maquina({List<Tarifa> t = const [], int? diario}) => Machine(
    id: 'm',
    name: 'A',
    reference: '1',
    category: 'Escavação',
    status: MachineStatus.available,
    dailyRateCents: diario,
    tarifas: t,
  );

  test('valor previsto: tabela > preço diário', () {
    final ini = DateTime(2026, 11, 1);
    expect(
      valorPrevistoDaTabela([maquina(t: tabela)], ini, DateTime(2026, 11, 3)),
      14000,
    );
    expect(
      valorPrevistoDaTabela(
        [maquina(diario: 9000)],
        ini,
        DateTime(2026, 11, 3),
      ),
      18000,
    );
    // meio dia à tabela = 1 dia (arredonda para cima).
    expect(
      valorPrevistoDaTabela(
        [maquina(t: tabela)],
        ini,
        DateTime(2026, 11, 1, 12),
      ),
      8000,
    );
  });

  test('tarifas fazem ida e volta; vazias não escrevem a chave', () {
    final json = PersistentOperationRepository.machineToJson(
      maquina(t: tabela),
    );
    expect(json['tarifas'], isNotEmpty);
    final volta = PersistentOperationRepository.machineFromJson(
      Map<String, dynamic>.from(json),
    );
    expect(volta.tarifas, tabela);
    final vazia = PersistentOperationRepository.machineToJson(maquina());
    expect(vazia.containsKey('tarifas'), isFalse);
  });

  group('categoria', () {
    ProviderContainer novo() {
      final c = ProviderContainer(
        overrides: [operationRepositoryProvider.overrideWithValue(_Vazio())],
      );
      addTearDown(c.dispose);
      return c;
    }

    Machine m(String id, String cat) => Machine(
      id: id,
      name: 'M$id',
      reference: id,
      category: cat,
      status: MachineStatus.available,
    );

    test('a tabela aplica-se a toda a categoria e só a ela', () {
      final c = novo();
      final n = c.read(operationsProvider.notifier);
      n.saveMachine(m('1', 'Escavação'));
      n.saveMachine(m('2', 'escavação '));
      n.saveMachine(m('3', 'Plataforma'));
      n.aplicarTarifasACategoria('Escavação', tabela);
      final ms = {for (final x in c.read(operationsProvider).machines) x.id: x};
      expect(ms['1']!.tarifas, tabela);
      expect(ms['2']!.tarifas, tabela);
      expect(ms['3']!.tarifas, isEmpty);
    });

    test('escolhe uma máquina livre da categoria', () {
      final c = novo();
      final n = c.read(operationsProvider.notifier);
      n.saveMachine(m('1', 'Escavação'));
      n.saveMachine(m('2', 'Escavação'));
      n.addCustomer(const Customer(id: 'c', name: 'Ana', phone: '910000000'));
      final ini = DateTime(2026, 12, 1);
      final fim = DateTime(2026, 12, 3);
      expect(n.maquinaLivreDaCategoria('Escavação', ini, fim)?.id, '1');
      n.addBooking(
        Booking(
          id: 'b',
          customerId: 'c',
          machineIds: const ['1'],
          startsAt: ini,
          endsAt: fim,
          status: BookingStatus.confirmed,
        ),
      );
      expect(n.maquinaLivreDaCategoria('Escavação', ini, fim)?.id, '2');
      expect(n.maquinaLivreDaCategoria('Outra', ini, fim), isNull);
    });
  });
}


class _Vazio extends LocalDemoOperationRepository {
  _Vazio() {
    resetAll();
  }
}
