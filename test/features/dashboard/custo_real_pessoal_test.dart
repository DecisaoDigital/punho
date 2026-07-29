import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/finance/regime_fiscal.dart';
import 'package:punho/core/operations/kpis.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/dashboard/presentation/todas_metricas_page.dart';

import 'fixtura.dart';

/// "Custo real com pessoal": o que sai mesmo da empresa, e não só o vencimento.
///
/// O KPI antigo mostrava a soma dos brutos. Para quem tem gente com contrato
/// isso subestima o custo em quase um quarto — a TSU da entidade patronal não
/// aparece em vencimento nenhum.
void main() {
  Collaborator pessoa(
    String id, {
    required int brutoCents,
    EmploymentType tipo = EmploymentType.contrato,
    bool archived = false,
    CollaboratorStatus status = CollaboratorStatus.active,
  }) => Collaborator(
    id: id,
    name: 'Pessoa $id',
    status: status,
    costCents: brutoCents,
    employmentType: tipo,
    archived: archived,
  );

  OperationsState comEquipa(
    List<Collaborator> equipa, {
    String legalForm = 'Lda.',
  }) => estadoComMovimento().copyWith(
    collaborators: equipa,
    legalForm: legalForm,
  );

  group('custoRealComPessoalMes', () {
    test('dois contratados de 1.000 € e um a recibos verdes de 500 €', () {
      final r = custoRealComPessoalMes(
        comEquipa([
          pessoa('a', brutoCents: 100000),
          pessoa('b', brutoCents: 100000),
          pessoa('c', brutoCents: 50000, tipo: EmploymentType.recibosVerdes),
        ]),
        regime: RegimeFiscal.ldaIrc,
      );

      expect(r.bruto, 250000);
      // Só sobre os dois contratados: 23,75% de 2.000 €.
      expect(r.tsuPatronal, 47500);
      expect(r.total, 297500);
    });

    test('recibos verdes não geram TSU patronal nenhuma', () {
      final r = custoRealComPessoalMes(
        comEquipa([
          pessoa('a', brutoCents: 80000, tipo: EmploymentType.recibosVerdes),
        ]),
        regime: RegimeFiscal.ldaIrc,
      );

      expect(r.bruto, 80000);
      expect(r.tsuPatronal, 0);
      expect(r.total, 80000);
    });

    test('arquivados e inactivos não contam', () {
      final r = custoRealComPessoalMes(
        comEquipa([
          pessoa('a', brutoCents: 100000),
          pessoa('arquivado', brutoCents: 900000, archived: true),
          pessoa(
            'inactivo',
            brutoCents: 900000,
            status: CollaboratorStatus.inactive,
          ),
        ]),
        regime: RegimeFiscal.ldaIrc,
      );

      expect(r.bruto, 100000);
      expect(r.total, 123750);
    });

    test('quem não tem custo declarado não entra na soma', () {
      // Zero seria uma afirmação — "não custa nada" — e o que se passa é que a
      // ficha está incompleta.
      final r = custoRealComPessoalMes(
        comEquipa([
          pessoa('a', brutoCents: 100000),
          const Collaborator(
            id: 'sem-custo',
            name: 'Sem custo',
            status: CollaboratorStatus.active,
          ),
        ]),
        regime: RegimeFiscal.ldaIrc,
      );

      expect(r.bruto, 100000);
      expect(r.total, 123750);
    });

    test('um ENI com empregados paga TSU patronal como qualquer entidade', () {
      final r = custoRealComPessoalMes(
        comEquipa([
          pessoa('a', brutoCents: 100000),
        ], legalForm: 'Empresário em Nome Individual'),
        regime: RegimeFiscal.eniSimplificado,
      );

      expect(r.tsuPatronal, 23750);
      expect(r.total, 123750);
    });

    test('regime não modelado não devolve zero, devolve null', () {
      // Decisão 1: KPI que não se aplica ao regime esconde-se, não aparece a
      // 0 €. Mostrar KPI irrelevante é ruído pior do que ausência.
      final r = custoRealComPessoalMes(
        comEquipa([pessoa('a', brutoCents: 100000)], legalForm: 'S.A.'),
        regime: RegimeFiscal.outro,
      );

      expect(r.bruto, isNull);
      expect(r.tsuPatronal, isNull);
      expect(r.total, isNull);
    });

    test('sem equipa é zero, e isso é uma afirmação verdadeira', () {
      final r = custoRealComPessoalMes(
        comEquipa(const []),
        regime: RegimeFiscal.ldaIrc,
      );

      expect(r.total, 0);
    });
  });

  group('Slide Custos', () {
    Future<void> abrirCustos(WidgetTester tester, OperationsState estado) async {
      await montarLandscape(
        tester,
        containerCom(estado),
        DashboardPage(agora: agoraFixa),
        tamanho: const Size(1280, 800),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Slide seguinte'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('mostra o custo real e as duas parcelas', (tester) async {
      await abrirCustos(
        tester,
        comEquipa([
          pessoa('a', brutoCents: 100000),
          pessoa('b', brutoCents: 50000, tipo: EmploymentType.recibosVerdes),
        ]),
      );

      expect(find.text('Custo real com pessoal'), findsOneWidget);
      // 1.500 € de bruto + 237,50 € de TSU sobre o contratado.
      expect(find.textContaining('1738 €'), findsOneWidget);
      expect(find.textContaining('Bruto pago'), findsOneWidget);
      expect(find.textContaining('TSU patronal'), findsOneWidget);
    });

    testWidgets('regime não modelado esconde o número', (tester) async {
      await abrirCustos(
        tester,
        comEquipa([pessoa('a', brutoCents: 100000)], legalForm: 'S.A.'),
      );

      expect(find.textContaining('forma jurídica'), findsOneWidget);
      expect(find.textContaining('Bruto pago'), findsNothing);
    });

    testWidgets('só recibos verdes: sem linha de TSU', (tester) async {
      // Não faz sentido mostrar "TSU patronal: 0,00 €" a quem não tem contratos.
      await abrirCustos(
        tester,
        comEquipa([
          pessoa('a', brutoCents: 80000, tipo: EmploymentType.recibosVerdes),
        ]),
      );

      expect(find.textContaining('Bruto pago'), findsOneWidget);
      expect(find.textContaining('TSU patronal'), findsNothing);
    });
  });

  group('TodasMetricasPage', () {
    testWidgets('as três linhas novas na secção Custos', (tester) async {
      await montarLandscape(
        tester,
        containerCom(
          comEquipa([
            pessoa('a', brutoCents: 100000),
            pessoa('b', brutoCents: 100000),
          ]),
        ),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 2600),
      );

      expect(find.text('Bruto pago'), findsOneWidget);
      expect(find.text('TSU patronal (contratados)'), findsOneWidget);
      expect(find.text('Custo real com pessoal'), findsOneWidget);
    });

    testWidgets('regime não modelado faz as três linhas desaparecer', (
      tester,
    ) async {
      await montarLandscape(
        tester,
        containerCom(
          comEquipa([pessoa('a', brutoCents: 100000)], legalForm: 'S.A.'),
        ),
        TodasMetricasPage(agora: agoraFixa),
        tamanho: const Size(1100, 2600),
      );

      expect(find.text('Bruto pago'), findsNothing);
      expect(find.text('Custo real com pessoal'), findsNothing);
    });
  });
}
