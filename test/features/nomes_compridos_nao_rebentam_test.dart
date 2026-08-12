import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/finance/presentation/finance_pages.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';

import 'dashboard/fixtura.dart';

/// **O que acontece quando o nome não cabe.**
///
/// Achado 6.5: 549 `Text(` no Punho para 49 guardas de `maxLines`/`overflow`.
/// O número é um proxy mau — a esmagadora maioria desses `Text` são rótulos
/// fixos que nunca vão crescer, ou vivem em colunas onde nada os aperta.
///
/// O que interessa é outra coisa: **o texto que vem do cliente**. Um nome de
/// empresa comprido, um cliente com nome completo por extenso, uma máquina com
/// referência longa. Esse não se controla, e é esse que rebenta a linha.
///
/// Em vez de contar `Text(`, este teste renderiza os ecrãs com dados
/// patológicos e deixa o Flutter queixar-se: um `RenderFlex overflowed` é uma
/// excepção a sério, apanhada aqui pelo `takeException`. É a mesma disciplina
/// da sonda descartável — medir em vez de inferir.
///
/// A largura é a do Redmi deitado, 761 dp, que é o aparelho onde isto corre.
void main() {
  const larguraRedmiDeitado = Size(761, 380);
  // Um telemóvel estreito ao alto: onde a largura falta mesmo.
  const larguraApertada = Size(360, 640);

  /// Nomes que ninguém escreveria de propósito e que os clientes escrevem.
  const nomeEnorme =
      'Sociedade de Alugueres e Equipamentos Pesados do Vale do Ave, '
      'Unipessoal Lda. (antiga Irmãos Fernandes & Filhos)';
  const clienteEnorme =
      'Maria da Conceição Fernandes de Almeida Sousa Vasconcelos';
  const maquinaEnorme =
      'Retroescavadora giratória de rastos com martelo hidráulico acoplado';

  OperationsState estadoComNomesEnormes() {
    final base = estadoComMovimento();
    return base.copyWith(
      companyName: nomeEnorme,
      ownerName: clienteEnorme,
      customers: [
        for (final c in base.customers) c.copyWith(name: clienteEnorme),
      ],
      machines: [
        for (final m in base.machines)
          m.copyWith(name: maquinaEnorme, reference: 'REF-$maquinaEnorme'),
      ],
    );
  }

  Future<void> semTransbordo(
    WidgetTester tester,
    Widget pagina, {
    required Size tamanho,
    required String onde,
  }) async {
    await montarLandscape(
      tester,
      containerCom(estadoComNomesEnormes()),
      pagina,
      tamanho: tamanho,
    );
    final excepcao = tester.takeException();
    expect(
      excepcao,
      isNull,
      reason:
          '$onde transbordou com um nome comprido a ${tamanho.width.toInt()} dp',
    );
  }

  group('a ${larguraRedmiDeitado.width.toInt()} dp — o Redmi deitado', () {
    testWidgets('lista de clientes', (t) async {
      await semTransbordo(
        t,
        const ClientsPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'A lista de clientes',
      );
    });

    testWidgets('lista de máquinas', (t) async {
      await semTransbordo(
        t,
        const MachinesPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'A lista de máquinas',
      );
    });

    testWidgets('extracto financeiro', (t) async {
      await semTransbordo(
        t,
        const FinanceListPage(title: 'Despesas', expenses: true),
        tamanho: larguraRedmiDeitado,
        onde: 'O extracto',
      );
    });

    testWidgets('colaboradores', (t) async {
      await semTransbordo(
        t,
        const CollaboratorsPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'A lista de colaboradores',
      );
    });

    testWidgets('veículos', (t) async {
      await semTransbordo(
        t,
        const VehiclesPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'A lista de veículos',
      );
    });

    testWidgets('marcações', (t) async {
      await semTransbordo(
        t,
        const BookingsPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'As marcações',
      );
    });

    testWidgets('painel — é aqui que o nome da empresa aparece por extenso', (
      t,
    ) async {
      await semTransbordo(
        t,
        const DashboardPage(),
        tamanho: larguraRedmiDeitado,
        onde: 'O painel',
      );
    });
  });

  // Controlo negativo. Sete testes que passam à primeira são bom sinal ou são
  // uma sonda avariada, e não há como saber qual sem a fazer falhar de
  // propósito. Isto monta uma linha que transborda de certeza: se este teste
  // deixar de apanhar nada, os outros sete deixaram de valer.
  testWidgets('a sonda sabe apanhar um transbordo', (tester) async {
    tester.view.physicalSize = larguraApertada;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              // Sem `Expanded`: é assim que se parte uma linha em Flutter, e é
              // exactamente o padrão que a sonda existe para caçar.
              Text(nomeEnorme, maxLines: 1),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNotNull,
      reason: 'a sonda deixou passar um transbordo evidente — está avariada',
    );
  });

  group('a ${larguraApertada.width.toInt()} dp — telemóvel estreito ao alto', () {
    testWidgets('lista de clientes', (t) async {
      await semTransbordo(
        t,
        const ClientsPage(),
        tamanho: larguraApertada,
        onde: 'A lista de clientes',
      );
    });

    testWidgets('lista de máquinas', (t) async {
      await semTransbordo(
        t,
        const MachinesPage(),
        tamanho: larguraApertada,
        onde: 'A lista de máquinas',
      );
    });

    testWidgets('extracto financeiro', (t) async {
      await semTransbordo(
        t,
        const FinanceListPage(title: 'Despesas', expenses: true),
        tamanho: larguraApertada,
        onde: 'O extracto',
      );
    });
  });
}
