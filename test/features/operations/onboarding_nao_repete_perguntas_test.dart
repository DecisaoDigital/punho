import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// **Uma pergunta já respondida não se volta a fazer.**
///
/// O pedido de acesso pergunta o nome e a empresa, e o Control aprova o cargo.
/// Aprovado como Alfredo / DepilConcept / Gestor, o Punho abria na mesma em
/// «Como te chamas?» e contava o percurso inteiro.
///
/// «quando eu fiz log in já foi pedido isto, se já foi perguntado e já
/// respondi, não tem de me fazer mais estas perguntas» — César, 5/8/2026.
///
/// Trazer o campo pré-preenchido não chegava: a pergunta continuava lá. Os três
/// passos saem do percurso, as respostas ficam guardadas, e o que falta —
/// NIF, morada, equipa, números — continua a ser perguntado.
void main() {
  ProviderContainer comAcesso(EstadoAcesso? acesso) {
    final container = ProviderContainer(
      overrides: [
        operationRepositoryProvider.overrideWithValue(_RepoVazio()),
        if (acesso != null)
          estadoAcessoProvider.overrideWith((ref) async => acesso),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // O `initState` lê o acesso já resolvido — é o que acontece na app, onde
    // quem decide mostrar isto é o `AcessoGate`, depois de o ter perguntado.
    await container
        .read(estadoAcessoProvider.future)
        .catchError((_) => const EstadoAcesso(membroAtivo: false));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  const aprovado = EstadoAcesso(
    membroAtivo: true,
    perfil: 'gestor',
    estado: 'aprovado',
    nome: 'Alfredo',
    empresaNome: 'DepilConcept',
  );

  /// Passa o ecrã de boas-vindas, que é o primeiro de quem foi aprovado.
  Future<void> passarOBemVindo(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Vamos a isto'));
    await tester.pumpAndSettle();
  }

  testWidgets('quem foi aprovado é recebido pelo nome', (tester) async {
    // «gostaria de ver um "bem-vindo!" e pequena explicação do que é o Punho»
    // — César, 5/8/2026. Entrava directo em «Forma jurídica e NIF da empresa».
    await abrir(tester, comAcesso(aprovado));

    expect(find.text('Bem-vindo, Alfredo.'), findsOneWidget);
    expect(find.textContaining('sala de controlo'), findsOneWidget);
  });

  testWidgets('em demonstração não há boas-vindas — não houve aprovação', (
    tester,
  ) async {
    await abrir(tester, comAcesso(null));

    expect(find.textContaining('Bem-vindo,'), findsNothing);
  });

  testWidgets('aprovado, não pergunta nome, empresa nem cargo', (tester) async {
    // O cargo também não: «lembra-te também que eu já disse ser gestor».
    await abrir(tester, comAcesso(aprovado));
    await passarOBemVindo(tester);

    expect(find.text('Como te chamas?'), findsNothing);
    expect(find.text('Como se chama a empresa?'), findsNothing);
    expect(find.text('Qual é o teu cargo?'), findsNothing);
  });

  testWidgets('abre no primeiro passo que ainda é pergunta', (tester) async {
    await abrir(tester, comAcesso(aprovado));
    await passarOBemVindo(tester);

    expect(find.text('Forma jurídica e NIF da empresa'), findsOneWidget);
  });

  testWidgets('o contador conta os que restam, não os originais', (
    tester,
  ) async {
    // "4 de 14" seria mentira nos dois números.
    await abrir(tester, comAcesso(aprovado));
    await passarOBemVindo(tester);

    expect(find.text('1 de 11'), findsOneWidget);
    expect(find.textContaining('de 14'), findsNothing);
  });

  testWidgets('sem servidor a saber nada, pergunta tudo como sempre', (
    tester,
  ) async {
    // Modo de demonstração e contas sem pedido: o percurso não encolhe.
    await abrir(tester, comAcesso(null));

    expect(find.text('Como te chamas?'), findsOneWidget);
    expect(find.text('1 de 14'), findsOneWidget);
  });

  testWidgets('só o que o servidor souber é que sai', (tester) async {
    // Nome sim, empresa não: sai uma pergunta, fica a outra.
    await abrir(
      tester,
      comAcesso(
        const EstadoAcesso(
          membroAtivo: true,
          perfil: 'gestor',
          nome: 'Alfredo',
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Vamos a isto'));
    await tester.pumpAndSettle();

    expect(find.text('Como te chamas?'), findsNothing);
    expect(find.text('Como se chama a empresa?'), findsOneWidget);
    expect(find.text('1 de 12'), findsOneWidget);
  });
}

class _RepoVazio extends LocalDemoOperationRepository {
  _RepoVazio() {
    resetAll();
  }
}
