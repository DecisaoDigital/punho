import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/empresa_sync_service.dart';
import 'package:punho/core/empresa_sync/ficha_da_empresa.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

/// O ecrã, e não só o provider.
///
/// Os testes do provider já provavam que a ficha era lida e aplicada. Faltava
/// o que o Cesar viu: abrir a app e mesmo assim ser recebido pelo onboarding.
/// Entre o provider e o ecrã há um `watch` dentro de um `if` — e é isso que
/// aqui se verifica, com o `AppShell` a sério.
void main() {
  Future<void> abrirApp(
    WidgetTester tester, {
    required Map<String, dynamic>? noServidor,
  }) async {
    tester.view.physicalSize = const Size(838.9, 392.7);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationRepositoryProvider.overrideWithValue(
            LocalDemoOperationRepository(),
          ),
          empresaSyncProvider.overrideWithValue(_Servico(noServidor)),
        ],
        child: MaterialApp(theme: PunhoTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('com a empresa no servidor, não se pergunta nada', (
    tester,
  ) async {
    await abrirApp(
      tester,
      noServidor: {
        'nome_comercial': 'Terraforte — Aluguer de Equipamentos',
        'nome_gestor': 'César Mendes',
        'nif': '514287934',
        'n_colaboradores': 4,
        'n_veiculos': 2,
        'n_maquinas': 7,
      },
    );

    // O sintoma exacto que ele descreveu: «tive de colocar nome, contribuinte e
    // morada só para entrar».
    expect(
      find.text('Como te chamas?'),
      findsNothing,
      reason: 'a empresa estava no servidor e mesmo assim perguntou',
    );
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('sem nada no servidor, o onboarding aparece como sempre', (
    tester,
  ) async {
    await abrirApp(tester, noServidor: null);

    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}

class _Servico implements EmpresaSyncService {
  _Servico(this.dados);
  final Map<String, dynamic>? dados;

  @override
  Future<FichaDaEmpresa?> buscarFicha() async {
    if (dados == null) return null;
    final ficha = FichaDaEmpresa.doServidor(dados!);
    return ficha.temOEssencial ? ficha : null;
  }

  @override
  Future<ResultadoDaFicha> sincronizar(Map<String, dynamic> dados) async =>
      const ResultadoDaFicha.entregue();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
