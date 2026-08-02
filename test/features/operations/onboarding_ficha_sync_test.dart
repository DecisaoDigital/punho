import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/empresa_sync_service.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O fim do onboarding é o único sítio que grava a ficha da empresa — e, até
/// hoje, o único que não a enviava ao servidor. Quem completava os 12 passos
/// via a empresa chegar ao Control sem NIF e sem nome, porque só uma visita
/// posterior a Definições (com "Guardar") disparava o envio.
///
/// Este ficheiro fixa: o envio passa a acontecer aqui, com os dados que
/// acabaram de ser escritos; nunca bloqueia o onboarding; e o colaborador —
/// que não preenche nada disto — não manda uma ficha em branco por cima da
/// real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sem `addTearDown` aqui de propósito: o `EmpresaSyncController` monta um
  // `Timer.periodic` de 20 em 20 minutos, e o `flutter_test` verifica que não
  // ficam temporizadores pendentes **antes** de correr os `addTearDown` — só
  // um `dispose()` explícito, no fim de cada teste, cancela a tempo. Ver
  // `core/empresa_sync/empresa_sync_controller.dart`.
  ProviderContainer container({
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    invocar,
  }) {
    SharedPreferences.setMockInitialValues({});
    return ProviderContainer(
      overrides: [
        operationRepositoryProvider.overrideWithValue(_RepoVazio()),
        empresaSyncProvider.overrideWithValue(EmpresaSyncService.mock(invocar)),
      ],
    );
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continuar(WidgetTester tester, {int vezes = 1}) async {
    for (var i = 0; i < vezes; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
  }

  /// Percorre o onboarding de gestor pelo caminho curto (switch OFF no passo
  /// 6), preenchendo identificação, NIF, morada, contactos e os números de
  /// equipa e frota — chega ao ecrã de boas-vindas sem passar pelos passos
  /// financeiros, que não interessam a este teste.
  Future<void> preencherComoGestor(WidgetTester tester) async {
    // Passo 0: nome do responsável.
    await tester.enterText(find.byType(TextField).first, 'César Mendes');
    await continuar(tester);
    // Passo 1: nome da empresa.
    await tester.enterText(find.byType(TextField).first, 'Mare Alta');
    await continuar(tester);
    // Passo 2: cargo — gestor por omissão.
    await continuar(tester);
    // Passo 3: forma jurídica (fica na omissão) + NIF.
    await tester.enterText(find.byType(TextField).first, '509442129');
    await continuar(tester);
    // Passo 4: morada, código-postal, localidade, telemóvel, email.
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Rua das Lavandarias, 10');
    await tester.enterText(campos.at(1), '4700-000');
    await tester.enterText(campos.at(2), 'Braga');
    await tester.enterText(campos.at(3), '912480315');
    await tester.enterText(campos.at(4), 'gestor@marealta.pt');
    await continuar(tester);
    // Passo 5: colaboradores e veículos, com os botões "+". Cada toque tem de
    // ser seguido de um `pump()`: o `onPressed` captura `value` no fecho do
    // `_NumberChoice` da altura, e sem redesenhar entre toques os dois
    // primeiros toques usavam o mesmo `value` antigo e o número não subia.
    final mais = find.byIcon(Icons.add_circle_outline);
    await tester.tap(mais.at(0)); // 1 colaborador
    await tester.pump();
    await tester.tap(mais.at(0)); // 2 colaboradores
    await tester.pump();
    await tester.tap(mais.at(1)); // 1 veículo
    await tester.pumpAndSettle();
    await continuar(tester);
    // Passo 6: switch — OFF entra directo no ecrã de boas-vindas.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await continuar(tester);

    await tester.tap(find.text('Entrar na Punho →'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'o fim do onboarding envia NIF, nome, morada e os números declarados',
    (tester) async {
      final chamadas = <Map<String, dynamic>>[];
      final c = container(
        invocar: (args) async {
          chamadas.add(Map<String, dynamic>.from(args['dados'] as Map));
          return {'ok': true};
        },
      );
      await abrir(tester, c);

      await preencherComoGestor(tester);

      expect(
        chamadas,
        isNotEmpty,
        reason: 'o onboarding devia ter disparado o envio da ficha',
      );
      final enviado = chamadas.last;
      expect(enviado['nif'], '509442129');
      expect(enviado['nome_comercial'], 'Mare Alta');
      expect(enviado['nome_gestor'], 'César Mendes');
      expect(enviado['morada'], 'Rua das Lavandarias, 10');
      expect(enviado['codigo_postal'], '4700-000');
      expect(enviado['localidade'], 'Braga');
      expect(enviado['telefone'], '912480315');
      expect(enviado['email'], 'gestor@marealta.pt');
      expect(enviado['n_colaboradores'], 2);
      expect(enviado['n_veiculos'], 1);
      // Confirma que o onboarding em si também gravou os mesmos dados: o
      // envio não é uma cópia paralela desalinhada do que ficou gravado.
      final estado = c.read(operationsProvider);
      expect(estado.companyTaxId, '509442129');
      expect(estado.companyName, 'Mare Alta');
      c.dispose();
    },
  );

  testWidgets(
    'o onboarding conclui mesmo quando o envio ao servidor falha',
    (tester) async {
      final c = container(invocar: (_) async => {'ok': false});
      await abrir(tester, c);

      await preencherComoGestor(tester);

      expect(
        c.read(operationsProvider).onboarded,
        isTrue,
        reason: 'uma EF a falhar não pode prender o onboarding',
      );
      c.dispose();
    },
  );

  testWidgets(
    'o onboarding conclui mesmo quando a chamada à EF rebenta',
    (tester) async {
      final c = container(
        invocar: (_) async => throw Exception('sem rede'),
      );
      await abrir(tester, c);

      await preencherComoGestor(tester);

      expect(c.read(operationsProvider).onboarded, isTrue);
      c.dispose();
    },
  );

  testWidgets('o colaborador não manda uma ficha em branco', (tester) async {
    final chamadas = <Map<String, dynamic>>[];
    final c = container(
      invocar: (args) async {
        chamadas.add(Map<String, dynamic>.from(args['dados'] as Map));
        return {'ok': true};
      },
    );
    await abrir(tester, c);

    // Passo 0: nome.
    await tester.enterText(find.byType(TextField).first, 'Jorge');
    await continuar(tester);
    // Passo 1: nome da empresa.
    await tester.enterText(find.byType(TextField).first, 'Mare Alta');
    await continuar(tester);
    // Passo 2: cargo — muda para colaborador.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colaborador').last);
    await tester.pumpAndSettle();
    await continuar(tester);
    // Passo 3 do colaborador: contacto telefónico pessoal.
    await tester.enterText(find.byType(TextField).first, '910000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Começar'));
    await tester.pumpAndSettle();

    expect(c.read(operationsProvider).onboarded, isTrue);
    expect(
      chamadas,
      isEmpty,
      reason:
          'o colaborador não preenche NIF/morada/números da empresa — '
          'mandar isto apagava a ficha real de quem já a tinha preenchido',
    );
    // Sem envio, o `EmpresaSyncController` nunca chegou a montar-se — não há
    // temporizador nenhum por cancelar, mas `dispose()` na mesma para não
    // deixar o container aberto.
    c.dispose();
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
