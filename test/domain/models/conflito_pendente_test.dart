import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/conflito_pendente.dart';

/// O `id` determinístico é a peça que faz o resto do desenho funcionar sem
/// coordenação entre dois aparelhos — ver o comentário na classe.
void main() {
  test('o id não depende da ordem em que as duas reservas chegam', () {
    final agora = DateTime(2026, 8, 3, 10);
    final aVindoDeA = ConflitoPendente.reservaMaquina(
      reservaId1: 'reserva-b',
      reservaId2: 'reserva-a',
      machineIdsPartilhados: const ['m1'],
      envolvidos: const ['colab-1', 'colab-2'],
      criadoEm: agora,
    );
    final aVindoDeB = ConflitoPendente.reservaMaquina(
      reservaId1: 'reserva-a',
      reservaId2: 'reserva-b',
      machineIdsPartilhados: const ['m1'],
      envolvidos: const ['colab-2', 'colab-1'],
      criadoEm: agora,
    );

    expect(aVindoDeA.id, aVindoDeB.id);
    expect(aVindoDeA.entidadeAId, 'reserva-a');
    expect(aVindoDeA.entidadeBId, 'reserva-b');
  });

  test('envolvidos fica deduplicado', () {
    final conflito = ConflitoPendente.reservaMaquina(
      reservaId1: 'reserva-a',
      reservaId2: 'reserva-b',
      machineIdsPartilhados: const ['m1'],
      envolvidos: const ['colab-1', 'colab-1'],
      criadoEm: DateTime(2026, 8, 3),
    );

    expect(conflito.envolvidos, ['colab-1']);
  });

  test('resolvidoComo marca estado e decisão sem tocar no resto', () {
    final pendente = ConflitoPendente.reservaMaquina(
      reservaId1: 'reserva-a',
      reservaId2: 'reserva-b',
      machineIdsPartilhados: const ['m1'],
      envolvidos: const ['colab-1', 'colab-2'],
      criadoEm: DateTime(2026, 8, 3),
    );

    final resolvido = pendente.resolvidoComo(
      ficaComEntidadeId: 'reserva-a',
      resolvidoPor: 'user-gestor',
      resolvidoEm: DateTime(2026, 8, 3, 12),
    );

    expect(resolvido.id, pendente.id);
    expect(resolvido.estado, EstadoConflito.resolvido);
    expect(resolvido.ficaComEntidadeId, 'reserva-a');
    expect(resolvido.resolvidoPor, 'user-gestor');
  });

  test('paraFila/daFila é um round-trip fiel', () {
    final original =
        ConflitoPendente.reservaMaquina(
          reservaId1: 'reserva-a',
          reservaId2: 'reserva-b',
          machineIdsPartilhados: const ['m1', 'm2'],
          envolvidos: const ['colab-1', 'colab-2'],
          criadoEm: DateTime(2026, 8, 3, 9, 30),
        ).resolvidoComo(
          ficaComEntidadeId: 'reserva-a',
          resolvidoPor: 'user-gestor',
          resolvidoEm: DateTime(2026, 8, 3, 12),
        );

    final devolta = ConflitoPendente.daFila(original.paraFila());

    expect(devolta.id, original.id);
    expect(devolta.tipo, original.tipo);
    expect(devolta.entidadeAId, original.entidadeAId);
    expect(devolta.entidadeBId, original.entidadeBId);
    expect(devolta.machineIdsPartilhados, original.machineIdsPartilhados);
    expect(devolta.envolvidos, original.envolvidos);
    expect(devolta.estado, EstadoConflito.resolvido);
    expect(devolta.ficaComEntidadeId, 'reserva-a');
    expect(devolta.resolvidoPor, 'user-gestor');
  });
}
