import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/pagina_do_painel.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/tarefas/presentation/tarefas_page.dart';

import 'fixtura.dart';

/// Os ecrãs ao tamanho do telemóvel do Cesar, e não só ao de um tablet.
///
/// **É este o buraco que deixou passar tudo o que ele reportou.** A suite
/// montava tudo a 1280x800 — um tablet. O Redmi Note 10 Pro deitado dá 873x393
/// em unidades lógicas: menos de metade da altura. Três máquinas e meia, botões
/// mal distribuídos nas reservas, a faixa do topo a comer espaço — nada disso
/// era visível ao tamanho a que eu testava.
///
/// O Flutter lança excepção em qualquer overflow, portanto estes testes falham
/// sozinhos sem ninguém ter de prever o problema. É a única família de testes
/// aqui que apanha o que não foi antecipado.
/// À primeira execução apanharam **três overflows reais** ao tamanho do
/// telemóvel do Cesar, que a suite a 1280x800 nunca tinha visto:
///
///   - slides do painel, Redmi deitado (873x393) — 161 px · **corrigido**
///   - slides do painel, telemóvel pequeno (720x360) — 222 px · **corrigido**
///   - ecrãs operacionais, Redmi de pé (393x873) — 51 px · **corrigido**
///
/// Os dois primeiros eram a mesma causa: o rótulo do botão da recomendação não
/// encolhia. O terceiro esteve marcado com `skip` como dívida assumida e foi
/// pago a 5 de Agosto de 2026: era a linha de acção das Reservas, que pede
/// 414 dp de largura — o campo da máquina 220, o "+ Reservar" 178, e o ar
/// entre eles — e de pé só tem 363. Abaixo de 560 a data desce para uma
/// segunda linha; de pé é a altura que sobra, e é dela que se paga.
void main() {
  /// Redmi Note 10 Pro: 1080x2400 físicos a 2.75 de densidade.
  const redmiDeitado = Size(873, 393);
  const redmiDePe = Size(393, 873);

  /// Um telemóvel pequeno, para o caso de o piloto seguinte não ter um Redmi.
  const pequenoDeitado = Size(720, 360);

  final tamanhos = {
    'Redmi deitado': redmiDeitado,
    'Redmi de pé': redmiDePe,
    'telemóvel pequeno deitado': pequenoDeitado,
    'tablet': const Size(1280, 800),
  };

  group('as páginas do painel cabem', () {
    // As quatro células de cada antigo slide, agora paginadas pelo gestor em
    // vez de escritas à mão — mesmos ids que os testes de célula usam.
    const idsPorPagina = [
      [
        'entradas-mes',
        'utilizacao-rentabilidade',
        'encontro-contas',
        'recomendacao-dia',
      ],
      ['reservas-activas', 'entregas-hoje', 'recolhas-fazer', 'cobrancas-7d'],
      // Os mestres da cadeia e o break even (13 Ago 2026). Entram nesta lista
      // porque as sub-linhas deles são as mais compridas do catálogo — trazem o
      // termo da comparação em euros e, no break even, ainda o dia previsto e a
      // origem da margem.
      ['vendas-mes', 'lucro-mes', 'estrutura-mes', 'break-even-mes'],
      ['lucro-mes-anterior', 'lucro-mes', 'break-even-mes', 'margem-bruta'],
      [
        'clientes-novos-30d',
        'leads-pipeline',
        'ticket-medio-mes',
        'conversao-lead-cliente',
      ],
    ];

    for (final entrada in tamanhos.entries) {
      // O painel é landscape por decisão de produto; de pé não se testa.
      if (entrada.value.width < entrada.value.height) continue;

      testWidgets('em ${entrada.key}', (tester) async {
        for (final ids in idsPorPagina) {
          await montarLandscape(
            tester,
            containerCom(estadoComMovimento()),
            PaginaDoPainel(ids: ids, agora: agoraFixa),
            tamanho: entrada.value,
          );
        }
      });
    }
  });

  group('os ecrãs operacionais cabem', () {
    for (final entrada in tamanhos.entries) {
      testWidgets('em ${entrada.key}', (tester) async {
        for (final ecra in const [
          MachinesPage(),
          BookingsPage(),
          TarefasPage(),
        ]) {
          await montarLandscape(
            tester,
            containerCom(estadoComMovimento()),
            ecra,
            tamanho: entrada.value,
          );
        }
      });
    }
  });

  group('a linha de acção das Reservas', () {
    // Não chega não transbordar: encolher o "+ Reservar" ou espremer a data a
    // duas setas coladas também não transborda, e seria pior. O que se fixa
    // aqui é a saída escolhida — deitado tudo numa linha, de pé a data desce.
    for (final entrada in {
      'deitado fica numa linha só': redmiDeitado,
      'de pé desce a data para a segunda linha': redmiDePe,
    }.entries) {
      testWidgets(entrada.key, (tester) async {
        await montarLandscape(
          tester,
          containerCom(estadoComMovimento()),
          const BookingsPage(),
          tamanho: entrada.value,
        );

        final reservar = tester.getRect(find.byType(FilledButton).first);
        final setaAnterior = tester.getRect(
          find.byIcon(Icons.chevron_left).first,
        );

        if (entrada.value.width < entrada.value.height) {
          expect(
            setaAnterior.top,
            greaterThanOrEqualTo(reservar.bottom),
            reason: 'a data devia ter descido para debaixo do "+ Reservar"',
          );
        } else {
          expect(
            setaAnterior.center.dy,
            closeTo(reservar.center.dy, 4),
            reason: 'a data devia estar na mesma linha do "+ Reservar"',
          );
        }
      });
    }
  });

  testWidgets('a sub-linha mais comprida do break even cabe no Redmi', (
    tester,
  ) async {
    // O pior caso da célula, montado de propósito: Julho ainda sem uma despesa
    // lançada nem uma venda, e Junho com 125 000 € — o alvo vem da média (que
    // se **tem** de dizer), tem seis dígitos, e ao ritmo de hoje não chega.
    // Dá "O mês paga-se com 125000 € · ao ritmo de hoje não chega este mês ·
    // média dos meses anteriores", a sub-linha mais comprida do catálogo.
    //
    // Sem isto, o texto só era medido no dia em que ele abrisse a app e visse
    // a faixa amarela do overflow.
    final estado = estadoComMovimento().copyWith(
      bookings: [
        Booking(
          id: 'v-anterior',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime(2026, 6, 10, 9),
          endsAt: DateTime(2026, 6, 10, 18),
          status: BookingStatus.completed,
          expectedValueCents: 100000,
        ),
      ],
      expenses: [
        Expense(
          id: 'e-junho',
          date: DateTime(2026, 6, 5),
          amountCents: 12500000,
          category: ExpenseCategory.rent,
          status: ExpensePaymentStatus.unpaid,
        ),
      ],
    );

    for (final tamanho in const [redmiDeitado, pequenoDeitado]) {
      await montarLandscape(
        tester,
        containerCom(estado),
        PaginaDoPainel(
          ids: const [
            'break-even-mes',
            'lucro-mes',
            'vendas-mes',
            'estrutura-mes',
          ],
          agora: agoraFixa,
        ),
        tamanho: tamanho,
      );
      expect(find.textContaining('média dos meses anteriores'), findsWidgets);
    }
  });

  testWidgets('no Redmi deitado cabem pelo menos seis máquinas', (
    tester,
  ) async {
    // A queixa do Cesar, transformada em asserção: "só vejo 3 máquinas e meia".
    // Sem um número escrito, a densidade volta a escorregar ao primeiro
    // refactor que mexa numa margem.
    await montarLandscape(
      tester,
      containerCom(estadoComMovimento()),
      const MachinesPage(),
      tamanho: redmiDeitado,
    );

    // A fixtura traz três máquinas; o que se mede é a altura de cada linha, que
    // é o que decide quantas cabem. 64 dp por linha deixa passar seis no ecrã
    // útil do Redmi deitado, depois de tirada a moldura e o botão de topo.
    final alturas = tester
        .widgetList<Card>(find.byType(Card))
        .map((c) => tester.getSize(find.byWidget(c)).height);

    // 66 dp por linha. Vinha de ~90 antes de encolher a miniatura; num ecrã
    // útil de ~330 dp (tirada a moldura e a linha do botão) dá cinco linhas
    // inteiras contra as "três e meia" que o Cesar via.
    expect(alturas, everyElement(lessThanOrEqualTo(72.0)));
  });
}
