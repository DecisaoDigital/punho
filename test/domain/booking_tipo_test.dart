import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _base({BookingTipo tipo = BookingTipo.maquina}) => Booking(
  id: 'b1',
  customerId: 'c1',
  machineIds: const [],
  startsAt: DateTime(2026, 10, 12, 10),
  endsAt: DateTime(2026, 10, 12, 11),
  status: BookingStatus.confirmed,
  tipo: tipo,
  lembreteMinutos: tipo == BookingTipo.reuniao ? 15 : null,
  criadoPorUid: 'u1',
);

void main() {
  test('reserva antiga sem o campo vale como máquina', () {
    final json = Map<String, dynamic>.from(
      PersistentOperationRepository.bookingToJson(_base()),
    )..remove('tipo');
    final b = PersistentOperationRepository.bookingFromJson(json);
    expect(b.tipo, BookingTipo.maquina);
    expect(b.eReuniao, isFalse);
  });

  test('tipo desconhecido vale como máquina, sem rebentar', () {
    final json = Map<String, dynamic>.from(
      PersistentOperationRepository.bookingToJson(_base()),
    )..['tipo'] = 'visita_do_futuro';
    expect(
      PersistentOperationRepository.bookingFromJson(json).tipo,
      BookingTipo.maquina,
    );
  });

  test('reunião faz ida e volta com lembrete e autor', () {
    final b = PersistentOperationRepository.bookingFromJson(
      Map<String, dynamic>.from(
        PersistentOperationRepository.bookingToJson(
          _base(tipo: BookingTipo.reuniao),
        ),
      ),
    );
    expect(b.tipo, BookingTipo.reuniao);
    expect(b.lembreteMinutos, 15);
    expect(b.criadoPorUid, 'u1');
  });

  test('copyWith mantém tipo e autor', () {
    final b = _base(tipo: BookingTipo.reuniao).copyWith(notes: 'x');
    expect(b.tipo, BookingTipo.reuniao);
    expect(b.criadoPorUid, 'u1');
    expect(b.lembreteMinutos, 15);
  });
}
