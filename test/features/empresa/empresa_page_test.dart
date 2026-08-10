import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/company/presentation/company_settings_page.dart';
import 'package:punho/features/empresa/presentation/empresa_page.dart';
import 'package:punho/features/sync/sync_providers.dart';
import 'package:punho/core/navigation/app_destination.dart';

/// **O ecrã Empresa.** Duas queixas do César a 10 de Agosto de 2026, e as duas
/// sobre a mesma coisa: o ecrã dava trabalho para não fazer nada.
///
///   «custos fixos remete para Dados… não pode»
///   «visualmente é muita informação, não tem fluxo de trabalho e visual»
///   «Dados deve mostrar os dados referentes à empresa; se for para editar é
///    outra situação»
///
/// O que estes testes guardam: **Dados lê-se**, não se preenche; **Custos
/// fixos edita-se onde está**, sem mandar ninguém para outro lado.
void main() {
  ProviderContainer container({
    String nome = 'Lavandaria Nocturna',
    String? nif = '509442129',
    String formaJuridica = 'Sociedade por quotas',
    List<CustoFixo> custosFixos = const [],
    List<Booking> reservas = const [],
    List<OperacaoRecusada> conflitos = const [],
  }) {
    final repo = LocalDemoOperationRepository()
      ..saveOnboarding(
        OnboardingData(
          companyName: nome,
          legalForm: formaJuridica,
          ownerName: 'César Mendes',
          companyTaxId: nif,
          companyAddress: 'Rua das Garrafinhas, 4',
          companyPostalCode: '2456',
          companyLocality: 'Nazaré',
          hasFleet: true,
          collaborators: 2,
          declaredVehicleCount: 1,
          totalMachinesDeclared: 6,
          insertMachinesNow: false,
          custosFixos: custosFixos,
        ),
      );
    for (final reserva in reservas) {
      repo.saveBooking(reserva);
    }
    return ProviderContainer(
      // A sessão de demonstração já nasce como gestor, que é quem pode ver e
      // alterar a ficha da empresa.
      overrides: [
        operationRepositoryProvider.overrideWithValue(repo),
        // Sem Supabase configurado o motor de sync é nulo e o balde vem sempre
        // vazio; para ver o cartão, entrega-se a lista à mão.
        if (conflitos.isNotEmpty)
          conflitosDeReservaProvider.overrideWith((ref) async => conflitos),
      ],
    );
  }

  Future<void> abrir(
    WidgetTester tester,
    ProviderContainer c, {
    AbaDaEmpresa aba = AbaDaEmpresa.dados,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: EmpresaPage(abaInicial: aba)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Dados — o retrato', () {
    testWidgets('mostra os valores, e não caixas para os escrever', (
      tester,
    ) async {
      await abrir(tester, container());

      expect(find.text('Lavandaria Nocturna'), findsOneWidget);
      expect(find.text('509442129'), findsOneWidget);
      expect(find.text('César Mendes'), findsOneWidget);
      expect(
        find.textContaining('Rua das Garrafinhas'),
        findsOneWidget,
        reason: 'a morada lê-se numa linha, não em três campos',
      );

      // Era isto o «muita informação»: a aba abria com o formulário inteiro,
      // cinco cartões e vinte campos de texto.
      expect(
        find.byType(EditableText),
        findsNothing,
        reason: 'Dados é para ler — editar é outro ecrã',
      );
    });

    /// Esconder o que falta faria a ficha parecer completa, e é justamente o
    /// que falta que se quer ver antes de carregar em Editar.
    testWidgets('o que está por preencher diz que está', (tester) async {
      await abrir(tester, container(nif: null));

      expect(find.text('Por indicar'), findsWidgets);
    });

    testWidgets('editar é um gesto à parte, e abre o formulário', (
      tester,
    ) async {
      await abrir(tester, container());

      await tester.tap(find.text('Editar dados da empresa'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanySettingsPage), findsOneWidget);
      expect(find.text('Dados da empresa'), findsOneWidget);
      expect(find.byType(EditableText), findsWidgets);
    });
  });

  group('Custos fixos — editam-se onde estão', () {
    testWidgets('não manda ninguém para Dados', (tester) async {
      await abrir(tester, container(), aba: AbaDaEmpresa.custosFixos);

      expect(
        find.textContaining('Editar por rubrica em Dados'),
        findsNothing,
        reason: 'era o único botão da aba, e não fazia nada de útil',
      );
      expect(find.text('Acrescentar rubrica'), findsOneWidget);
    });

    testWidgets('acrescentar e guardar uma rubrica grava mesmo', (
      tester,
    ) async {
      final c = container();
      await abrir(tester, c, aba: AbaDaEmpresa.custosFixos);

      await tester.tap(find.text('Acrescentar rubrica'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '€ / mês').first,
        '450',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar custos fixos'));
      await tester.pumpAndSettle();

      final gravadas = c.read(operationsProvider).custosFixos;
      expect(gravadas, hasLength(1));
      expect(gravadas.single.valorCents, 45000);
      expect(c.read(operationsProvider).custoFixoMensalCents, 45000);
    });

    /// O botão só acende quando há mudança por gravar — e diz-o.
    testWidgets('sem mudanças, o Guardar está apagado', (tester) async {
      await abrir(
        tester,
        container(
          custosFixos: const [
            CustoFixo(
              id: 'cf1',
              categoria: ExpenseCategory.rent,
              valorCents: 60000,
              diaDoMes: 4,
            ),
          ],
        ),
        aba: AbaDaEmpresa.custosFixos,
      );

      final botao = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar custos fixos'),
      );
      expect(botao.onPressed, isNull);
      expect(find.text('Por guardar'), findsNothing);
      // E o total do que já lá está aparece em cima.
      expect(find.text('600,00 €'), findsOneWidget);
    });
  });

  /// A regra do César, em memória desde o início: nada a fingir no ecrã.
  testWidgets('o ecrã não anuncia coisas que não existem', (tester) async {
    await abrir(tester, container(), aba: AbaDaEmpresa.estado);

    expect(find.textContaining('em preparação'), findsNothing);
  });

  /// **Regime** — tinha o mesmo defeito que os custos fixos: uma aba cujo
  /// único botão era «Editar em Dados →».
  group('Regime — muda-se aqui', () {
    Future<void> escolher(WidgetTester tester, String forma) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(forma).last);
      await tester.pumpAndSettle();
    }

    testWidgets('não manda ninguém para Dados', (tester) async {
      await abrir(tester, container(), aba: AbaDaEmpresa.regime);

      expect(find.textContaining('Editar em Dados'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('sem mudança, o Guardar está apagado', (tester) async {
      await abrir(tester, container(), aba: AbaDaEmpresa.regime);

      final botao = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar forma jurídica'),
      );
      expect(botao.onPressed, isNull);
      expect(find.text('Por guardar'), findsNothing);
    });

    /// Mudar de regime muda o significado de metade dos KPIs financeiros. É
    /// para isso que serve a confirmação — e é ela que justifica o selector
    /// poder estar aqui, à mão, em vez de escondido nos Dados.
    testWidgets('mudar de regime avisa antes, e só grava depois de sim', (
      tester,
    ) async {
      final c = container(formaJuridica: 'Empresário em Nome Individual');
      await abrir(tester, c, aba: AbaDaEmpresa.regime);
      expect(find.text('ENI — regime simplificado'), findsOneWidget);

      await escolher(tester, 'Lda.');
      expect(find.text('Passa a Lda. — IRC.'), findsOneWidget);

      await tester.tap(find.text('Guardar forma jurídica'));
      await tester.pumpAndSettle();
      expect(find.text('Mudar de regime?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Mudar de regime'));
      await tester.pumpAndSettle();

      expect(c.read(operationsProvider).legalForm, 'Lda.');
      expect(find.text('Lda. — IRC'), findsWidgets);
    });

    testWidgets('cancelar o aviso não muda nada', (tester) async {
      final c = container(formaJuridica: 'Empresário em Nome Individual');
      await abrir(tester, c, aba: AbaDaEmpresa.regime);

      await escolher(tester, 'Lda.');
      await tester.tap(find.text('Guardar forma jurídica'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(
        c.read(operationsProvider).legalForm,
        'Empresário em Nome Individual',
      );
    });
  });

  /// **Conflitos** — o cartão prometia «resolve-as aqui (remarcar ou recusar)»
  /// e não tinha botão nenhum; dizia «Marcação b1786396745111605», o id em
  /// bruto. Duas queixas num cartão só, apanhadas pelo César a 10 de Agosto de
  /// 2026.
  group('Estado — o cartão de conflito', () {
    final reserva = Booking(
      id: 'b-conflito',
      customerId: 'c1',
      machineIds: const ['m1'],
      startsAt: DateTime(2026, 8, 12),
      endsAt: DateTime(2026, 8, 14),
      status: BookingStatus.confirmed,
      customerNameSnapshot: 'Construções Silva',
    );

    OperacaoRecusada conflitoDe(String bookingId) => OperacaoRecusada(
      operacao: OperacaoPendente(
        id: 'op-1',
        entidade: 'booking',
        entidadeId: bookingId,
        payload: const {},
        feitoEm: DateTime(2026, 8, 10),
      ),
      motivo: '23P01: sobreposição',
      codigo: '23P01',
      recusadaEm: DateTime(2026, 8, 10),
    );

    Future<ProviderContainer> abrirComConflito(WidgetTester tester) async {
      final c = container(
        reservas: [reserva],
        conflitos: [conflitoDe('b-conflito')],
      );
      await abrir(tester, c, aba: AbaDaEmpresa.estado);
      return c;
    }

    testWidgets('diz de quem é e de quando, não o id da marcação', (
      tester,
    ) async {
      await abrirComConflito(tester);

      expect(find.textContaining('b-conflito'), findsNothing);
      expect(find.textContaining('Mini escavadora 1.8T'), findsOneWidget);
      expect(find.textContaining('12/08 a 13/08'), findsOneWidget);
      expect(find.textContaining('Construções Silva'), findsOneWidget);
    });

    testWidgets('remarcar muda o dia da marcação', (tester) async {
      final c = await abrirComConflito(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Remarcar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final depois = c
          .read(operationsProvider)
          .bookings
          .firstWhere((b) => b.id == 'b-conflito');
      expect(depois.startsAt, DateTime(2026, 8, 19));
      // Dois dias continuam dois dias.
      expect(depois.endsAt, DateTime(2026, 8, 21));
    });

    testWidgets('recusar cancela — depois de perguntar', (tester) async {
      final c = await abrirComConflito(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Recusar'));
      await tester.pumpAndSettle();
      expect(find.text('Recusar a marcação?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Recusar'));
      await tester.pumpAndSettle();

      expect(
        c
            .read(operationsProvider)
            .bookings
            .firstWhere((b) => b.id == 'b-conflito')
            .status,
        BookingStatus.cancelled,
      );
    });

    testWidgets('voltar atrás não cancela nada', (tester) async {
      final c = await abrirComConflito(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Recusar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Voltar atrás'));
      await tester.pumpAndSettle();

      expect(
        c
            .read(operationsProvider)
            .bookings
            .firstWhere((b) => b.id == 'b-conflito')
            .status,
        BookingStatus.confirmed,
      );
    });

    /// Um conflito de uma marcação que já cá não está não pode oferecer
    /// «Remarcar» — não há o que remarcar. Diz-se, e a saída é tirá-lo da
    /// lista.
    testWidgets('marcação que já não existe só se tira da lista', (
      tester,
    ) async {
      await abrir(
        tester,
        container(conflitos: [conflitoDe('b-que-ja-nao-ha')]),
        aba: AbaDaEmpresa.estado,
      );

      expect(find.text('Remarcar'), findsNothing);
      expect(find.text('Tirar da lista'), findsOneWidget);
      expect(
        find.textContaining('já não está neste telemóvel'),
        findsOneWidget,
      );
    });
  });
}
