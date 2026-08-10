import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/caixa.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';
import 'package:punho/features/kpis/presentation/cartao_caixa.dart';

import '../dashboard/fixtura.dart';

/// **A Caixa diz como está, não só quanto está.**
///
/// «cada KPI deve ter na sua frente as regras de apreciação do próprio» —
/// Cesar, 5/8/2026. O cartão mostrava "+ 1 240 €" e mais nada: quem lê não fica
/// a saber se isso é um bom mês ou o pior do ano.
///
/// A referência é a própria empresa — não há média de sector nenhuma, e
/// inventá-la seria pior do que calar. Ver `apreciar` e
/// [mediaDosMesesAnteriores].
void main() {
  final agora = DateTime(2026, 8, 10, 12);

  Receipt recebimento(String id, DateTime data, int cents) => Receipt(
    id: id,
    date: data,
    amountCents: cents,
    customerId: 'c1',
    method: PaymentMethod.cash,
  );

  /// Empresa que só recebe: os meses anteriores dão a média, o corrente dá o
  /// valor a apreciar. Sem despesas de propósito — o que está em causa aqui é a
  /// comparação, não a soma.
  OperationsState comRecebimentos(List<Receipt> recibos) =>
      OperationsState(onboarded: true, receipts: recibos);

  group('a média dos meses anteriores', () {
    test('conta cada mês até ao mesmo dia, não o mês inteiro', () {
      // No dia 10, comparar dez dias deste mês com meses inteiros dava sempre
      // "estás muito abaixo" no princípio do mês e "recuperaste" no fim.
      final estado = comRecebimentos([
        recebimento('r1', DateTime(2026, 7, 5), 10000),
        // Depois do dia 10 de Julho: fora da janela.
        recebimento('r2', DateTime(2026, 7, 20), 90000),
      ]);

      expect(mediaDosMesesAnteriores(estado, agora), 10000);
    });

    test('meses sem movimento nenhum não entram na média', () {
      // Contá-los como zero puxava a média para baixo por causa de um mês em
      // que a empresa esteve fechada.
      final estado = comRecebimentos([
        recebimento('r1', DateTime(2026, 7, 5), 10000),
        recebimento('r2', DateTime(2026, 5, 5), 30000),
      ]);

      expect(mediaDosMesesAnteriores(estado, agora), 20000);
    });

    test('sem passado nenhum não há média', () {
      final estado = comRecebimentos([
        recebimento('r1', DateTime(2026, 8, 3), 10000),
      ]);

      expect(mediaDosMesesAnteriores(estado, agora), isNull);
    });
  });

  group('o que o cartão diz', () {
    Future<void> montar(WidgetTester tester, OperationsState estado) =>
        montarLandscape(
          tester,
          containerCom(estado),
          SizedBox(height: 165, width: 431, child: CartaoCaixa(agora: agora)),
          tamanho: const Size(750, 393),
        );

    testWidgets('mês melhor que o costume: diz que está acima e quanto', (
      tester,
    ) async {
      await montar(
        tester,
        comRecebimentos([
          recebimento('r1', DateTime(2026, 7, 5), 10000),
          recebimento('r2', DateTime(2026, 8, 5), 12000),
        ]),
      );

      expect(find.text('Estás acima da tua média em 20%.'), findsOneWidget);
    });

    testWidgets('mês pior também tem frase — não fica calado', (tester) async {
      // A metade do pedido que é fácil esquecer.
      await montar(
        tester,
        comRecebimentos([
          recebimento('r1', DateTime(2026, 7, 5), 10000),
          recebimento('r2', DateTime(2026, 8, 5), 7000),
        ]),
      );

      expect(find.text('Estás abaixo da tua média em 30%.'), findsOneWidget);
    });

    testWidgets('primeiro mês: diz que ainda não há com que comparar', (
      tester,
    ) async {
      // Nunca "estás em linha com a média" quando média não há.
      await montar(
        tester,
        comRecebimentos([recebimento('r1', DateTime(2026, 8, 5), 12000)]),
      );

      expect(find.textContaining('primeiro mês com registos'), findsOneWidget);
    });

    testWidgets('a frase cabe no cartão do painel sem o rebentar', (
      tester,
    ) async {
      // A célula do painel mede 431x165 no Redmi deitado — medido, não
      // estimado — e a frase tem de caber lá dentro.
      await montar(
        tester,
        comRecebimentos([
          recebimento('r1', DateTime(2026, 7, 5), 10000),
          recebimento('r2', DateTime(2026, 8, 5), 12000),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CelulaSemaforo), findsOneWidget);
    });
  });
}
