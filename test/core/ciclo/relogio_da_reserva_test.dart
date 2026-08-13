import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/ciclo/relogio_da_reserva.dart';
import 'package:punho/domain/models/operations.dart';

/// **O relógio é que manda no estado da marcação.**
///
/// Regra do César, 13 de Agosto de 2026: «o tempo actual é que diz e assume o
/// estado da encomenda. Se não foi editada, nem cancelada, considera-se que
/// avança para entrega, e avança para recolha no fim do período de tempo» — e
/// logo a seguir: «só pode ter sido concluída quando foi instalada e recolhida,
/// isso é automático».
void main() {
  final inicio = DateTime(2026, 8, 20, 9);
  final fim = DateTime(2026, 8, 22, 18);

  Booking reserva({
    BookingStatus estado = BookingStatus.confirmed,
    String id = 'b1',
  }) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: inicio,
    endsAt: fim,
    status: estado,
  );

  group('antes do dia de entrega o relógio não manda', () {
    // É a janela do comercial: combinar preço, mandar orçamento, ter o sim do
    // cliente. Nada disto o tempo sabe fazer sozinho.
    for (final estado in [
      BookingStatus.request,
      BookingStatus.proposalSent,
      BookingStatus.confirmed,
    ]) {
      test('$estado fica como está', () {
        expect(
          estadoPeloRelogio(reserva(estado: estado), DateTime(2026, 8, 19, 23)),
          estado,
        );
      });
    }
  });

  test('no dia de início passa a Em aluguer, tenha sido confirmada ou não', () {
    // Mesmo um pedido que ninguém chegou a confirmar: se o dia chegou e
    // ninguém a cancelou, considera-se que a máquina foi entregue.
    expect(
      estadoPeloRelogio(reserva(estado: BookingStatus.request), inicio),
      BookingStatus.rented,
    );
    expect(
      estadoPeloRelogio(reserva(), DateTime(2026, 8, 21, 10)),
      BookingStatus.rented,
    );
  });

  test('no fim do período passa a Concluída', () {
    expect(estadoPeloRelogio(reserva(), fim), BookingStatus.completed);
    expect(
      estadoPeloRelogio(reserva(), DateTime(2026, 9, 1)),
      BookingStatus.completed,
    );
  });

  test('cancelada é intocável — o tempo não a desfaz', () {
    expect(
      estadoPeloRelogio(
        reserva(estado: BookingStatus.cancelled),
        DateTime(2026, 9, 1),
      ),
      BookingStatus.cancelled,
    );
  });

  group('o que há a gravar', () {
    test('só as que mudaram — e nada quando não há nada', () {
      final jaEmDia = [
        reserva(estado: BookingStatus.confirmed),
        reserva(id: 'b2', estado: BookingStatus.cancelled),
      ];
      expect(reservasAAvancar(jaEmDia, DateTime(2026, 8, 19)), isEmpty);
    });

    test('uma volta mexida, a outra não', () {
      final lista = [
        reserva(estado: BookingStatus.confirmed),
        reserva(id: 'cancelada', estado: BookingStatus.cancelled),
      ];
      final mexidas = reservasAAvancar(lista, DateTime(2026, 9, 1));

      expect(mexidas.map((r) => r.id), ['b1']);
      expect(mexidas.single.status, BookingStatus.completed);
    });

    test('correr duas vezes não muda mais nada — é idempotente', () {
      final lista = [reserva()];
      final primeira = reservasAAvancar(lista, DateTime(2026, 9, 1));
      expect(primeira, hasLength(1));
      expect(reservasAAvancar(primeira, DateTime(2026, 9, 1)), isEmpty);
    });
  });
}
