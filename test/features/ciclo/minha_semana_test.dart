import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/ciclo/presentation/minha_semana_page.dart';

import '../dashboard/fixtura.dart';

/// **A minha semana** vista do lado de quem a lê — e de quem lhe toca.
///
/// O motor já é testado em `proximo_passo_test.dart`. O que falta garantir é a
/// promessa que só o ecrã pode quebrar: **um botão por linha**, com um verbo, e
/// que o botão faz mesmo o que diz. Um ecrã que mostra o passo certo e não o
/// executa é pior do que não o mostrar — ensina o gestor a desconfiar dele.
void main() {
  final hoje = DateTime(2026, 8, 4, 9, 40);

  Booking trabalho({
    String id = 'b1',
    required BookingStatus estado,
    int comecaDaquiA = 1,
    int acabaDaquiA = 3,
    int? valorCents,
  }) => Booking(
    id: id,
    customerId: 'c1',
    customerNameSnapshot: 'Construções Silva',
    machineIds: const ['m1'],
    startsAt: hoje.add(Duration(days: comecaDaquiA)),
    endsAt: hoje.add(Duration(days: acabaDaquiA)),
    status: estado,
    expectedValueCents: valorCents,
  );

  const maquina = Machine(
    id: 'm1',
    name: 'Mini escavadora',
    reference: 'ME-01',
    category: 'Escavação',
    status: MachineStatus.available,
  );

  OperationsState estadoCom(List<Booking> trabalhos) => OperationsState(
    onboarded: true,
    companyName: 'Alugueres Norte',
    machines: const [maquina],
    customers: const [
      Customer(id: 'c1', name: 'Construções Silva', phone: '912 000 000'),
    ],
    bookings: trabalhos,
  );

  testWidgets('cada trabalho aparece com o seu verbo e a sua razão', (
    tester,
  ) async {
    await montarLandscape(
      tester,
      containerCom(
        estadoCom([
          // Com preço: sem ele o passo deixou de ser "Enviar orçamento" e
          // passou a "Pôr preço" — ver `proximo_passo_test.dart`.
          trabalho(
            id: 'pedido',
            estado: BookingStatus.request,
            valorCents: 40000,
          ),
          trabalho(
            id: 'entrega-atrasada',
            estado: BookingStatus.confirmed,
            comecaDaquiA: -1,
            acabaDaquiA: 2,
          ),
        ]),
      ),
      MinhaSemanaPage(agora: hoje),
    );

    expect(find.text('Enviar orçamento'), findsOneWidget);
    expect(find.text('Entregar'), findsOneWidget);
    expect(find.text('2 por fazer'), findsOneWidget);
    expect(find.text('1 atrasado'), findsOneWidget);
    // A máquina identifica a linha tão bem como o cliente: o mesmo cliente
    // costuma ter mais do que um trabalho a decorrer.
    expect(find.textContaining('ME-01'), findsNWidgets(2));
  });

  testWidgets('sem nada por fazer, diz que não há nada por fazer', (
    tester,
  ) async {
    await montarLandscape(
      tester,
      containerCom(estadoCom([trabalho(estado: BookingStatus.cancelled)])),
      MinhaSemanaPage(agora: hoje),
    );

    expect(find.text('Nada por fazer.'), findsOneWidget);
    // O "0 atrasados" não existe de propósito: um contador que está sempre lá a
    // dizer zero ensina o olho a saltar aquele sítio do ecrã.
    expect(find.textContaining('atrasado'), findsNothing);
  });

  testWidgets('o "0 por fazer" nunca chega a existir', (tester) async {
    await montarLandscape(
      tester,
      containerCom(estadoCom(const [])),
      MinhaSemanaPage(agora: hoje),
    );

    // Um "0 por fazer" é um contador a dar a notícia errada: parece uma
    // contagem por resolver quando o que se quer dizer é que está tudo feito.
    expect(find.text('0 por fazer'), findsNothing);
    expect(find.text('Nada por fazer.'), findsOneWidget);
  });

  testWidgets('tocar no botão avança mesmo o trabalho', (tester) async {
    // Aqui o controller tem de ser o verdadeiro: com o estado fixo dos outros
    // testes o botão parecia funcionar e não mudava nada — que é exactamente o
    // defeito que este teste existe para apanhar.
    final repo = _RepoCom([
      trabalho(id: 'b1', estado: BookingStatus.confirmed, comecaDaquiA: 0),
    ]);
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await montarLandscape(tester, container, MinhaSemanaPage(agora: hoje));

    expect(find.text('Entregar'), findsOneWidget);
    await tester.tap(find.text('Entregar'));
    await tester.pumpAndSettle();

    expect(
      container.read(operationsProvider).bookings.single.status,
      BookingStatus.rented,
    );
    // E o ecrã acompanha: o passo seguinte de um trabalho entregue é fechá-lo.
    expect(find.text('Fechar trabalho'), findsOneWidget);
  });

  testWidgets(
    'o trabalho fechado sem valor pergunta quanto valeu, e guarda-o',
    (tester) async {
      final repo = _RepoCom([
        trabalho(
          id: 'b1',
          estado: BookingStatus.completed,
          comecaDaquiA: -4,
          acabaDaquiA: -2,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [operationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await montarLandscape(tester, container, MinhaSemanaPage(agora: hoje));

      await tester.tap(find.text('Dizer quanto valeu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1.500,00');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        container.read(operationsProvider).bookings.single.expectedValueCents,
        150000,
      );
      // Com valor declarado e nada recebido, o passo passa a ser o dinheiro.
      expect(find.text('Registar recebimento'), findsOneWidget);
    },
  );
}

/// Repositório com os trabalhos que o teste quer, e mais nada.
class _RepoCom extends LocalDemoOperationRepository {
  _RepoCom(List<Booking> trabalhos) {
    resetAll();
    for (final item in trabalhos) {
      saveBooking(item);
    }
  }
}
