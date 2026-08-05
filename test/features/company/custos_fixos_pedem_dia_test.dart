import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/features/company/presentation/company_settings_page.dart';

/// **O quadro dos custos fixos tem de pedir a data.**
///
/// «então o quadro dos custos fixos tem de começar a perguntar datas» — Cesar,
/// 5/8/2026, depois de ver a Caixa sem a renda lá dentro.
///
/// O campo *Dia* já existia — uma caixa estreita no fim da linha, com um
/// rótulo que não diz o que se perde por a deixar em branco. Sem dia, a rubrica
/// não chega à Caixa: sem data não há como saber se já saiu da conta, e
/// inventar o dia 1 punha o mês inteiro a pesar logo no primeiro dia. Quem a
/// deixou vazia foi ver a Caixa e não encontrou lá a renda — e não tinha como
/// perceber porquê.
void main() {
  Future<void> abrir(WidgetTester tester, List<CustoFixo> rubricas) async {
    // Alta de propósito: a página é uma lista e o cartão dos custos fixos
    // fica abaixo da dobra — fora do ecrã o Flutter nem o constrói.
    tester.view.physicalSize = const Size(1280, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = LocalDemoOperationRepository();
    // Sem onboarding gravado a página não tem empresa nenhuma para editar.
    repo.saveOnboarding(
      const OnboardingData(
        ownerName: 'Cesar',
        companyName: 'Alugueres Norte',
        legalForm: 'Lda.',
        hasFleet: false,
        collaborators: 1,
        declaredVehicleCount: 0,
        totalMachinesDeclared: 1,
        insertMachinesNow: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(operationsProvider.notifier).updateCompanySettings(
      custosFixos: rubricas,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CompanySettingsPage(embutida: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  CustoFixo rubrica(String id, {int? dia}) => CustoFixo(
    id: id,
    categoria: ExpenseCategory.rent,
    valorCents: 120000,
    diaDoMes: dia,
  );

  final aviso = find.textContaining('não entra na Caixa');
  final avisoPlural = find.textContaining('não entram na Caixa');

  testWidgets('uma rubrica sem dia é assinalada, e diz-se o que se perde', (
    tester,
  ) async {
    await abrir(tester, [rubrica('a')]);

    expect(aviso, findsOneWidget);
  });

  testWidgets('com o dia preenchido não há aviso nenhum', (tester) async {
    // Quem já respondeu não leva um aviso por cima da resposta.
    await abrir(tester, [rubrica('a', dia: 4)]);

    expect(aviso, findsNothing);
    expect(avisoPlural, findsNothing);
  });

  testWidgets('duas em falta contam-se, e o aviso fala no plural', (
    tester,
  ) async {
    await abrir(tester, [rubrica('a'), rubrica('b'), rubrica('c', dia: 10)]);

    expect(avisoPlural, findsOneWidget);
    expect(find.textContaining('2 rubricas'), findsOneWidget);
  });

  testWidgets('o campo do dia continua lá para ser preenchido', (tester) async {
    await abrir(tester, [rubrica('a')]);

    expect(find.widgetWithText(TextFormField, 'Dia'), findsOneWidget);
  });
}
