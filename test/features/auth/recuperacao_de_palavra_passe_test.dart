import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/presentation/nova_palavra_passe_screen.dart';

/// **O caminho de volta de quem perdeu a palavra-passe.**
///
/// Estava partido em dois sítios, e nenhum dava erro. A app pedia ao Supabase
/// que o link do email voltasse a `punho://auth/callback`, mas nem o
/// `AndroidManifest` nem o `Info.plist` declaravam esse esquema: o sistema não
/// sabia a quem entregar o link, e quem carregasse em "Esqueci a palavra-passe"
/// no telemóvel recebia o email e ficava sem caminho de volta. Apanhado a 4 de
/// Agosto de 2026 — o próprio César ficou de fora da app.
///
/// O segundo sítio é o que este ficheiro guarda, e é o mais perigoso dos dois.
/// **Abrir o link autentica**: o `supabase_flutter` chama `getSessionFromUrl` e
/// a partir daí há sessão. Registar o esquema sem mais nada punha a pessoa
/// dentro da app sem lhe ser pedida palavra-passe nenhuma — a antiga continuava
/// a valer, ela julgava tê-la mudado, e no dia seguinte não entrava. Um link de
/// email a dar entrada silenciosa é pior do que o problema que se foi corrigir.
///
/// O ecrã não se chega a montar sem o `AuthGate` o escolher — essa metade está
/// coberta pelo `_aRecuperar` lá, que fica preso até `userUpdated` ou
/// `signedOut`.
void main() {
  Future<void> abrir(
    WidgetTester tester, {
    Future<String?> Function(String)? aoGuardar,
    VoidCallback? aoDesistir,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NovaPalavraPasseScreen(
          aoGuardar: aoGuardar ?? (_) async => null,
          aoDesistir: aoDesistir ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escrever(
    WidgetTester tester,
    String nova,
    String repetida,
  ) async {
    await tester.enterText(find.byType(TextField).first, nova);
    await tester.enterText(find.byType(TextField).last, repetida);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets('pede a palavra-passe nova duas vezes', (tester) async {
    await abrir(tester);

    // Duas e não uma: um erro de dedos aqui tranca a conta na tentativa
    // seguinte, e já não há segundo link para a destrancar.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('não guarda se as duas não forem iguais', (tester) async {
    var guardou = false;
    await abrir(
      tester,
      aoGuardar: (_) async {
        guardou = true;
        return null;
      },
    );

    await escrever(tester, 'palavra-longa-1', 'palavra-longa-2');

    expect(guardou, isFalse);
    expect(find.text('As duas não são iguais.'), findsOneWidget);
  });

  testWidgets('não guarda uma palavra-passe curta', (tester) async {
    var guardou = false;
    await abrir(
      tester,
      aoGuardar: (_) async {
        guardou = true;
        return null;
      },
    );

    await escrever(tester, 'curta', 'curta');

    expect(guardou, isFalse);
    // A mesma regra do registo. Duas regras diferentes para a mesma coisa é a
    // app a contradizer-se.
    expect(
      find.text('A palavra-passe deve ter pelo menos 8 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('guarda a que serve, e diz que ficou feito', (tester) async {
    String? guardada;
    await abrir(
      tester,
      aoGuardar: (nova) async {
        guardada = nova;
        return null;
      },
    );

    await escrever(tester, 'uma-boa-palavra-passe', 'uma-boa-palavra-passe');

    expect(guardada, 'uma-boa-palavra-passe');
    expect(find.text('Palavra-passe alterada.'), findsOneWidget);
  });

  testWidgets('o erro do servidor aparece, e não se finge que correu bem', (
    tester,
  ) async {
    await abrir(
      tester,
      aoGuardar: (_) async => 'Palavra-passe demasiado fraca.',
    );

    await escrever(tester, 'uma-boa-palavra-passe', 'uma-boa-palavra-passe');

    expect(find.text('Palavra-passe demasiado fraca.'), findsOneWidget);
    expect(find.text('Palavra-passe alterada.'), findsNothing);
  });

  testWidgets('desistir fecha a sessão que o link abriu', (tester) async {
    var desistiu = false;
    await abrir(tester, aoDesistir: () => desistiu = true);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Sair daqui sem fechar a sessão deixava a porta encostada a quem só
    // clicou num email.
    expect(desistiu, isTrue);
  });
}
