import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';

/// O corpo do formulário tem de sobreviver ao teclado.
///
/// No Redmi Note 10 Pro deitado — 873x393 dp — o teclado leva 200 dp. Sobram
/// 193, e enquanto isto foi um diálogo o cabeçalho mais o rodapé em tamanho
/// normal somavam 124: o corpo, que era `Flexible`, encolhia até zero. Ficava
/// título, um vazio e os botões, e não havia forma de escrever um nome.
///
/// Em ecrã completo o corpo é o que sobra do ecrã, e o que sobra do ecrã já
/// desconta o teclado. Estes testes continuam a medir a altura do corpo: não
/// olham para o aspecto — olham para o número que estava a zero.
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

    final controladores = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in controladores) {
        c.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: tamanho, viewInsets: teclado),
          child: EcraDeFormulario(
            titulo: 'Adicionar colaborador',
            aoGuardar: () {},
            campos: [
              for (var i = 0; i < 6; i++)
                CampoDeTexto(controlador: controladores[i], rotulo: 'Campo $i'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double alturaDoCorpo(WidgetTester tester) =>
      tester.getSize(find.byType(SingleChildScrollView)).height;

  testWidgets('com o teclado aberto o corpo continua a existir', (
    tester,
  ) async {
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

  testWidgets('o Guardar nunca fica debaixo do teclado', (tester) async {
    await montar(tester, teclado: tecladoAberto);

    // Está na barra de topo, que é onde nenhum teclado lhe chega.
    final guardar = tester.getRect(find.text('Guardar'));
    expect(guardar.bottom, lessThanOrEqualTo(393 - 200));
  });

  testWidgets('com o teclado aberto vê-se mais do que um campo', (
    tester,
  ) async {
    await montar(tester, teclado: tecladoAberto);

    final campos = find.byType(TextField);
    var inteiros = 0;
    for (var i = 0; i < tester.widgetList(campos).length; i++) {
      final caixa = tester.getRect(campos.at(i));
      if (caixa.bottom <= 393 - 200 && caixa.height > 20) inteiros++;
    }
    // Era isto que não acontecia: com o teclado aberto não havia um único campo
    // utilizável. A altura escasseia, a largura sobra — e é por isso que há
    // colunas.
    expect(
      inteiros,
      greaterThanOrEqualTo(4),
      reason: 'só $inteiros campos à vista com o teclado aberto',
    );
  });

  testWidgets('num ecrã com altura os campos não andam apertados', (
    tester,
  ) async {
    // O modo compacto é para quando falta altura, e não deve contaminar o
    // normal. O Redmi deitado é sempre apertado, com teclado ou sem ele: 393 dp
    // é pouco para um formulário de qualquer maneira. Num ecrã com altura, não.
    await montar(
      tester,
      teclado: EdgeInsets.zero,
      tamanho: const Size(873, 900),
    );

    final campo = tester.widget<TextField>(find.byType(TextField).first);
    expect(campo.decoration?.isDense, isFalse);
  });
}
