import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/navigation/app_destination.dart';
import 'package:punho/core/navigation/navigation_controller.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/features/company/presentation/company_settings_page.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/features/tarefas/domain/tarefa.dart';
import 'package:punho/features/tarefas/presentation/tarefas_page.dart';

import '../dashboard/fixtura.dart';

void main() {
  group('Fontes das tarefas', () {
    test('junta cobranças, dados em falta, fichas e frota', () {
      final tarefas = tarefasPendentes(estadoComMovimento(), agoraFixa);
      final ids = tarefas.map((t) => t.id).toList();

      expect(ids, contains('cobranca-b-atraso'));
      expect(ids, contains('colaboradores-incompletos'));
      // O que está resolvido não aparece: a frota tem veículo registado e as 3
      // máquinas declaradas estão todas identificadas.
      expect(ids, isNot(contains('frota-sem-veiculos')));
      expect(ids, isNot(contains('maquinas-por-identificar')));
    });

    test('máquinas declaradas a mais geram tarefa de identificação', () {
      final comFalta = estadoComMovimento().copyWith(
        totalMachinesDeclared: 8,
      );
      final tarefa = tarefasPendentes(
        comFalta,
        agoraFixa,
      ).firstWhere((t) => t.id == 'maquinas-por-identificar');

      expect(tarefa.titulo, 'Identificar 5 máquinas');
      expect(tarefa.destino, DestinoTarefa.maquinas);
    });

    test('urgentes vêm primeiro', () {
      final tarefas = tarefasPendentes(estadoComMovimento(), agoraFixa);

      expect(tarefas.first.severidade, SeveridadeTarefa.urgente);
      expect(
        tarefas.map((t) => t.severidade.prioridade).toList(),
        orderedEquals(
          List.of(tarefas.map((t) => t.severidade.prioridade))
            ..sort((a, b) => b.compareTo(a)),
        ),
      );
    });

    test('a cobrança em atraso diz quem, quanto e há quanto tempo', () {
      final cobranca = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
      ).firstWhere((t) => t.id == 'cobranca-b-atraso');

      expect(cobranca.titulo, 'Cobrar João Pereira');
      expect(cobranca.subtitulo, contains('780,00 €'));
      expect(cobranca.subtitulo, contains('20 dias'));
      expect(cobranca.destino, DestinoTarefa.clientes);
    });

    test('recomendação adiada aparece como sugestão', () {
      final tarefas = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        recomendacoesAdiadas: {
          'pending': agoraFixa.add(const Duration(days: 7)),
        },
      );

      final sugestao = tarefas.firstWhere(
        (t) => t.severidade == SeveridadeTarefa.sugestao,
      );
      expect(sugestao.id, 'recomendacao-pending');
      expect(sugestao.subtitulo, contains('volta a 22/07'));
    });

    test('frota declarada sem veículos gera tarefa', () {
      final semVeiculos = estadoSemMovimento().copyWith(hasFleet: true);
      final ids = tarefasPendentes(semVeiculos, agoraFixa).map((t) => t.id);

      expect(ids, contains('frota-sem-veiculos'));
    });

    test('o NIF em falta é urgente; a morada não', () {
      final tarefas = tarefasPendentes(estadoSemMovimento(), agoraFixa);
      final nif = tarefas.firstWhere((t) => t.titulo.contains('NIF'));
      final morada = tarefas.firstWhere((t) => t.titulo.contains('morada'));

      expect(nif.severidade, SeveridadeTarefa.urgente);
      expect(morada.severidade, SeveridadeTarefa.aCompletar);
    });
  });

  group('Página de Tarefas', () {
    testWidgets('conta as tarefas e agrupa-as por severidade', (tester) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(tester, container, const TarefasPage());

      final total = container.read(tarefasProvider).length;
      expect(find.text('$total tarefas pendentes'), findsOneWidget);
      expect(find.text('URGENTE'), findsOneWidget);
      expect(find.text('A COMPLETAR'), findsOneWidget);
      expect(find.text('Cobrar João Pereira'), findsOneWidget);
    });

    testWidgets('a CTA de um dado em falta abre as Definições', (tester) async {
      final container = containerCom(estadoComMovimento());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TarefasPage())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preencher →').first);
      await tester.pumpAndSettle();

      expect(find.byType(CompanySettingsPage), findsOneWidget);
    });

    testWidgets('a CTA de uma cobrança muda para a área de Clientes', (
      tester,
    ) async {
      final container = containerCom(estadoComMovimento());
      await montarLandscape(tester, container, const TarefasPage());

      await tester.tap(find.text('Ver cliente →').first);
      await tester.pumpAndSettle();

      expect(container.read(navigationProvider), AppDestination.clients);
    });

    testWidgets('sem nada pendente mostra o estado vazio', (tester) async {
      // Empresa com tudo preenchido e sem dívidas: o ecrã não deve fingir
      // trabalho que não existe.
      final container = containerCom(
        estadoSemMovimento().copyWith(
          companyTaxId: '501234567',
          ownerName: 'Alfredo',
          companyPhone: '912 000 000',
          companyAddress: 'Rua 1',
          companyPostalCode: '4700-000',
          companyLocality: 'Braga',
          revenueLastYearCents: 1,
          revenueThisYearCents: 1,
          maintenanceLastYearCents: 1,
          fixedMonthlyCostsCents: 1,
          // O histórico completo do ano passado é uma das tarefas de dados
          // iniciais; sem ele nunca se chegava ao estado vazio.
          historicalMonths: [
            for (var mes = 1; mes <= 12; mes++)
              HistoricalMonth(
                year: agoraFixa.year - 1,
                month: mes,
                revenueReceivedCents: 100000,
              ),
          ],
        ),
      );
      await montarLandscape(tester, container, const TarefasPage());

      expect(find.text('Nada pendente'), findsOneWidget);
    });
  });
}
