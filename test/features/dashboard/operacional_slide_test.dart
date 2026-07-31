import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/slides/operacional_slide.dart';

import 'fixtura.dart';

/// O slide 2 é o primeiro ligado a dados a sério. O que estes testes protegem
/// não é o layout — é a promessa de que **nenhum número no ecrã é inventado**.
void main() {
  final agora = DateTime(2026, 7, 15, 10, 30);
  DateTime dia(int d) => DateTime(2026, 7, d);

  testWidgets('empresa sem reservas diz "Por apurar", não zeros', (
    tester,
  ) async {
    final container = containerCom(
      const OperationsState(onboarded: true, companyName: 'Alugueres Norte'),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    // Quatro células, todas honestas sobre a falta de dados.
    expect(find.text('Por apurar'), findsNWidgets(4));
    expect(find.text('Ainda não há reservas registadas'), findsNWidgets(4));
  });

  testWidgets('os números vêm do estado, não de constantes', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        bookings: [
          Booking(
            id: 'activa',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(10),
            endsAt: dia(20),
            status: BookingStatus.rented,
          ),
          Booking(
            id: 'entrega-hoje',
            customerId: 'c2',
            machineIds: const ['m2'],
            startsAt: dia(15),
            endsAt: dia(18),
            status: BookingStatus.confirmed,
          ),
        ],
      ),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    expect(find.text('Por apurar'), findsNothing);
    // 2 reservas activas, 1 entrega hoje ainda por sair. O valor e a unidade
    // vivem no mesmo `RichText`, daí o `findRichText`.
    expect(
      find.textContaining('2 em curso', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('1 por fazer'), findsOneWidget);
  });

  testWidgets('a recolha em atraso aparece com a antiguidade', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        bookings: [
          Booking(
            id: 'atrasada',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(1),
            endsAt: dia(12),
            status: BookingStatus.rented,
          ),
        ],
      ),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    expect(find.text('1 em atraso — a mais antiga há 3 dias'), findsOneWidget);
    expect(
      find.text('Alertas operacionais: 1 recolha em atraso'),
      findsOneWidget,
    );
  });

  testWidgets('sem nada a assinalar, a faixa de alertas não aparece', (
    tester,
  ) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        bookings: [
          Booking(
            id: 'tranquila',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(10),
            endsAt: dia(25),
            status: BookingStatus.rented,
          ),
        ],
      ),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    expect(find.textContaining('Alertas operacionais'), findsNothing);
  });

  testWidgets('o vocabulário é recolhas, nunca devoluções', (tester) async {
    // As máquinas são alugadas e têm de ser recuperadas: é trabalho da empresa,
    // não um acto do cliente.
    final container = containerCom(
      const OperationsState(onboarded: true, companyName: 'Alugueres Norte'),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    expect(find.textContaining('evolu'), findsNothing);
    expect(find.textContaining('RECOLHAS A FAZER'), findsOneWidget);
  });
}
