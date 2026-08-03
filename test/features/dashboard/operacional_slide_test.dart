import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/slides/operacional_slide.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';

import 'fixtura.dart';

/// O slide 2 é o primeiro ligado a dados a sério. O que estes testes protegem
/// não é o layout — é a promessa de que **nenhum número no ecrã é inventado**.
void main() {
  final agora = DateTime(2026, 7, 15, 10, 30);
  DateTime dia(int d) => DateTime(2026, 7, d);

  testWidgets('empresa sem reservas diz o que falta fazer, não zeros', (
    tester,
  ) async {
    final container = containerCom(
      const OperationsState(onboarded: true, companyName: 'Alugueres Norte'),
    );

    await montarLandscape(tester, container, OperacionalSlide(agora: agora));

    // Quatro células, todas honestas sobre a falta de dados — e o que ocupa o
    // lugar do número é a acção que o destranca, não o rótulo "Por apurar"
    // repetido quatro vezes, que se lia como app avariada.
    expect(find.text('Marca a primeira reserva'), findsOneWidget);
    expect(find.text('Nada para entregar'), findsOneWidget);
    expect(find.text('Nada para recolher'), findsOneWidget);
    expect(find.text('Nada por cobrar'), findsOneWidget);
    expect(find.text('Por apurar'), findsNothing);

    // E nenhuma pintada de laranja: falta de dados não é aviso. Um painel de
    // empresa nova todo cor de alarme diz "está tudo mal" a quem só ainda não
    // começou.
    final celulas = tester.widgetList<CelulaSemaforo>(
      find.byType(CelulaSemaforo),
    );
    expect(celulas.length, 4);
    expect(
      celulas.every((c) => c.nivel == NivelSemaforo.aguarda),
      isTrue,
      reason: 'sem dados é espera, não urgência',
    );
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
