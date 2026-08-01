import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/presentation/login_screen.dart';

/// O que o ecrã de entrar tem de ter, sempre.
///
/// Estas três coisas existiram e desapareceram sem ninguém dar por isso. O
/// histórico está no git:
///
///   29/07 09:39  `31e6f4e`  "Esqueci a palavra-passe" — adicionado
///   29/07 12:53  `afab061`  AutofillGroup + autofillHints + olhinho — adicionados
///                `9ac5655`  **as três desaparecem de uma vez**
///
/// O commit que as levou foi um de *branding* — pôr o símbolo do Punho no
/// Login, no Registo e no Onboarding. Reescreveu o ecrã a partir de uma versão
/// anterior do ficheiro e arrastou tudo o que lá tinha entrado nesse dia.
///
/// O `afab061` era ele próprio a correcção de um smoke test, e dizia no corpo:
/// *"link do email caía em página em branco, sem recuperação possível"*. Três
/// horas depois estava desfeito.
///
/// Ninguém deu por isso porque não havia teste nenhum a cobrir este ecrã. Um
/// commit de branding não pode conseguir remover a recuperação de palavra-passe
/// sem nada acusar — é para isso que este ficheiro existe.
void main() {
  Future<void> abrirLogin(
    WidgetTester tester, {
    Future<String?> Function(String, String)? aoEntrar,
    Future<String?> Function(String)? aoRecuperar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          aoCriarConta: () {},
          aoEntrar: aoEntrar ?? (_, _) async => null,
          aoRecuperar: aoRecuperar ?? (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('há saída para quem perdeu a palavra-passe', (tester) async {
    await abrirLogin(tester);

    // Sem isto, quem perde a palavra-passe perde a empresa e os dados. Não é
    // uma conveniência — é a única porta de volta.
    expect(find.text('Esqueci a palavra-passe'), findsOneWidget);
  });

  testWidgets('o Android consegue oferecer a palavra-passe guardada', (
    tester,
  ) async {
    await abrirLogin(tester);

    // É o `AutofillGroup` que diz ao sistema que aquilo é um formulário de
    // login. Sem ele o gestor de palavras-passe não decora nem oferece nada, e
    // a app parece "não se lembrar" de quem lá entrou ontem.
    expect(find.byType(AutofillGroup), findsOneWidget);

    final campos = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(
      campos.any(
        (c) => c.autofillHints?.contains(AutofillHints.password) ?? false,
      ),
      isTrue,
      reason: 'o campo da palavra-passe não se identifica ao sistema',
    );
    expect(
      campos.any(
        (c) => c.autofillHints?.contains(AutofillHints.username) ?? false,
      ),
      isTrue,
      reason: 'o campo do email não se identifica ao sistema',
    );
  });

  testWidgets('o olhinho mostra e esconde o que se escreveu', (tester) async {
    await abrirLogin(tester);

    TextField campoDaPass() => tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((c) => c.obscureText || c.decoration?.suffixIcon != null);

    // Começa escondida.
    expect(campoDaPass().obscureText, isTrue);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    // E vê-se, que é o ponto: numa palavra-passe longa escrita num teclado de
    // telemóvel, escrever às cegas é a diferença entre entrar e tentar três
    // vezes.
    expect(campoDaPass().obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    expect(campoDaPass().obscureText, isTrue);
  });

  testWidgets('o "Esqueci" pede mesmo o email de recuperação', (tester) async {
    // Ter o botão não chega: o `afab061` corrigiu precisamente um caso em que
    // o link existia e levava a uma página em branco. Aqui verifica-se que o
    // pedido sai, e com que email.
    final pedidos = <String>[];
    await abrirLogin(
      tester,
      aoRecuperar: (email) async {
        pedidos.add(email);
        return null;
      },
    );

    await tester.enterText(find.byType(TextField).first, 'ana@exemplo.pt');
    await tester.tap(find.text('Esqueci a palavra-passe'));
    await tester.pumpAndSettle();

    // O email já vem preenchido do campo de cima — não se pede duas vezes.
    expect(find.text('Recuperar palavra-passe'), findsOneWidget);
    await tester.tap(find.text('Enviar'));
    // `pump` e não `pumpAndSettle`: o segundo avança o tempo até tudo assentar,
    // e a mensagem já se tinha ido embora sozinha quando se olhava para ela.
    await tester.pump();
    await tester.pump();

    expect(pedidos, ['ana@exemplo.pt']);

    // A mensagem não revela se a conta existe: igual nos dois casos, senão
    // este ecrã servia para descobrir quem tem conta.
    expect(find.textContaining('Se existir uma conta'), findsOneWidget);
  });
}
