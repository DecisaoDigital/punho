import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/shared/widgets/brand_lockup.dart';

/// O nome da marca tem de se ler nos dois fundos onde o lockup vive.
///
/// Esteve fixo em branco, escolhido para o navy da barra lateral: no
/// onboarding, no login e no registo — todos de fundo claro — ficava branco
/// sobre branco. O Cesar viu-o numa captura do telemóvel.
void main() {
  Color corDe(WidgetTester tester, String texto) =>
      tester.widget<Text>(find.text(texto)).style!.color!;

  Future<void> montar(WidgetTester tester, {required bool emFundoEscuro}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: PunhoTheme.light,
          home: Scaffold(body: BrandLockup(emFundoEscuro: emFundoEscuro)),
        ),
      );

  testWidgets('em fundo claro o nome é navy, e não branco', (tester) async {
    await montar(tester, emFundoEscuro: false);
    expect(corDe(tester, 'Punho'), PunhoTheme.navyDeep);
    // O slogan acompanha, esbatido — o que não pode é ser o cinza-claro do navy.
    expect(corDe(tester, 'Agarra o comando.'), isNot(const Color(0xFFB7C5CE)));
  });

  testWidgets('em navy o nome continua branco', (tester) async {
    await montar(tester, emFundoEscuro: true);
    expect(corDe(tester, 'Punho'), Colors.white);
    expect(corDe(tester, 'Agarra o comando.'), const Color(0xFFB7C5CE));
  });

  testWidgets('o default é o fundo claro', (tester) async {
    // A maioria dos ecrãs que o usam é clara. Quem está em navy é que diz.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLockup())),
    );
    expect(corDe(tester, 'Punho'), PunhoTheme.navyDeep);
  });
}
