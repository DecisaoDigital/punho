import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';

/// Decisão de 2026-08-02: o limite de colaboradores ativos passa a valer o da
/// subscrição no servidor, não o que o gestor declarou no onboarding.
///
/// `saveCollaborator` recebe esse limite como parâmetro
/// (`limiteColaboradoresAtivos`) — quem o resolve é
/// `limiteColaboradoresEfetivoProvider`, em
/// `lib/features/auth/subscricao_providers.dart` (testado à parte, porque
/// depende de Riverpod async). Aqui testa-se só a aplicação do limite dentro
/// do controlador, que é onde a regra de negócio de facto vive.
void main() {
  Collaborator colaborador(String id) =>
      Collaborator(id: id, name: 'n', status: CollaboratorStatus.active);

  test(
    'limite do servidor mais alto do que o local deixa passar do valor local',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      // O local (onboarding) é 3 por omissão — sem o parâmetro, o quarto
      // falharia. Com o servidor a autorizar 5, os cinco passam.
      for (var i = 0; i < 5; i++) {
        n.saveCollaborator(colaborador('$i'), limiteColaboradoresAtivos: 5);
      }
      final ativos = c
          .read(operationsProvider)
          .collaborators
          .where((x) => !x.archived && x.status == CollaboratorStatus.active);
      expect(ativos.length, 5);
    },
  );

  test(
    'limite do servidor mais baixo do que o local recusa antes do local '
    'deixar',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      n.saveCollaborator(colaborador('1'), limiteColaboradoresAtivos: 1);
      // O local permitiria até 3; o servidor só autoriza 1 — é este que manda.
      expect(
        () => n.saveCollaborator(
          colaborador('2'),
          limiteColaboradoresAtivos: 1,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'sem limite do servidor (parâmetro omitido) usa-se o valor local, para '
    'nunca bloquear por falha de rede',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      for (var i = 0; i < 3; i++) {
        n.saveCollaborator(colaborador('$i'));
      }
      expect(
        () => n.saveCollaborator(colaborador('4')),
        throwsStateError,
      );
    },
  );

  test(
    'já há mais ativos do que vagas do servidor: não rebenta, não apaga '
    'ninguém, só recusa novos',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(operationsProvider.notifier);
      // Três colaboradores criados quando o limite local (3) ainda permitia
      // — é o caso real: Lavandaria Mare Alta, limite 1 no servidor, três já
      // ativos.
      for (var i = 0; i < 3; i++) {
        n.saveCollaborator(colaborador('$i'));
      }

      expect(
        () => n.saveCollaborator(
          colaborador('novo'),
          limiteColaboradoresAtivos: 1,
        ),
        throwsStateError,
      );

      // Ninguém foi apagado: os três continuam ativos.
      final ativos = c
          .read(operationsProvider)
          .collaborators
          .where((x) => !x.archived && x.status == CollaboratorStatus.active);
      expect(ativos.length, 3);
    },
  );
}
