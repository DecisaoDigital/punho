import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/presentation/login_screen.dart';

/// **A recuperação tem de caber com o teclado aberto.**
///
/// No Redmi, em landscape, o teclado ocupa 57% do ecrã: sobram 160 dp de
/// altura. Enquanto isto foi um `AlertDialog`, não se queixava quando não
/// cabia — encolhia o conteúdo até onde fosse preciso, e a 4 de Agosto de 2026
/// encolheu-o a **zero**. O título e os botões continuavam lá, o campo do
/// email desaparecia, e escrevia-se às cegas sem nada a indicar que faltava
/// alguma coisa. Só se percebeu ao medir os limites no `uiautomator`.
///
/// Passou a ecrã completo, que encolhe com o teclado em vez de ser encolhido
/// por ele. O teste fica na mesma e continua a ser a régua: segue a ordem real
/// — abre com o ecrã inteiro, e só depois o `autofocus` levanta o teclado.
void main() {
  // O Redmi deitado: 2177x1080 físicos a 2.75 de densidade.
  const ecraFisico = Size(2177, 1080);
  const densidade = 2.75;
  // O teclado medido no mesmo aparelho: 620 px físicos, 225 dp.
  const tecladoFisico = 620.0;

  Future<Finder> abrirARecuperacao(WidgetTester tester) async {
    tester.view.physicalSize = ecraFisico;
    tester.view.devicePixelRatio = densidade;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(aoCriarConta: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Esqueci a palavra-passe'));
    await tester.pumpAndSettle();

    return find.byType(TextField);
  }

  Future<void> levantarOTeclado(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: tecladoFisico);
    await tester.pumpAndSettle();
  }

  testWidgets('com o teclado aberto, o campo do email continua visível', (
    tester,
  ) async {
    final campo = await abrirARecuperacao(tester);
    await levantarOTeclado(tester);

    expect(find.text('Recuperar palavra-passe'), findsOneWidget);
    expect(campo, findsOneWidget);

    // Um `TextField` deste tamanho de letra ronda os 48 dp. Exigir >= 40 deixa
    // margem para o tema mudar sem transformar isto num teste de pixels — mas
    // apanha o zero, que é o que interessa.
    expect(
      tester.getSize(campo).height,
      greaterThanOrEqualTo(40),
      reason: 'o campo do email foi esmagado — escreve-se às cegas',
    );

    // E o "Enviar" tem de continuar alcançável: um formulário que cabe mas em
    // que não se chega ao botão não serve de nada.
    expect(find.text('Enviar'), findsOneWidget);
    expect(tester.getSize(find.text('Enviar')).height, greaterThan(0));
  });

  testWidgets('a explicação continua a ser dada, e não se perdeu no caminho', (
    tester,
  ) async {
    await abrirARecuperacao(tester);
    await levantarOTeclado(tester);

    // Mudou de sítio — de parágrafo à parte para dica do campo — mas quem abre
    // isto continua a ficar a saber o que vai acontecer a seguir.
    expect(
      find.textContaining('Envio-te um link'),
      findsOneWidget,
      reason: 'sem isto, pede-se um email sem dizer para quê',
    );
  });

  testWidgets('sem teclado também cabe, sem sobras estranhas', (tester) async {
    final campo = await abrirARecuperacao(tester);

    expect(tester.getSize(campo).height, greaterThanOrEqualTo(40));
  });
}
