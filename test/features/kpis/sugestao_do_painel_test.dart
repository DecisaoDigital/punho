import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/operations/painel_controller.dart';
import 'package:punho/domain/models/arranjo_do_painel.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/kpis/domain/sugestao_do_painel.dart';
import 'package:punho/features/kpis/presentation/kpis_page.dart';

import '../dashboard/fixtura.dart';

/// **A última peça do plano de KPIs, e a parte dela que não se fez.**
///
/// O plano previa «promoção automática ao painel». O painel é do gestor — ele
/// montou-o à mão, caixa a caixa, e uma app que lhe troca as células enquanto
/// ele não olha tira-lhe o que a bancada lhe deu. O que se construiu é a
/// proposta: uma frase e um botão.
///
/// A regra que estes testes guardam é uma só — **propõe-se o filho que explica
/// um número que está mau e já está no painel**. Sem pai no painel não há
/// proposta; sem número mau não há proposta; e um filho que ainda não passou
/// pelo nosso crivo não se propõe, pela mesma razão por que não tem caixa de
/// marcar na bancada.
void main() {
  final agosto = DateTime(2026, 8, 13, 21);

  Booking venda(String id, DateTime fim, int cents) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: const ['m1'],
    startsAt: fim.subtract(const Duration(hours: 9)),
    endsAt: fim,
    status: BookingStatus.completed,
    expectedValueCents: cents,
  );

  Expense despesa(String id, DateTime data, int cents) => Expense(
    id: id,
    date: data,
    amountCents: cents,
    // Renda: fica na estrutura e não nos custos de servir o trabalho, que é o
    // que faz a decomposição do lucro apontar para o KPI da Estrutura.
    category: ExpenseCategory.rent,
    status: ExpensePaymentStatus.paid,
  );

  /// Agosto de 2026 contra Agosto de 2025 — o homólogo, que é o termo que a
  /// app escolhe quando existe.
  OperationsState comHomologo({
    required int vendasAgora,
    required int estruturaAgora,
    int vendasHomologo = 500000,
    int estruturaHomologo = 100000,
  }) => OperationsState(
    bookings: [
      venda('h', DateTime(2025, 8, 6, 18), vendasHomologo),
      venda('a', DateTime(2026, 8, 6, 18), vendasAgora),
    ],
    expenses: [
      despesa('eh', DateTime(2025, 8, 4), estruturaHomologo),
      despesa('ea', DateTime(2026, 8, 4), estruturaAgora),
    ],
  );

  ArranjoDoPainel painelCom(List<String> ids) {
    var arranjo = ArranjoDoPainel.vazio;
    for (final id in ids) {
      arranjo = arranjo.comEscolha(id, escolher: true);
    }
    return arranjo;
  }

  group('quem sobe', () {
    test('no lucro é a conta que manda, não a cor da célula', () {
      // Vendas iguais ao ano passado, estrutura a dobrar: o lucro caiu 1000 € e
      // a decomposição sabe ao cêntimo de quem foi a culpa. Não se adivinha
      // pelo semáforo — a célula das Vendas está verde e não é ela.
      final estado = comHomologo(vendasAgora: 500000, estruturaAgora: 200000);
      final s = sugestaoDoPainel(estado, painelCom(['lucro-mes']), agosto)!;

      expect(s.kpi.id, 'estrutura-mes');
      expect(s.pai.id, 'lucro-mes');
      expect(
        s.motivo,
        'O lucro caiu 1000 € e o que mais pesou foi a estrutura.',
      );
    });

    test('e quando foram as vendas, o verbo concorda com elas', () {
      // «o que mais pesou foi as vendas» é o que sai de escrever a frase sem
      // olhar para o sujeito. Num ecrã que se lê todos os dias, um erro destes
      // desgasta a confiança em tudo o resto que lá está escrito.
      final estado = comHomologo(vendasAgora: 100000, estruturaAgora: 100000);
      final s = sugestaoDoPainel(estado, painelCom(['lucro-mes']), agosto)!;

      expect(s.kpi.id, 'vendas-mes');
      expect(
        s.motivo,
        'O lucro caiu 4000 € e o que mais pesou foram as vendas.',
      );
    });

    test('fora do lucro, exige-se que o filho esteja mau também', () {
      // Com as Vendas e a Estrutura já no painel, sobra o Break even — e ele
      // só se propõe por estar ele próprio em alerta (o mês ainda não se paga:
      // 1000 € vendidos para 2000 € de despesa).
      final estado = comHomologo(vendasAgora: 100000, estruturaAgora: 200000);
      final s = sugestaoDoPainel(
        estado,
        painelCom(['lucro-mes', 'vendas-mes', 'estrutura-mes']),
        agosto,
      )!;

      expect(s.kpi.id, 'break-even-mes');
      expect(
        s.motivo,
        'Lucro do mês está em alerta, e Break even do mês também — '
        'é aí que se vê porquê.',
      );
    });
  });

  group('quando não se diz nada', () {
    test('painel vazio: ele ainda não escolheu ver número nenhum', () {
      final estado = comHomologo(vendasAgora: 100000, estruturaAgora: 200000);
      expect(sugestaoDoPainel(estado, ArranjoDoPainel.vazio, agosto), isNull);
    });

    test('o número está bem — não há o que explicar', () {
      // Lucro a subir: a célula está verde e uma proposta aqui era ruído.
      final estado = comHomologo(vendasAgora: 900000, estruturaAgora: 100000);
      expect(
        sugestaoDoPainel(estado, painelCom(['lucro-mes']), agosto),
        isNull,
      );
    });

    test('os filhos todos já estão no painel', () {
      final estado = comHomologo(vendasAgora: 500000, estruturaAgora: 200000);
      expect(
        sugestaoDoPainel(
          estado,
          painelCom([
            'lucro-mes',
            'vendas-mes',
            'estrutura-mes',
            'break-even-mes',
          ]),
          agosto,
        ),
        isNull,
      );
    });

    test('um KPI à espera de dados não está mau, está por começar', () {
      // Empresa sem uma linha escrita: metade do catálogo diz «aguarda». Se
      // `aguarda` contasse como mau, quem abrisse a app pela primeira vez
      // levava uma proposta para explicar um número que ainda não existe.
      const estado = OperationsState();
      expect(
        sugestaoDoPainel(estado, painelCom(['lucro-mes', 'caixa']), agosto),
        isNull,
      );
    });
  });

  group('na bancada', () {
    test('o filho fica ao lado do pai, e não no fim da fila', () {
      // O painel mostra quatro por página. No fim da fila, a explicação cai na
      // página seguinte — e ver os dois juntos passava a exigir um arrasto.
      final arranjo = painelCom([
        'lucro-mes',
        'caixa',
      ]).comEscolhaJuntoDe('estrutura-mes', depoisDe: 'lucro-mes');

      expect(arranjo.noPainel, ['lucro-mes', 'estrutura-mes', 'caixa']);
    });

    test('aceitar duas vezes não o deixa duas vezes na arrumação', () {
      final arranjo = painelCom(['lucro-mes', 'caixa'])
          .comEscolhaJuntoDe('caixa', depoisDe: 'lucro-mes')
          .comEscolhaJuntoDe('caixa', depoisDe: 'lucro-mes');

      expect(arranjo.ordem, ['lucro-mes', 'caixa']);
    });

    testWidgets('a linha propõe, e o botão é que põe', (tester) async {
      final estado = comHomologo(vendasAgora: 500000, estruturaAgora: 200000);
      final container = containerCom(estado);
      container
          .read(painelProvider.notifier)
          .alternar('lucro-mes', escolher: true);
      await montarLandscape(tester, container, KpisPage(agora: agosto));

      expect(
        find.text('O lucro caiu 1000 € e o que mais pesou foi a estrutura.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Pôr no painel'));
      await tester.pumpAndSettle();

      expect(container.read(painelProvider).noPainel, [
        'lucro-mes',
        'estrutura-mes',
      ]);
      // E cala-se: aceite a proposta, não há segunda para o mesmo número — os
      // outros dois filhos do Lucro estão verdes.
      expect(find.text('Pôr no painel'), findsNothing);
    });

    testWidgets('sem nada a dizer, a linha não existe', (tester) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(tester, container, KpisPage(agora: agoraFixa));

      expect(find.text('Pôr no painel'), findsNothing);
    });

    testWidgets('e cabe no Redmi deitado, sem comer os cartões', (
      tester,
    ) async {
      // O canvas real do aparelho dele, o mesmo de `bancada_do_painel_test`: a
      // janela menos a barra lateral e a faixa do topo. A bancada existe para
      // mostrar KPIs — uma linha de proposta que empurrasse o terceiro cartão
      // para fora do ecrã custava mais do que vale.
      const canvasDoRedmi = Size(791.6 - 88, 392.7 - 27);
      final estado = comHomologo(vendasAgora: 500000, estruturaAgora: 200000);
      final container = containerCom(estado);
      container
          .read(painelProvider.notifier)
          .alternar('lucro-mes', escolher: true);
      await montarLandscape(
        tester,
        container,
        KpisPage(agora: agosto),
        tamanho: canvasDoRedmi,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pôr no painel'), findsOneWidget);
      // A proposta ocupa uma linha, e uma linha é o que ela pode ocupar.
      expect(
        tester.getSize(find.text('Pôr no painel')).height,
        lessThan(32),
        reason: 'o botão passou a duas linhas',
      );
    });
  });
}
