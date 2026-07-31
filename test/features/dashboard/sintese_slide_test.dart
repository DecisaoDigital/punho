import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/slides/sintese_slide.dart';

import 'fixtura.dart';

/// Slide 1 · Primeiro impulso.
///
/// O que estes testes protegem: **o dinheiro é do mês**, o dia é contexto, e
/// nenhuma célula inventa um número.
void main() {
  final agora = DateTime(2026, 7, 15, 10, 30);
  DateTime dia(int d) => DateTime(2026, 7, d);

  Receipt recebimento(String id, int d, int cents) => Receipt(
    id: id,
    date: dia(d),
    amountCents: cents,
    customerId: 'c1',
    method: PaymentMethod.transfer,
  );

  testWidgets('empresa sem movimentos não inventa números', (tester) async {
    final container = containerCom(
      const OperationsState(onboarded: true, companyName: 'Alugueres Norte'),
    );

    await montarLandscape(tester, container, SinteseSlide(agora: agora));

    // Entradas, utilização e encontro de contas em "Por apurar". A quarta
    // célula é a recomendação, que se cala em vez de inventar conselho.
    expect(find.text('Por apurar'), findsNWidgets(3));
    expect(find.text('Nada a assinalar'), findsOneWidget);
    expect(find.textContaining('1 240'), findsNothing);
    expect(find.textContaining('Silva & Filhos'), findsNothing);
  });

  testWidgets('o valor grande é o do mês, não o do dia', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        receipts: [
          recebimento('r1', 3, 100000),
          recebimento('r2', 9, 50000),
          recebimento('r3', 15, 24000),
        ],
      ),
    );

    await montarLandscape(tester, container, SinteseSlide(agora: agora));

    // 1000 + 500 + 240 = 1740 no mês. O dia 15 rendeu 240.
    expect(
      find.textContaining('1740 € este mês', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Hoje: 240 €'), findsOneWidget);
  });

  testWidgets('sem recebimentos hoje, a sub-linha não fala do dia', (
    tester,
  ) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        receipts: [recebimento('r1', 3, 100000)],
      ),
    );

    await montarLandscape(tester, container, SinteseSlide(agora: agora));

    expect(find.textContaining('Hoje:'), findsNothing);
  });

  testWidgets('encontro de contas mostra o saldo com sinal', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        receipts: [recebimento('r1', 10, 124000)],
        expenses: [
          Expense(
            id: 'e1',
            date: dia(11),
            amountCents: 86000,
            category: ExpenseCategory.supplies,
            status: ExpensePaymentStatus.paid,
          ),
        ],
      ),
    );

    await montarLandscape(tester, container, SinteseSlide(agora: agora));

    expect(
      find.textContaining('+ 380 € saldo', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Entradas 1240 · Saídas 860'), findsOneWidget);
  });

  testWidgets('a utilização diz quantas máquinas estão sem preço', (
    tester,
  ) async {
    final container = containerCom(
      const OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        machines: [
          Machine(
            id: 'm1',
            name: 'Mini escavadora',
            reference: 'ME-01',
            category: 'Escavação',
            status: MachineStatus.available,
            dailyRateCents: 18500,
          ),
          Machine(
            id: 'm2',
            name: 'Plataforma',
            reference: 'PE-02',
            category: 'Elevação',
            status: MachineStatus.available,
          ),
        ],
      ),
    );

    await montarLandscape(tester, container, SinteseSlide(agora: agora));

    expect(find.text('Falta o preço de 1 de 2 máquinas'), findsOneWidget);
  });
}
