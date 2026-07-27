import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/conta/presentation/perfil_popup.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';

import '../dashboard/fixtura.dart';

/// O Perfil no avatar da barra lateral.
///
/// O avatar era decorativo: só tooltip, sem `onTap`. Não havia forma de ver quem
/// estava ligado nem de sair sem procurar o ícone certo — e num dispositivo
/// partilhado isso deixa a conta anterior lá presa.
void main() {
  group('podeTerminarSessao', () {
    test('só com Supabase e utilizador', () {
      // Pura porque o `SupabaseConfig.enabled` é constante de compilação e nos
      // testes é sempre falso: sem isto o caminho "com sessão" não se cobria.
      expect(
        podeTerminarSessao(comSupabase: true, comUtilizador: true),
        isTrue,
      );
      expect(
        podeTerminarSessao(comSupabase: true, comUtilizador: false),
        isFalse,
        reason: 'sessão expirada não tem o que terminar',
      );
      expect(
        podeTerminarSessao(comSupabase: false, comUtilizador: true),
        isFalse,
        reason: 'em demonstração local não há sessão',
      );
    });
  });

  group('Abrir pelo avatar', () {
    testWidgets('tocar no avatar abre o Perfil', (tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
        tamanho: const Size(1280, 800),
      );

      expect(find.byType(PerfilPopup), findsNothing);
      await tester.tap(find.byKey(chaveDoAvatarDoPerfil));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilPopup), findsOneWidget);
    });

    testWidgets('a área tocável é o círculo desenhado', (tester) async {
      // O `Container` colorido não recebia toque nenhum. Com `Material` +
      // `InkWell` da mesma forma, tocar dentro do desenho abre — inclusive junto
      // ao bordo, que é onde um hit target menor falharia.
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
        tamanho: const Size(1280, 800),
      );

      final caixa = tester.getRect(find.byKey(chaveDoAvatarDoPerfil));
      expect(caixa.width, 32);
      expect(caixa.height, 32);
      // Junto ao bordo esquerdo, à altura do centro: dentro do círculo, e é
      // onde um hit target menor do que o desenho falharia. O canto do
      // quadrado **não** se testa — num avatar redondo o canto não é área
      // desenhada, portanto não ser tocável é o comportamento certo.
      await tester.tapAt(Offset(caixa.left + 2, caixa.center.dy));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilPopup), findsOneWidget);
    });
  });

  group('Conteúdo em modo de demonstração', () {
    Future<void> abrirPerfil(WidgetTester tester) async {
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
        tamanho: const Size(1280, 800),
      );
      await tester.tap(find.byKey(chaveDoAvatarDoPerfil));
      await tester.pumpAndSettle();
    }

    testWidgets('chip de demonstração, sem email e sem terminar sessão', (
      tester,
    ) async {
      await abrirPerfil(tester);

      expect(find.text('MODO DEMONSTRAÇÃO'), findsOneWidget);
      expect(find.text('SESSÃO ACTIVA'), findsNothing);
      // Sem conta não há email: uma linha "Email" vazia faria parecer que
      // faltava um dado.
      expect(find.text('Email'), findsNothing);
      expect(find.text('Terminar sessão'), findsNothing);
      expect(
        find.textContaining('não há sessão para terminar'),
        findsOneWidget,
      );
    });

    testWidgets('mostra quem está ligado e a empresa', (tester) async {
      await abrirPerfil(tester);

      expect(find.text('Alfredo'), findsOneWidget);
      expect(find.text('Gestor (demonstração)'), findsOneWidget);
    });

    testWidgets('fecha pelo Fechar', (tester) async {
      await abrirPerfil(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilPopup), findsNothing);
    });

    testWidgets('não tem edição de dados da empresa', (tester) async {
      // Isso é o destino Empresa da v0.0.7. Um popup com formulário de empresa
      // era a ContaScreen unificada que ficou explicitamente de fora.
      await abrirPerfil(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Guardar alterações'), findsNothing);
    });
  });

  group('O botão de sair solto desapareceu da barra', () {
    testWidgets('a barra lateral já não tem o ícone de logout', (tester) async {
      // Estava ao lado dos convites, sem confirmação e sem contexto. Agora vive
      // dentro do Perfil, onde se sabe de quem é a sessão que se está a fechar.
      await montarLandscape(
        tester,
        containerCom(estadoComMovimento()),
        const AppShell(),
        tamanho: const Size(1280, 800),
      );

      expect(
        find.descendant(
          of: find.byKey(chaveDaBarraLateral),
          matching: find.byIcon(Icons.logout),
        ),
        findsNothing,
      );
    });
  });
}
