import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/features/company/presentation/company_settings_page.dart';

/// **Um valor ilegível recusa-se; nunca vira zero.**
///
/// O campo `€ / mês` das rubricas fazia `centsDeTexto(valor) ?? 0`. Quem
/// escrevesse "1.500.00" — dois pontos, como sai de uma folha de cálculo
/// inglesa — ou qualquer letra, ficava com uma rubrica de **0 €**, sem uma
/// palavra no ecrã. E um custo fixo não fica ali parado: alimenta a cadeia de
/// tesouraria inteira, por isso o gestor via a conta dele mudar e não tinha
/// como perceber porquê.
///
/// O ecrã das Finanças já recusava com mensagem desde sempre. Era a mesma
/// pergunta com duas respostas diferentes conforme o ecrã onde se estava.
void main() {
  Future<ProviderContainer> abrir(
    WidgetTester tester,
    List<CustoFixo> rubricas,
  ) async {
    // Alta de propósito: o cartão dos custos fixos fica abaixo da dobra, e
    // fora do ecrã o Flutter nem o constrói.
    tester.view.physicalSize = const Size(1280, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = LocalDemoOperationRepository();
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
      // Sem NIF válido o `_guardar` sai logo no primeiro `if` e nunca chegava
      // à verificação dos custos — o teste passaria por outra razão.
      companyTaxId: const Campo('501442600'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // `embutida` não traz Scaffold — na app real vem o do shell à volta.
        // Sem um aqui, o `showSnackBar` rebenta e o teste falhava por uma
        // razão que não é a que quer provar.
        child: const MaterialApp(
          home: Scaffold(body: CompanySettingsPage(embutida: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  CustoFixo renda(int cents) => CustoFixo(
    id: 'cf-renda',
    categoria: ExpenseCategory.rent,
    valorCents: cents,
    diaDoMes: 8,
  );

  List<CustoFixo> rubricasDe(ProviderContainer c) =>
      c.read(operationsProvider).custosFixos;

  Finder campoDeValor() => find.widgetWithText(TextFormField, '€ / mês');

  Future<void> guardar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets('"1.500.00" não vira 0 € — recusa com mensagem', (tester) async {
    await abrir(tester, [renda(150000)]);

    await tester.enterText(campoDeValor(), '1.500.00');
    await tester.pumpAndSettle();

    // O que o gestor vê: a explicação, com o texto que escreveu lá dentro.
    expect(
      find.textContaining('Não consigo ler o valor "1.500.00"'),
      findsOneWidget,
    );
  });

  testWidgets('letras também recusam', (tester) async {
    await abrir(tester, [renda(150000)]);

    await tester.enterText(campoDeValor(), 'não sei');
    await tester.pumpAndSettle();

    expect(find.textContaining('Não consigo ler o valor'), findsOneWidget);
  });

  testWidgets('campo vazio pede um valor, em vez de assumir zero', (
    tester,
  ) async {
    await abrir(tester, [renda(150000)]);

    await tester.enterText(campoDeValor(), '');
    await tester.pumpAndSettle();

    expect(find.text('Indica um valor superior a zero.'), findsOneWidget);
  });

  testWidgets('um valor legível limpa o aviso e é o que fica gravado', (
    tester,
  ) async {
    final container = await abrir(tester, [renda(150000)]);

    await tester.enterText(campoDeValor(), 'xpto');
    await tester.pumpAndSettle();
    expect(find.textContaining('Não consigo ler'), findsOneWidget);

    // "1.200,00" — vírgula decimal, ponto de milhares. É como se escreve cá.
    await tester.enterText(campoDeValor(), '1.200,00');
    await tester.pumpAndSettle();
    expect(find.textContaining('Não consigo ler'), findsNothing);

    await guardar(tester);
    expect(rubricasDe(container).single.valorCents, 120000);
  });

  testWidgets('com um valor por corrigir, o Guardar recusa e não grava', (
    tester,
  ) async {
    final container = await abrir(tester, [renda(150000)]);

    await tester.enterText(campoDeValor(), '1.500.00');
    await tester.pumpAndSettle();

    await guardar(tester);

    // Gravar aqui guardaria o valor anterior sem o dizer — a mesma mentira do
    // `?? 0`, só mais discreta.
    expect(
      find.text('Há custos fixos com valores por corrigir. Nada foi guardado.'),
      findsOneWidget,
    );
    expect(find.text('Dados da empresa guardados.'), findsNothing);
    expect(rubricasDe(container).single.valorCents, 150000);
  });
}
