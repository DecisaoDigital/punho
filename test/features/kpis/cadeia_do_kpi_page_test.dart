import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';
import 'package:punho/features/kpis/presentation/cadeia_do_kpi_page.dart';

import '../dashboard/fixtura.dart';

/// **Descer do número mau até à causa, com o dedo.**
///
/// O motor já sabe dizer quem foi o culpado (`test/core/kpis/atencao_test.dart`
/// prova a conta). Estes testes provam a outra metade: que o gestor lá chega, e
/// que o que lê no caminho não o manda tratar do problema errado.
///
/// O caso é o de Abril de 2026 na Depilconcept, semeado em produção: vendas na
/// mesma, lucro de +1 053 € para −48 €, estrutura de 2 326 € para 3 234 €.
void main() {
  Booking venda(String id, DateTime fim, int cents) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: fim.subtract(const Duration(hours: 9)),
    endsAt: fim,
    status: BookingStatus.completed,
    expectedValueCents: cents,
  );

  Expense despesa(String id, DateTime data, int cents, ExpenseCategory cat) =>
      Expense(
        id: id,
        date: data,
        amountCents: cents,
        category: cat,
        status: ExpensePaymentStatus.paid,
      );

  final emAbril = DateTime(2026, 4, 30, 10);

  OperationsState abrilDeSustos() => estadoComMovimento().copyWith(
    bookings: [
      venda('m-1', DateTime(2026, 3, 15, 18), 337900),
      venda('a-1', DateTime(2026, 4, 15, 18), 340200),
    ],
    expenses: [
      despesa('d-m1', DateTime(2026, 3, 4), 45000, ExpenseCategory.rent),
      despesa('d-m2', DateTime(2026, 3, 4), 187600, ExpenseCategory.salaries),
      despesa('d-a1', DateTime(2026, 4, 4), 62000, ExpenseCategory.rent),
      despesa('d-a2', DateTime(2026, 4, 4), 261400, ExpenseCategory.salaries),
    ],
    receipts: const [],
  );

  Future<void> abrir(WidgetTester tester, String kpiId) => montarLandscape(
    tester,
    containerCom(abrilDeSustos()),
    CadeiaDoKpiPage(kpiId: kpiId, agora: emAbril),
    tamanho: const Size(2177, 1080),
  );

  group('o ecrã de atenção do Lucro', () {
    testWidgets('diz que o lucro caiu e nomeia a estrutura', (tester) async {
      await abrir(tester, 'lucro-mes');

      expect(find.textContaining('O lucro caiu'), findsOneWidget);
      expect(find.textContaining('a estrutura'), findsWidgets);
    });

    testWidgets('não deixa ler que as vendas correram mal', (tester) async {
      // É o erro que este ecrã existe para evitar: um lucro em queda lido como
      // falta de clientes manda o gestor à procura de trabalho que ele já tem.
      await abrir(tester, 'lucro-mes');

      expect(find.textContaining('mantiveram-se'), findsOneWidget);
    });

    testWidgets('mostra os filhos por baixo, para se descer', (tester) async {
      await abrir(tester, 'lucro-mes');

      expect(find.text('O que está por trás deste número'), findsOneWidget);
      expect(find.textContaining('VENDAS DO MÊS'), findsWidgets);
      expect(find.textContaining('ESTRUTURA'), findsWidgets);
    });

    testWidgets('e desce mesmo, ao toque', (tester) async {
      await abrir(tester, 'lucro-mes');
      await tester.tap(find.textContaining('ESTRUTURA').first);
      await tester.pumpAndSettle();

      // A barra do ecrã novo é a da Estrutura, e as migalhas dizem de onde veio.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Estrutura'),
        ),
        findsOneWidget,
      );
      expect(find.text('Lucro do mês'), findsWidgets);
    });
  });

  group('os três meses lado a lado', () {
    testWidgets('o mês anterior aparece em euros, não só em percentagem', (
      tester,
    ) async {
      // Pedido do César (13 Ago 2026): «na realidade eu ali gostava de ver o
      // lucro do mês anterior». A célula só tem espaço para um termo, e escolhe
      // o homólogo — o mês passado, que é o que ele tem fresco na cabeça, não
      // aparecia em lado nenhum.
      await abrir(tester, 'lucro-mes');

      expect(find.text('Este mês'), findsOneWidget);
      expect(find.text('Mês passado'), findsOneWidget);
      // Março: 3379 € de vendas − 2326 € de despesas.
      expect(find.text('1053 €'), findsOneWidget);
    });

    testWidgets('um mês sem uma linha diz "sem registos", não 0 €', (
      tester,
    ) async {
      // 2025 não existe nesta fixtura. Escrever 0 € era dizer que o ano passado
      // correu mal, quando o que houve foi não haver ano passado.
      await abrir(tester, 'lucro-mes');

      expect(find.text('Mesmo mês do ano passado'), findsOneWidget);
      expect(find.text('sem registos'), findsOneWidget);
    });
  });

  group('o break even do mês', () {
    testWidgets('pendura-se no Lucro e diz se o mês já se paga', (
      tester,
    ) async {
      // Abril vendeu 3402 € com 3234 € de estrutura e nenhum custo directo: o
      // mês pagou-se a 15, no dia da única venda.
      await abrir(tester, 'lucro-mes');

      expect(find.textContaining('BREAK EVEN DO MÊS'), findsWidgets);
      expect(find.textContaining('O mês já se paga'), findsOneWidget);
      expect(find.textContaining('Passou a 15 de Abril'), findsOneWidget);
    });
  });

  group('as migalhas', () {
    testWidgets('mostram o caminho todo até à raiz', (tester) async {
      await abrir(tester, 'vendas-mes');

      // Caixa › Lucro do mês › (Vendas do mês, que é onde estamos)
      expect(find.text('Caixa'), findsOneWidget);
      expect(find.text('Lucro do mês'), findsOneWidget);
    });

    testWidgets('a raiz não tem migalhas nenhumas', (tester) async {
      await abrir(tester, 'caixa');
      expect(find.text(' › '), findsNothing);
    });
  });

  group('o caminho para a acção', () {
    testWidgets('a explicação acaba num botão que leva lá', (tester) async {
      await abrir(tester, 'lucro-mes');
      expect(find.textContaining('Ir a '), findsOneWidget);
    });
  });

  group('o toque no painel', () {
    testWidgets('um KPI com filhos abre a cadeia', (tester) async {
      await montarLandscape(
        tester,
        containerCom(abrilDeSustos()),
        const PaginaDoPainel(ids: ['lucro-mes'], agora: null),
        tamanho: const Size(2177, 1080),
      );
      await tester.tap(find.textContaining('LUCRO DO MÊS').first);
      await tester.pumpAndSettle();

      expect(find.byType(CadeiaDoKpiPage), findsOneWidget);
    });

    testWidgets('uma folha não abre — vai directa à acção', (tester) async {
      // As «Entregas hoje» não têm nada por baixo. Abrir uma página que só
      // repetisse a célula era um toque a mais para chegar ao mesmo sítio.
      await montarLandscape(
        tester,
        containerCom(abrilDeSustos()),
        const PaginaDoPainel(ids: ['entregas-hoje'], agora: null),
        tamanho: const Size(2177, 1080),
      );
      await tester.tap(find.textContaining('ENTREGAS HOJE').first);
      await tester.pumpAndSettle();

      expect(find.byType(CadeiaDoKpiPage), findsNothing);
    });
  });
}
