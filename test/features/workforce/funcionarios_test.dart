import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/domain/models/workforce.dart' as pw;
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

import '../dashboard/fixtura.dart';

/// "Vejo o custo do colaborador e não vejo o que ele traz para dentro."
void main() {
  Booking reserva({
    required String id,
    required String? responsavel,
    required BookingStatus estado,
    required DateTime inicio,
    int? valorCents,
  }) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: inicio,
    endsAt: inicio.add(const Duration(days: 1)),
    status: estado,
    expectedValueCents: valorCents,
    collaboratorResponsibleId: responsavel,
  );

  OperationsState comReservas(List<Booking> bookings) =>
      estadoComMovimento().copyWith(bookings: bookings);

  group('vendasDoMesDoColaborador', () {
    test('conta confirmadas, alugadas e concluídas do mês', () {
      final estado = comReservas([
        reserva(
          id: 'b1',
          responsavel: 'co1',
          estado: BookingStatus.confirmed,
          inicio: DateTime(2026, 7, 3),
          valorCents: 50000,
        ),
        reserva(
          id: 'b2',
          responsavel: 'co1',
          estado: BookingStatus.rented,
          inicio: DateTime(2026, 7, 20),
          valorCents: 30000,
        ),
        reserva(
          id: 'b3',
          responsavel: 'co1',
          estado: BookingStatus.completed,
          inicio: DateTime(2026, 7, 28),
          valorCents: 20000,
        ),
      ]);

      final vendas = vendasDoMesDoColaborador(estado, 'co1', agoraFixa);
      expect(vendas.contagem, 3);
      expect(vendas.valorCents, 100000);
    });

    test('propostas, pedidos e canceladas não são vendas', () {
      // Uma proposta enviada não é uma venda: contá-la dava a quem só envia
      // propostas os mesmos números de quem fecha negócio.
      final estado = comReservas([
        for (final estadoReserva in [
          BookingStatus.request,
          BookingStatus.proposalSent,
          BookingStatus.cancelled,
        ])
          reserva(
            id: 'b-${estadoReserva.name}',
            responsavel: 'co1',
            estado: estadoReserva,
            inicio: DateTime(2026, 7, 10),
            valorCents: 90000,
          ),
      ]);

      final vendas = vendasDoMesDoColaborador(estado, 'co1', agoraFixa);
      expect(vendas.contagem, 0);
      expect(vendas.valorCents, isNull);
    });

    test('outro mês e outro colaborador ficam de fora', () {
      final estado = comReservas([
        reserva(
          id: 'b-junho',
          responsavel: 'co1',
          estado: BookingStatus.completed,
          inicio: DateTime(2026, 6, 30),
          valorCents: 70000,
        ),
        reserva(
          id: 'b-outro',
          responsavel: 'co2',
          estado: BookingStatus.completed,
          inicio: DateTime(2026, 7, 10),
          valorCents: 70000,
        ),
        reserva(
          id: 'b-sem-responsavel',
          responsavel: null,
          estado: BookingStatus.completed,
          inicio: DateTime(2026, 7, 10),
          valorCents: 70000,
        ),
      ]);

      expect(vendasDoMesDoColaborador(estado, 'co1', agoraFixa).contagem, 0);
    });

    test('sem valor esperado o valor é por apurar, não zero', () {
      // Zero significaria "vendeu e não rendeu nada". O que se passa é que não
      // se sabe.
      final estado = comReservas([
        reserva(
          id: 'b1',
          responsavel: 'co1',
          estado: BookingStatus.confirmed,
          inicio: DateTime(2026, 7, 3),
        ),
      ]);

      final vendas = vendasDoMesDoColaborador(estado, 'co1', agoraFixa);
      expect(vendas.contagem, 1);
      expect(vendas.valorCents, isNull);
    });

    test('umas com valor e outras sem soma as que têm', () {
      final estado = comReservas([
        reserva(
          id: 'b1',
          responsavel: 'co1',
          estado: BookingStatus.confirmed,
          inicio: DateTime(2026, 7, 3),
          valorCents: 40000,
        ),
        reserva(
          id: 'b2',
          responsavel: 'co1',
          estado: BookingStatus.confirmed,
          inicio: DateTime(2026, 7, 4),
        ),
      ]);

      final vendas = vendasDoMesDoColaborador(estado, 'co1', agoraFixa);
      expect(vendas.contagem, 2);
      expect(vendas.valorCents, 40000);
    });
  });

  group('Collaborator.copyWith', () {
    const base = Collaborator(
      id: 'co1',
      name: 'Manuel Silva',
      status: CollaboratorStatus.active,
      phone: '912345678',
      role: 'Manobrador',
      notes: 'tem carta de máquinas pesadas',
      costCents: 120000,
    );

    test('não mexer é diferente de apagar', () {
      // O defeito P2-5: com `phone ?? this.phone` era impossível limpar um
      // telemóvel escrito errado.
      expect(base.copyWith(name: 'Manuel S.').phone, '912345678');
      expect(base.copyWith(phone: null).phone, isNull);
      expect(base.copyWith(costCents: null).costCents, isNull);
    });

    test('mantém o id e o que o diálogo não mostra', () {
      final editado = base.copyWith(name: 'Manuel S.');
      expect(editado.id, 'co1');
      expect(editado.notes, 'tem carta de máquinas pesadas');
    });
  });

  group('Página de Funcionários', () {
    const manuel = Collaborator(
      id: 'co1',
      name: 'Manuel Silva',
      status: CollaboratorStatus.active,
      costCents: 120000,
    );

    /// Estado fixo, para os testes que só lêem o que está no ecrã.
    ProviderContainer soParaLer({List<Booking> bookings = const []}) =>
        containerCom(
          estadoComMovimento().copyWith(
            bookings: bookings,
            collaborators: const [manuel],
          ),
        );

    /// Container com repositório a sério, para os testes que gravam.
    ///
    /// O [ControllerFixo] devolve um estado fixo em `build()`, mas qualquer
    /// mutação faz o controller reler o repositório — e aí o estado fixo
    /// desaparece. Editar e eliminar têm de correr contra um repositório de
    /// verdade, senão o teste mede o fixture e não o código.
    ProviderContainer paraGravar({int quantos = 1}) {
      final container = ProviderContainer(
        overrides: [
          operationRepositoryProvider.overrideWithValue(_RepoVazio()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(operationsProvider.notifier);
      notifier.saveCollaborator(manuel);
      for (var i = 2; i <= quantos; i++) {
        notifier.saveCollaborator(
          Collaborator(
            id: 'co$i',
            name: 'Colega $i',
            status: CollaboratorStatus.active,
            costCents: 100000,
          ),
        );
      }
      return container;
    }

    Future<void> abrir(WidgetTester tester, ProviderContainer container) =>
        montarLandscape(
          tester,
          container,
          CollaboratorsPage(agora: agoraFixa),
          tamanho: const Size(1280, 900),
        );

    testWidgets('o subtítulo diz as vendas do mês', (tester) async {
      await abrir(
        tester,
        soParaLer(
          bookings: [
            reserva(
              id: 'b1',
              responsavel: 'co1',
              estado: BookingStatus.completed,
              inicio: DateTime(2026, 7, 3),
              valorCents: 50000,
            ),
            reserva(
              id: 'b2',
              responsavel: 'co1',
              estado: BookingStatus.confirmed,
              inicio: DateTime(2026, 7, 9),
              valorCents: 25000,
            ),
          ],
        ),
      );

      expect(
        find.textContaining('2 reservas este mês · 750.00 €'),
        findsOneWidget,
      );
    });

    testWidgets('sem reservas diz sem reservas, não 0 €', (tester) async {
      await abrir(tester, soParaLer());

      expect(find.textContaining('sem reservas este mês'), findsOneWidget);
      expect(find.textContaining('0.00 €\n'), findsNothing);
    });

    testWidgets('o estado está em português e o custo/hora em euros', (
      tester,
    ) async {
      await abrir(
        tester,
        containerCom(
          estadoComMovimento().copyWith(
            collaborators: [
              manuel.copyWith(
                schedule: const {
                  1: WorkDay(works: true, start: pw.TimeOfDay(9, 0), end: pw.TimeOfDay(18, 0)),
                  2: WorkDay(works: true, start: pw.TimeOfDay(9, 0), end: pw.TimeOfDay(18, 0)),
                },
              ),
            ],
          ),
        ),
      );

      // "active" era o nome do valor do enum a chegar ao ecrã.
      expect(find.textContaining('active'), findsNothing);
      expect(find.textContaining('Ativo'), findsOneWidget);
      // 1200 €/mês por 18h/semana: ~15,38 €/hora, e não "1538.46".
      expect(find.textContaining('custo/hora: 15.38 €'), findsOneWidget);
    });

    testWidgets('tocar na linha abre o diálogo de edição com os dados', (
      tester,
    ) async {
      await abrir(tester, soParaLer());

      await tester.tap(find.text('Manuel Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Editar colaborador'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Nome'))
            .controller!
            .text,
        'Manuel Silva',
      );
    });

    testWidgets('editar mantém o mesmo colaborador em vez de criar outro', (
      tester,
    ) async {
      final container = paraGravar();
      await abrir(tester, container);

      await tester.tap(find.byTooltip('Editar colaborador'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Manuel Silva Jr.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final colaboradores = container
          .read(operationsProvider)
          .collaborators
          .where((c) => !c.archived)
          .toList();
      expect(colaboradores, hasLength(1));
      expect(colaboradores.single.id, 'co1');
      expect(colaboradores.single.name, 'Manuel Silva Jr.');
    });

    testWidgets('eliminar pede confirmação e deixa anular', (tester) async {
      final container = paraGravar();
      await abrir(tester, container);

      await tester.tap(find.byTooltip('Eliminar colaborador'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar Manuel Silva?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      // Sai da lista, mas não do repositório.
      expect(find.text('Manuel Silva'), findsNothing);
      expect(
        container.read(operationsProvider).collaborators.single.archived,
        isTrue,
      );

      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      expect(find.text('Manuel Silva'), findsOneWidget);
      expect(
        container.read(operationsProvider).collaborators.single.archived,
        isFalse,
      );
    });

    testWidgets('cancelar a confirmação não elimina', (tester) async {
      final container = paraGravar();
      await abrir(tester, container);

      await tester.tap(find.byTooltip('Eliminar colaborador'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Manuel Silva'), findsOneWidget);
      expect(
        container.read(operationsProvider).collaborators.single.archived,
        isFalse,
      );
    });

    testWidgets('com as vagas cheias ainda se pode editar', (tester) async {
      // Três colaboradores em três vagas contratadas. O saveCollaborator conta
      // os *outros* activos, por isso editar um dos três passa. Se contasse
      // todos, uma empresa com as vagas cheias ficava sem poder corrigir um
      // nome mal escrito.
      final container = paraGravar(quantos: 3);
      await abrir(tester, container);
      expect(container.read(operationsProvider).activeCollaborators, 3);
      expect(container.read(operationsProvider).activeCollaboratorLimit, 3);

      await tester.tap(find.byTooltip('Editar colaborador').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Manuel Corrigido',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(EcraDeFormulario), findsNothing);
      expect(
        container
            .read(operationsProvider)
            .collaborators
            .firstWhere((c) => c.id == 'co1')
            .name,
        'Manuel Corrigido',
      );
    });
  });
}

/// Repositório sem os dados de demonstração.
class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
