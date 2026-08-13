import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/features/tarefas/domain/tarefa.dart';

/// **Uma reserva criada sem valor entra logo como tarefa, e fica lá até estar
/// completa.**
///
/// Regra do César, 13 de Agosto de 2026: «quando é criada a reserva sem o
/// valor, tem de entrar automaticamente como tarefa a fazer» — «e fica pendente
/// até estar completa».
///
/// Isto passou a ser indispensável no dia em que o relógio deixou de esperar
/// por ninguém: uma reserva sem preço fecha-se sozinha no fim do período e
/// ninguém volta a olhar para ela. Sem esta tarefa, era trabalho feito e nunca
/// facturado.
void main() {
  final hoje = DateTime(2026, 8, 13, 10);

  Booking reserva({
    String id = 'b1',
    int? valorCents,
    int comecaDaquiA = 3,
    BookingStatus estado = BookingStatus.request,
  }) => Booking(
    id: id,
    customerId: 'c1',
    customerNameSnapshot: 'Construções Silva',
    machineIds: const ['m1'],
    startsAt: hoje.add(Duration(days: comecaDaquiA)),
    endsAt: hoje.add(Duration(days: comecaDaquiA + 2)),
    status: estado,
    expectedValueCents: valorCents,
  );

  List<Tarefa> tarefasDe(List<Booking> reservas) => tarefasPendentes(
    OperationsState(onboarded: true, bookings: reservas),
    hoje,
  ).where((t) => t.id.startsWith('reserva-sem-valor-')).toList();

  test('sem valor, entra na lista', () {
    final tarefas = tarefasDe([reserva()]);

    expect(tarefas, hasLength(1));
    expect(tarefas.single.titulo, 'Pôr preço à reserva de Construções Silva');
    expect(tarefas.single.destino, DestinoTarefa.reservas);
    expect(tarefas.single.referencia, 'b1');
  });

  test('com valor, não entra', () {
    expect(tarefasDe([reserva(valorCents: 40000)]), isEmpty);
  });

  test('valor a zero conta como sem valor', () {
    expect(tarefasDe([reserva(valorCents: 0)]), hasLength(1));
  });

  test('depois de começar passa a urgente — o dinheiro já foi ganho', () {
    expect(
      tarefasDe([reserva(comecaDaquiA: -1)]).single.severidade,
      SeveridadeTarefa.urgente,
    );
    expect(
      tarefasDe([reserva(comecaDaquiA: 3)]).single.severidade,
      SeveridadeTarefa.aCompletar,
    );
  });

  test('fica pendente mesmo depois de concluída', () {
    // É o ponto todo: o relógio fecha-a sozinha, e a pendência não desaparece
    // com ela. Só o preço a tira da lista.
    final concluida = reserva(
      comecaDaquiA: -10,
      estado: BookingStatus.completed,
    );

    expect(tarefasDe([concluida]), hasLength(1));
    expect(tarefasDe([concluida]).single.severidade, SeveridadeTarefa.urgente);
  });

  test('uma reserva cancelada não pede preço nenhum', () {
    expect(
      tarefasDe([reserva(estado: BookingStatus.cancelled)]),
      isEmpty,
    );
  });
}
