import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';

/// Decisão de 2026-08-02: as vagas de colaboradores da subscrição (servidor
/// ou, na falta dele, o valor local do onboarding) deixaram de bloquear a
/// gravação. `saveCollaborator` grava sempre; quem quer avisar de que a
/// empresa ficou acima do autorizado compara `activeCollaborators` com
/// `limiteColaboradoresEfetivoProvider` depois de gravar — é o que
/// `workforce_pages.dart` faz. Este ficheiro testava a recusa; agora testa
/// que ela desapareceu, com os mesmos casos.
void main() {
  Collaborator colaborador(String id) =>
      Collaborator(id: id, name: 'n', status: CollaboratorStatus.active);

  test('grava acima do limite local sem lançar nem recusar', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    // O local (onboarding) é 3 por omissão — o quarto já não falha.
    for (var i = 0; i < 4; i++) {
      n.saveCollaborator(colaborador('$i'));
    }
    final ativos = c
        .read(operationsProvider)
        .collaborators
        .where((x) => !x.archived && x.status == CollaboratorStatus.active);
    expect(ativos.length, 4);
  });

  test('já há mais ativos do que vagas autorizadas: não rebenta, não apaga '
      'ninguém, e o novo fica gravado', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(operationsProvider.notifier);
    // Três colaboradores criados quando o limite local (3) ainda permitia
    // — é o caso real: Lavandaria Mare Alta, limite 1 no servidor, três já
    // ativos.
    for (var i = 0; i < 3; i++) {
      n.saveCollaborator(colaborador('$i'));
    }

    n.saveCollaborator(colaborador('novo'));

    final ativos = c
        .read(operationsProvider)
        .collaborators
        .where((x) => !x.archived && x.status == CollaboratorStatus.active);
    // Ninguém foi apagado, e o quarto entrou: ficar acima do autorizado só
    // impede o acesso, aprovado à parte no Control — nunca a gravação.
    expect(ativos.length, 4);
  });
}
