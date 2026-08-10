import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';

import 'fixtura.dart';

/// As quatro células que antes viviam no slide da Síntese.
///
/// O que estes testes protegem: **o dinheiro é do mês**, o dia é contexto, e
/// nenhuma célula inventa um número.
const idsDaSintese = [
  'entradas-mes',
  'utilizacao-rentabilidade',
  'encontro-contas',
  'recomendacao-dia',
];

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

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    // Entradas, utilização e encontro de contas dizem o que falta fazer. A
    // quarta célula é a recomendação, que se cala em vez de inventar conselho.
    expect(find.text('Regista um recebimento'), findsOneWidget);
    expect(find.text('Identifica as máquinas'), findsOneWidget);
    expect(find.text('Sem movimentos este mês'), findsOneWidget);
    expect(find.text('Por apurar'), findsNothing);
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

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    // 1000 + 500 + 240 = 1740 no mês. O dia 15 rendeu 240.
    expect(
      find.textContaining('1740 € este mês', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Hoje: 240 €'), findsOneWidget);
  });

  testWidgets('havendo histórico, compara com o mês homólogo', (tester) async {
    // Agosto contra Julho mistura variação de negócio com estação do ano. O
    // mesmo mês do ano passado é a única comparação que isola o que mudou na
    // empresa — e o texto tem de dizer contra o quê.
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        receipts: [
          recebimento('agora', 10, 120000),
          // Junho de 2026: o mês anterior.
          Receipt(
            id: 'anterior',
            date: DateTime(2026, 6, 10),
            amountCents: 200000,
            customerId: 'c1',
            method: PaymentMethod.transfer,
          ),
          // Julho de 2025: o homólogo.
          Receipt(
            id: 'homologo',
            date: DateTime(2025, 7, 10),
            amountCents: 100000,
            customerId: 'c1',
            method: PaymentMethod.transfer,
          ),
        ],
      ),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    // 1200 contra 1000 do homólogo = +20%. Contra o mês passado seria −40%.
    // Sem reservas na agenda, o previsto do mês é igual ao recebido, por isso
    // a percentagem não muda — muda só o rótulo, que agora diz "previsto".
    expect(
      find.textContaining('▲ 20% previsto vs mesmo mês do ano passado'),
      findsOneWidget,
    );
  });

  testWidgets('sem homólogo, recorre ao mês passado e di-lo', (tester) async {
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        receipts: [
          recebimento('agora', 10, 120000),
          Receipt(
            id: 'anterior',
            date: DateTime(2026, 6, 10),
            amountCents: 200000,
            customerId: 'c1',
            method: PaymentMethod.transfer,
          ),
        ],
      ),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    expect(
      find.textContaining('▼ 40% previsto vs mês passado'),
      findsOneWidget,
    );
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

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

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

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

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

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    expect(find.text('Falta o preço de 1 de 2 máquinas'), findsOneWidget);
  });

  testWidgets('com valor de compra inventado, mostra o retorno e não parte', (
    tester,
  ) async {
    // O Cesar pediu (9 Ago): meter um valor de compra inventado só para ver que
    // a célula acende sem partir. Precisa das duas coisas — preço/dia em TODAS
    // as máquinas e valor de compra em pelo menos uma — senão fica no "falta".
    final container = containerCom(
      OperationsState(
        onboarded: true,
        companyName: 'Alugueres Norte',
        machines: const [
          Machine(
            id: 'm1',
            name: 'Mini escavadora',
            reference: 'ME-01',
            category: 'Escavação',
            status: MachineStatus.available,
            dailyRateCents: 18500,
            purchasePriceCents: 500000, // 5000 € inventados
          ),
        ],
        bookings: [
          Booking(
            id: 'b1',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: dia(14),
            endsAt: dia(16),
            status: BookingStatus.confirmed,
            expectedValueCents: 80000, // 800 € → 16% de 5000 €
          ),
        ],
      ),
    );

    await montarLandscape(
      tester,
      container,
      PaginaDoPainel(ids: idsDaSintese, agora: agora),
    );

    // Deixou de dizer "falta" e passou a medir o retorno. Se a montagem
    // rebentasse por overflow ou excepção, o teste caía aqui.
    expect(find.text('Falta o valor de compra'), findsNothing);
    expect(find.textContaining('16% do investido recuperado'), findsOneWidget);
  });
}
