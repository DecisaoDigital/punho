import 'package:fist/core/lembretes/reconciliar.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:flutter_test/flutter_test.dart';

Booking reuniao(
  String id, {
  DateTime? inicio,
  int? lembrete = 15,
  String? uid = 'u1',
  BookingStatus status = BookingStatus.confirmed,
  BookingTipo tipo = BookingTipo.reuniao,
  String cliente = 'Ana',
}) {
  final i = inicio ?? DateTime(2026, 10, 21, 10);
  return Booking(
    id: id,
    customerId: 'c1',
    machineIds: const [],
    startsAt: i,
    endsAt: i.add(const Duration(hours: 1)),
    status: status,
    tipo: tipo,
    lembreteMinutos: lembrete,
    criadoPorUid: uid,
    customerNameSnapshot: cliente,
  );
}

void main() {
  final agora = DateTime(2026, 10, 20, 9);

  test('agenda para início menos antecedência, só do autor', () {
    final plano = reconciliar([reuniao('a')], 'u1', agora);
    expect(plano, hasLength(1));
    expect(plano.single.reuniaoId, 'a');
    expect(plano.single.quando, DateTime(2026, 10, 21, 9, 45));
    expect(plano.single.texto, contains('Ana'));
    expect(plano.single.texto, contains('10:00'));
  });

  test('não agenda a de outro utilizador, sem aviso ou sem autor', () {
    expect(reconciliar([reuniao('a', uid: 'u2')], 'u1', agora), isEmpty);
    expect(reconciliar([reuniao('a', lembrete: null)], 'u1', agora), isEmpty);
    expect(reconciliar([reuniao('a', uid: null)], 'u1', agora), isEmpty);
    expect(reconciliar([reuniao('a')], null, agora), isEmpty);
  });

  test('não agenda canceladas, passadas nem reservas de máquina', () {
    expect(
      reconciliar([reuniao('a', status: BookingStatus.cancelled)], 'u1', agora),
      isEmpty,
    );
    expect(
      reconciliar(
        [reuniao('a', inicio: DateTime(2026, 10, 20, 9, 10))],
        'u1',
        agora,
      ),
      isEmpty,
    );
    expect(
      reconciliar([reuniao('a', tipo: BookingTipo.maquina)], 'u1', agora),
      isEmpty,
    );
  });

  test('janela de 30 dias e máximo de 50, as mais próximas primeiro', () {
    expect(
      reconciliar(
        [reuniao('longe', inicio: DateTime(2026, 12, 25, 10))],
        'u1',
        agora,
      ),
      isEmpty,
    );
    final muitas = [
      for (var i = 0; i < 60; i++)
        reuniao(
          'r$i',
          inicio: DateTime(2026, 10, 21).add(Duration(hours: i + 1)),
        ),
    ];
    final plano = reconciliar(muitas, 'u1', agora);
    expect(plano, hasLength(50));
    expect(plano.first.reuniaoId, 'r0');
  });

  test('id numérico estável por reunião', () {
    final a = reconciliar([reuniao('a')], 'u1', agora).single.idNotificacao;
    final b = reconciliar([reuniao('a')], 'u1', agora).single.idNotificacao;
    expect(a, b);
    expect(a, greaterThan(0));
    expect(a, lessThan(2147483647));
  });

  test('o texto não leva notas nem NIF', () {
    final r = reuniao('a');
    final texto = reconciliar([r], 'u1', agora).single.texto;
    expect(texto, 'Reunião às 10:00 com Ana');
  });
}
