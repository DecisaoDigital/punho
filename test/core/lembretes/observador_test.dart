import 'package:fist/core/lembretes/agendador.dart';
import 'package:fist/core/lembretes/lembretes_providers.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime(2026, 10, 20, 9);

  Future<(ProviderContainer, AgendadorFalso, StateProvider<String?>)> montar(
    WidgetTester t,
  ) async {
    final falso = AgendadorFalso();
    final uid = StateProvider<String?>((_) => 'u1');
    final c = ProviderContainer(
      overrides: [
        relogioProvider.overrideWithValue(() => agora),
        agendadorProvider.overrideWithValue(falso),
        uidAtualProvider.overrideWith((ref) => ref.watch(uid)),
      ],
    );
    addTearDown(c.dispose);
    c.read(operationsProvider.notifier).addCustomer(
      Customer(
        id: 'c1',
        name: 'Ana',
        phone: '910000000',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: ObservadorDeLembretes(child: SizedBox()),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (c, falso, uid);
  }

  testWidgets('marcar agenda, remarcar reagenda, cancelar limpa', (t) async {
    final (c, falso, _) = await montar(t);
    final n = c.read(operationsProvider.notifier);
    expect(falso.agendados, isEmpty);

    final r = n.agendarReuniao(
      customerId: 'c1',
      inicio: DateTime(2026, 10, 21, 10),
      lembreteMinutos: 15,
      criadoPorUid: 'u1',
    );
    await t.pumpAndSettle();
    expect(falso.agendados.single.quando, DateTime(2026, 10, 21, 9, 45));

    n.remarcarReuniao(r.id, DateTime(2026, 10, 22, 14));
    await t.pumpAndSettle();
    expect(falso.agendados.single.quando, DateTime(2026, 10, 22, 13, 45));

    n.cancelarReuniao(r.id);
    await t.pumpAndSettle();
    expect(falso.agendados, isEmpty);
  });

  testWidgets('sair da conta cancela tudo; outra conta não herda o alarme',
      (t) async {
    final (c, falso, uid) = await montar(t);
    c.read(operationsProvider.notifier).agendarReuniao(
      customerId: 'c1',
      inicio: DateTime(2026, 10, 21, 10),
      lembreteMinutos: 15,
      criadoPorUid: 'u1',
    );
    await t.pumpAndSettle();
    expect(falso.agendados, hasLength(1));

    c.read(uid.notifier).state = null;
    await t.pumpAndSettle();
    expect(falso.agendados, isEmpty);
    expect(falso.cancelamentos, greaterThan(0));

    c.read(uid.notifier).state = 'u2';
    await t.pumpAndSettle();
    expect(falso.agendados, isEmpty);

    c.read(uid.notifier).state = 'u1';
    await t.pumpAndSettle();
    expect(falso.agendados, hasLength(1));
  });
}
