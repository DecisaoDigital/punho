import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/dialogo_de_formulario.dart';

/// O corpo do diálogo tem de sobreviver ao teclado.
///
/// No Redmi Note 10 Pro deitado — 873x393 dp — o teclado leva 200 dp. Sobram
/// 193, e o cabeçalho mais o rodapé em tamanho normal somavam 124: o corpo,
/// que é `Flexible`, encolhia até zero. Ficava título, um vazio e os botões, e
/// não havia forma de escrever um nome.
///
/// Estes testes medem a altura do corpo. Não olham para o aspecto — olham para
/// o número que estava a zero.
void main() {
  const redmiDeitado = Size(873, 393);

  /// Medido no telemóvel: o teclado ocupa 200 dos 393 dp.
  const tecladoAberto = EdgeInsets.only(bottom: 200);

  Future<void> montar(
    WidgetTester tester, {
    required EdgeInsets teclado,
    Size tamanho = redmiDeitado,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: tamanho, viewInsets: teclado),
          child: DialogoDeFormulario(
            titulo: 'Adicionar colaborador',
            aoGuardar: () {},
            corpo: Column(
              children: List.generate(
                6,
                (i) => TextField(
                  decoration: InputDecoration(labelText: 'Campo $i'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double alturaDoCorpo(WidgetTester tester) =>
      tester.getSize(find.byType(SingleChildScrollView)).height;

  testWidgets('com o teclado aberto o corpo continua a existir', (tester) async {
    await montar(tester, teclado: tecladoAberto);

    final altura = alturaDoCorpo(tester);
    // Um campo de texto do Material mede cerca de 48 dp. Menos do que isso e o
    // formulário não serve para nada — que era exactamente o defeito.
    expect(
      altura,
      greaterThan(48),
      reason: 'o corpo ficou com $altura dp: não cabe um único campo',
    );
  });

  testWidgets('o rodapé nunca fica debaixo do teclado', (tester) async {
    await montar(tester, teclado: tecladoAberto);

    final rodape = tester.getRect(find.text('Guardar'));
    expect(rodape.bottom, lessThanOrEqualTo(393 - 200));
  });

  testWidgets('sem teclado mantém a moldura folgada', (tester) async {
    await montar(tester, teclado: EdgeInsets.zero);

    // Sem aperto o título continua no tamanho grande: o modo compacto é para o
    // caso apertado e não deve contaminar o normal.
    final titulo = tester.widget<Text>(find.text('Adicionar colaborador'));
    expect(titulo.style?.fontSize, greaterThan(18));
  });
}
