import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/company/presentation/company_settings_page.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';

/// Empresa já configurada, como fica depois do onboarding.
const _empresa = OnboardingData(
  ownerName: 'Cesar Mendes',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  hasFleet: true,
  collaborators: 2,
  declaredVehicleCount: 3,
  totalMachinesDeclared: 5,
  insertMachinesNow: false,
  companyTaxId: '501234567',
  companyPhone: '912 000 000',
  companyEmail: 'geral@alugueresnorte.pt',
  companyAddress: 'Rua das Máquinas 10',
  companyPostalCode: '4700-000',
  companyLocality: 'Braga',
  revenueLastYearCents: 12500000,
  revenueThisYearCents: 4300000,
  maintenanceLastYearCents: 850000,
  fixedMonthlyCostsCents: 320000,
);

ProviderContainer _container({OnboardingData? empresa = _empresa}) {
  final repo = LocalDemoOperationRepository();
  if (empresa != null) repo.saveOnboarding(empresa);
  final container = ProviderContainer(
    overrides: [operationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// O formulário tem 15 campos numa `ListView`, que só constrói o que cabe no
/// ecrã. Com a janela de teste normal (800x600) metade dos campos não existe na
/// árvore e nem `ensureVisible` os encontra — daí a janela alta.
void _janelaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ProviderContainer> _montarDefinicoes(WidgetTester tester) async {
  _janelaAlta(tester);
  final container = _container();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CompanySettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Texto actualmente dentro do campo com este rótulo.
String _valorDoCampo(WidgetTester tester, String etiqueta) {
  final campo = tester.widget<TextField>(
    find.ancestor(
      of: find.text(etiqueta),
      matching: find.byType(TextField),
    ),
  );
  return campo.controller!.text;
}

Future<void> _escrever(
  WidgetTester tester,
  String etiqueta,
  String valor,
) async {
  final campo = find.ancestor(
    of: find.text(etiqueta),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(campo);
  await tester.enterText(campo, valor);
  await tester.pump();
}

void main() {
  group('Definições da empresa', () {
    testWidgets('mostra os valores que o utilizador introduziu', (tester) async {
      await _montarDefinicoes(tester);

      // O problema original: isto entrava no onboarding e não voltava a
      // aparecer em lado nenhum.
      expect(_valorDoCampo(tester, 'Nome do responsável'), 'Cesar Mendes');
      expect(_valorDoCampo(tester, 'Nome da empresa / nome comercial'), 'Alugueres Norte');
      expect(_valorDoCampo(tester, 'NIF da empresa'), '501234567');
      expect(_valorDoCampo(tester, 'Telemóvel'), '912 000 000');
      expect(_valorDoCampo(tester, 'Localidade'), 'Braga');
      expect(_valorDoCampo(tester, 'Colaboradores'), '2');
      expect(_valorDoCampo(tester, 'Veículos'), '3');
      expect(
        _valorDoCampo(tester, 'Facturação do ano passado (€)'),
        '125000,00',
      );
      expect(_valorDoCampo(tester, 'Custos fixos mensais (€)'), '3200,00');
      expect(find.text('Lda.'), findsWidgets);
    });

    testWidgets('guardar escreve o valor novo no state e no repositório', (
      tester,
    ) async {
      final container = await _montarDefinicoes(tester);

      await _escrever(tester, 'Nome da empresa / nome comercial', 'Alugueres Norte II');
      await _escrever(tester, 'Localidade', 'Guimarães');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final estado = container.read(operationsProvider);
      expect(estado.companyName, 'Alugueres Norte II');
      expect(estado.companyLocality, 'Guimarães');
      // Não tocado continua igual.
      expect(estado.companyTaxId, '501234567');
      // E ficou gravado, não só no state.
      final repo = container.read(operationRepositoryProvider);
      expect(repo.onboarding?.companyName, 'Alugueres Norte II');
      expect(repo.onboarding?.companyLocality, 'Guimarães');
    });

    testWidgets('cancelar não grava nada', (tester) async {
      _janelaAlta(tester);
      final container = _container();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompanySettingsPage(),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await _escrever(tester, 'Nome da empresa / nome comercial', 'Nome descartado');
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanySettingsPage), findsNothing);
      expect(container.read(operationsProvider).companyName, 'Alugueres Norte');
    });

    testWidgets('limpar o NIF apaga-o de verdade', (tester) async {
      // Regra 4: tem de ser possível limpar. Com `copyWith(x ?? this.x)` era
      // impossível — o campo voltava sempre ao valor antigo.
      final container = await _montarDefinicoes(tester);

      await _escrever(tester, 'NIF da empresa', '');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(container.read(operationsProvider).companyTaxId, isNull);
      expect(
        container.read(operationRepositoryProvider).onboarding?.companyTaxId,
        isNull,
      );
    });

    testWidgets('veículos a zero desliga a frota', (tester) async {
      final container = await _montarDefinicoes(tester);

      await _escrever(tester, 'Veículos', '0');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(container.read(operationsProvider).hasFleet, isFalse);
      expect(container.read(operationsProvider).declaredVehicleCount, 0);
    });

    testWidgets('repor dados apaga tudo e volta ao arranque', (tester) async {
      final container = await _montarDefinicoes(tester);

      await tester.ensureVisible(find.text('Repor dados desta app'));
      await tester.tap(find.text('Repor dados desta app'));
      await tester.pumpAndSettle();
      expect(find.text('Repor dados desta app?'), findsOneWidget);
      // Dentro do diálogo: "Repor" também é o título da secção no formulário.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Repor'),
        ),
      );
      await tester.pumpAndSettle();

      final estado = container.read(operationsProvider);
      expect(estado.onboarded, isFalse);
      expect(estado.companyName, '');
      expect(estado.machines, isEmpty);
      expect(estado.customers, isEmpty);
      expect(container.read(operationRepositoryProvider).onboarding, isNull);
    });
  });

  group('Acesso ao ecrã', () {
    testWidgets('o painel de gestão tem o botão e ele abre as definições', (
      tester,
    ) async {
      final container = _container();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DashboardPage())),
        ),
      );
      await tester.pumpAndSettle();

      final botao = find.byTooltip('Editar dados da empresa');
      expect(botao, findsOneWidget);

      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(find.byType(CompanySettingsPage), findsOneWidget);
      expect(find.text('Dados da empresa'), findsOneWidget);
    });
  });
}
