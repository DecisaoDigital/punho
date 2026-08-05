import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// Quem ainda não tem reserva no período que está no calendário.
///
/// O gestor escolhe a máquina, marca os períodos e só depois diz de quem é a
/// reserva. Nessa lista, numa semana cheia, quase toda a gente já lá está — e
/// quem ele procura é justamente quem falta.
void main() {
  const ana = Customer(id: 'ana', name: 'Ana', phone: '');
  const bruno = Customer(id: 'bruno', name: 'Bruno', phone: '');
  const clientes = [ana, bruno];

  final semana = DateTimeRange(
    start: DateTime(2026, 8, 3),
    end: DateTime(2026, 8, 10),
  );

  Booking reservaDe(String customerId, DateTime inicio, DateTime fim) =>
      Booking(
        id: 'r-$customerId-${inicio.day}',
        customerId: customerId,
        machineIds: const ['m1'],
        startsAt: inicio,
        endsAt: fim,
        status: BookingStatus.confirmed,
      );

  test('sem reservas nenhumas, ninguém é filtrado', () {
    expect(clientesSemReservaNoPeriodo(clientes, const [], semana), [
      ana,
      bruno,
    ]);
  });

  test('quem tem reserva dentro da semana sai da lista', () {
    final reservas = [
      reservaDe('ana', DateTime(2026, 8, 5), DateTime(2026, 8, 6)),
    ];

    expect(clientesSemReservaNoPeriodo(clientes, reservas, semana), [bruno]);
  });

  test('quem atravessa a semana toda também sai', () {
    // O caso que uma comparação só pelo início deixaria passar: a reserva não
    // começa nem acaba dentro da semana, mas ocupa-a de ponta a ponta.
    final reservas = [
      reservaDe('bruno', DateTime(2026, 7, 28), DateTime(2026, 8, 20)),
    ];

    expect(clientesSemReservaNoPeriodo(clientes, reservas, semana), [ana]);
  });

  test('reserva de outra semana não conta', () {
    final reservas = [
      reservaDe('ana', DateTime(2026, 8, 11), DateTime(2026, 8, 12)),
    ];

    expect(clientesSemReservaNoPeriodo(clientes, reservas, semana), [
      ana,
      bruno,
    ]);
  });

  test('uma reserva que acaba quando a semana começa não a ocupa', () {
    // Fronteira: acaba exactamente no instante em que a semana abre. Se isto
    // contasse, quem devolveu a máquina no domingo à noite ficava de fora da
    // semana seguinte.
    final reservas = [
      reservaDe('ana', DateTime(2026, 7, 30), DateTime(2026, 8, 3)),
    ];

    expect(clientesSemReservaNoPeriodo(clientes, reservas, semana), [
      ana,
      bruno,
    ]);
  });

  test(
    'o cliente escolhido que sai da lista deixa de contar como presente',
    () {
      expect(clientesContem(const [ana], 'bruno'), isFalse);
      expect(clientesContem(const [ana], 'ana'), isTrue);
      // Nada escolhido é um estado legítimo, e não um id em falta.
      expect(clientesContem(const [ana], null), isTrue);
    },
  );
}
