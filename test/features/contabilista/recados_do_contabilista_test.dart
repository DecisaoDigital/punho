import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/contabilista/contabilista_providers.dart';
import 'package:punho/features/contabilista/data/contabilista_service.dart';
import 'package:punho/features/contabilista/domain/contabilista.dart';
import 'package:punho/features/contabilista/presentation/historico_contabilista_page.dart';

/// A caixa do fim do portal do contabilista gravava numa tabela que nenhum ecrã
/// lia. Ele escrevia, a app respondia "guardado", e o recado morria ali.
///
/// Uma caixa que engole é pior do que não haver caixa: quem escreve fica
/// convencido de que avisou, e o aviso costuma ser exactamente o que explica um
/// número esquisito. Estes testes fixam a outra ponta do canal.
void main() {
  MensagemContabilista recado({
    String id = 'm1',
    String texto = 'O valor de Março inclui uma nota de crédito de 800 €.',
    DateTime? criado,
    DateTime? lido,
  }) => MensagemContabilista(
    id: id,
    texto: texto,
    criadoEm: criado ?? DateTime(2026, 8, 4, 16, 30),
    lidoEm: lido,
  );

  Future<_ServicoFalso> montar(
    WidgetTester tester,
    List<MensagemContabilista> recados,
  ) async {
    final servico = _ServicoFalso(recados);
    tester.view.physicalSize = const Size(872.7, 392.7);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contabilistaServiceProvider.overrideWithValue(servico)],
        child: MaterialApp(
          theme: PunhoTheme.light,
          home: const Scaffold(body: HistoricoContabilistaPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return servico;
  }

  testWidgets('o recado do contabilista aparece ao gestor', (tester) async {
    await montar(tester, [recado()]);

    expect(find.text('O contabilista deixou-lhe recado'), findsOneWidget);
    expect(
      find.text('O valor de Março inclui uma nota de crédito de 800 €.'),
      findsOneWidget,
    );
    // A data importa: um recado sem data não se sabe se é de antes ou depois do
    // número que explica.
    expect(find.text('04/08/2026 às 16:30'), findsOneWidget);
  });

  testWidgets('ver o recado marca-o por lido, uma vez só', (tester) async {
    final servico = await montar(tester, [
      recado(id: 'm1'),
      recado(id: 'm2', texto: 'Faltam-me os extractos de 2023.'),
      recado(id: 'm3', texto: 'Já lido antes', lido: DateTime(2026, 8, 4)),
    ]);
    await tester.pumpAndSettle();

    expect(servico.marcados, ['m1', 'm2'], reason: 'só as que estavam por ler');

    // Reconstruir o ecrã não pode voltar a marcar: a data de leitura é de
    // quando se leu, não da última pintura.
    await tester.pump();
    await tester.pumpAndSettle();
    expect(servico.chamadasAMarcar, 1);
  });

  testWidgets('sem recados não há cartão nenhum', (tester) async {
    await montar(tester, const []);

    expect(find.text('Recados do contabilista'), findsNothing);
    expect(find.text('O contabilista deixou-lhe recado'), findsNothing);
    // E o resto do ecrã continua lá.
    expect(find.text('As perguntas'), findsOneWidget);
  });

  testWidgets('recados já lidos ficam, sem chamar a atenção', (tester) async {
    await montar(tester, [
      recado(texto: 'Isto já foi visto', lido: DateTime(2026, 8, 4, 18)),
    ]);

    expect(find.text('Recados do contabilista'), findsOneWidget);
    expect(find.text('O contabilista deixou-lhe recado'), findsNothing);
    expect(find.text('Isto já foi visto'), findsOneWidget);
  });

  testWidgets('uma falha a ler os recados não leva o ecrã à frente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(872.7, 392.7);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contabilistaServiceProvider.overrideWithValue(
            _ServicoFalso(const [], rebentaNasMensagens: true),
          ),
        ],
        child: MaterialApp(
          theme: PunhoTheme.light,
          home: const Scaffold(body: HistoricoContabilistaPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('As perguntas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ServicoFalso implements ContabilistaService {
  _ServicoFalso(this._recados, {this.rebentaNasMensagens = false});

  final List<MensagemContabilista> _recados;
  final bool rebentaNasMensagens;
  final marcados = <String>[];
  int chamadasAMarcar = 0;

  @override
  Future<List<MensagemContabilista>> mensagens() async {
    if (rebentaNasMensagens) throw StateError('sem rede');
    return _recados;
  }

  @override
  Future<void> marcarMensagensLidas(List<String> ids) async {
    chamadasAMarcar++;
    marcados.addAll(ids);
  }

  @override
  Future<List<RubricaContabilista>> catalogo() async => const [
    RubricaContabilista(
      chave: 'facturacao',
      rotulo: 'Faturação do mês',
      periodicidade: PeriodicidadeRubrica.mensal,
      tipo: 'euros',
      essencial: true,
      aceitaAnual: true,
    ),
  ];

  @override
  Future<List<ConviteContabilista>> convites() async => const [];

  @override
  Future<List<LacunaContabilista>> lacunas() async => const [];

  @override
  Future<List<RespostaContabilista>> respostasDe(String rubrica) async =>
      const [];

  @override
  Future<ConviteCriado> criarConvite({
    String? nome,
    String? email,
    int anos = 5,
  }) async => throw UnimplementedError();

  @override
  Future<void> revogarConvite(String conviteId) async {}

  @override
  Future<void> guardar({
    required String rubrica,
    DateTime? mes,
    int? ano,
    int? valorCentavos,
    String? valorTexto,
  }) async {}
}
