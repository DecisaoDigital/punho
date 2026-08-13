import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// **Uma célula do calendário com duas reservas tem de dizer que tem duas.**
///
/// A 13 de Agosto de 2026, o César: «quando estou em reservas e carrego na
/// célula que tem reservas feitas, a informação fornecida não é suficiente.
/// Atualizar estado de reserva, nem mostra que a célula tem afinal duas
/// reservas feitas, com máquinas diferentes e clientes diferentes».
///
/// Tinha razão duas vezes. A caixa dizia «Atualizar estado da reserva» e mais
/// nada — nem de que máquina, nem de que cliente, nem de que dia. E a segunda
/// reserva do meio-dia era **invisível**: a célula tem 44 dp de altura e a
/// etiqueta de baixo fica cortada, portanto nem se sabia que existia.
///
/// Estes testes fixam as três coisas: a caixa identifica a reserva, anuncia as
/// outras da mesma célula, e deixa saltar para elas.
void main() {
  /// Duas reservas no mesmo meio-dia de hoje, de máquinas e clientes
  /// diferentes — exactamente o caso que ele descreveu.
  ///
  /// A data é de hoje porque o calendário abre na semana corrente: uma data
  /// fixa cairia fora da vista e não haveria célula nenhuma para carregar.
  OperationsState comDuasNoMesmoMeioDia() {
    final hoje = DateTime.now();
    final manha = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDaManha = manha.add(const Duration(hours: 11));
    return estadoComMovimento().copyWith(
      bookings: [
        Booking(
          id: 'b-manha-1',
          customerId: 'c1',
          customerNameSnapshot: 'Construções Silva',
          machineIds: const ['m1'],
          startsAt: manha,
          endsAt: fimDaManha,
          status: BookingStatus.confirmed,
          expectedValueCents: 50000,
        ),
        Booking(
          id: 'b-manha-2',
          customerId: 'c2',
          customerNameSnapshot: 'João Pereira',
          machineIds: const ['m2'],
          startsAt: manha,
          endsAt: fimDaManha,
          status: BookingStatus.request,
        ),
      ],
    );
  }

  Future<void> abrirCalendario(WidgetTester tester) => montarLandscape(
    tester,
    containerCom(comDuasNoMesmoMeioDia()),
    const BookingsPage(),
    // As medidas do Redmi deitado, que é onde isto se viu.
    tamanho: const Size(2177, 1080),
  );

  /// Carrega na etiqueta da primeira reserva — «ME-01 · Construções Silva».
  Future<void> carregarNaPrimeira(WidgetTester tester) async {
    await tester.tap(find.textContaining('Construções Silva').first);
    await tester.pumpAndSettle();
  }

  testWidgets('a caixa diz de que máquina e de que cliente é', (tester) async {
    await abrirCalendario(tester);
    await carregarNaPrimeira(tester);

    expect(
      find.text('ME-01 · Construções Silva'),
      findsOneWidget,
      reason: 'sem isto muda-se o estado de uma reserva sem saber de quem é',
    );
  });

  testWidgets('e de que meio-dia — a caixa tapa o calendário', (tester) async {
    await abrirCalendario(tester);
    await carregarNaPrimeira(tester);

    expect(find.textContaining(RegExp('Manhã|Tarde')), findsWidgets);
  });

  testWidgets('anuncia a outra reserva do mesmo meio-dia', (tester) async {
    await abrirCalendario(tester);
    await carregarNaPrimeira(tester);

    expect(find.text('Este meio-dia tem mais uma reserva:'), findsOneWidget);
    expect(find.text('PE-02 · João Pereira'), findsOneWidget);
  });

  testWidgets('e salta para ela sem se ter de fechar nada', (tester) async {
    await abrirCalendario(tester);
    await carregarNaPrimeira(tester);

    await tester.tap(find.text('PE-02 · João Pereira'));
    await tester.pumpAndSettle();

    // A caixa agora é da segunda reserva, e é a primeira que aparece como
    // vizinha.
    expect(find.text('PE-02 · João Pereira'), findsOneWidget);
    expect(find.text('ME-01 · Construções Silva'), findsOneWidget);
  });

  testWidgets('Cancelada continua alcançável — é o desfazer', (tester) async {
    await abrirCalendario(tester);
    await carregarNaPrimeira(tester);

    // Seis estados mais o valor mais as vizinhas não cabem em 393 dp de ecrã
    // deitado. Se a caixa não rolar, «Cancelada» — o único caminho para
    // desfazer uma marcação enganada — fica fora dela e não há como lá chegar.
    final rolo = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    expect(rolo, findsOneWidget, reason: 'sem rolo, o que não cabe perde-se');

    expect(find.text('Cancelada'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancelada'), 120, scrollable: rolo);
    await tester.tap(find.text('Cancelada'));
    await tester.pumpAndSettle();

    // Carregar em «Cancelada» fecha a caixa: a marcação foi desfeita.
    expect(find.byType(AlertDialog), findsNothing);
  });
}
