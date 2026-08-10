import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// **O teclado é do campo, não do ecrã anterior.**
///
/// O César, no Redmi, a 10 de Agosto de 2026: «morada da empresa tem teclado de
/// numeração telemóvel… não pode».
///
/// O assistente mostra um passo de cada vez, e o passo do contacto e o da morada
/// são ambos uma `Column` com um `TextField` em primeiro lugar. Sem chave que os
/// distinga, o Flutter **reaproveita o mesmo elemento**: o campo muda de
/// controlador e de rótulo, mas a ligação ao teclado do sistema é a mesma que
/// estava aberta — e essa foi criada com `TextInputType.phone`. O resultado é
/// um teclado numérico para escrever «Rua de Santo António».
///
/// Não se vê em nenhum teste que olhe para widgets: o widget está certo, é
/// `TextField` sem `keyboardType`. O que está errado é o que a app **disse à
/// plataforma**, e é por isso que este teste escuta o canal `TextInput`.
void main() {
  /// O tipo de teclado que a plataforma tem aberto neste momento, tal como a
  /// app lho pediu. `null` quando não há nenhum.
  String? tecladoAberto(List<MethodCall> chamadas) {
    String? tipo;
    for (final c in chamadas) {
      switch (c.method) {
        case 'TextInput.setClient':
          final config = (c.arguments as List<dynamic>)[1] as Map<Object?, Object?>;
          final tipoDoCampo = config['inputType'] as Map<Object?, Object?>;
          tipo = tipoDoCampo['name'] as String?;
        case 'TextInput.clearClient':
          tipo = null;
      }
    }
    return tipo;
  }

  Future<List<MethodCall>> escutarOTeclado(WidgetTester tester) async {
    final chamadas = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (chamada) async {
        chamadas.add(chamada);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );
    return chamadas;
  }

  Future<void> continuar(WidgetTester tester, {int vezes = 1}) async {
    for (var i = 0; i < vezes; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a morada da empresa não herda o teclado do telemóvel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [operationRepositoryProvider.overrideWithValue(_RepoVazio())],
    );
    addTearDown(container.dispose);

    final chamadas = await escutarOTeclado(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Até ao contacto: nome, empresa, cargo, forma jurídica + NIF,
    // funcionários, veículos.
    await continuar(tester, vezes: 3);
    await tester.enterText(find.byType(TextField).last, '509442129');
    await continuar(tester, vezes: 3);
    expect(find.text('Telemóvel ou telefone'), findsOneWidget);
    // O campo do telemóvel abre com `autofocus`, e é aqui que o teclado
    // numérico entra em cena — legitimamente.
    expect(tecladoAberto(chamadas), 'TextInputType.phone');

    await continuar(tester);
    expect(find.text('Morada da empresa'), findsOneWidget);

    expect(
      tecladoAberto(chamadas),
      isNot('TextInputType.phone'),
      reason: 'a morada ficou com o teclado que o telemóvel deixou aberto',
    );
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
