import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/fichas_postas_de_lado.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O balde das fichas que o servidor mandou deitar fora.
///
/// Guardar não chega: tem de sobreviver a fechar a app (é aí que o gestor a vai
/// ver), tem de ser legível por quem não sabe o que é um payload, e uma linha
/// estragada não pode levar as outras com ela.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RegistoDeFichasPostasDeLado> registo() async {
    SharedPreferences.setMockInitialValues({});
    return RegistoDeFichasPostasDeLado(await SharedPreferences.getInstance());
  }

  String fichaComCustos() => jsonEncode({
    'onboarding': {
      'companyName': 'Terraforte',
      'custosFixos': [
        {'id': 'r1', 'categoria': 'rent', 'valorCents': 90000},
        {'id': 'r2', 'categoria': 'electricity', 'valorCents': 12500},
      ],
    },
    'historicalMonths': [
      {'year': 2026, 'month': 1},
      {'year': 2026, 'month': 2},
      {'year': 2026, 'month': 3},
    ],
  });

  FichaPostaDeLado posta({DateTime? quando, String? payload}) =>
      FichaPostaDeLado(
        quando: quando ?? DateTime.utc(2026, 8, 10, 14, 32),
        revisaoLocal: 3,
        revisaoDoServidor: 7,
        payload: payload ?? fichaComCustos(),
      );

  test('o que se guarda continua lá depois de fechar a app', () async {
    final antes = await registo();
    await antes.guardar(posta());

    // Instância nova sobre as mesmas preferências — é o que acontece ao
    // reabrir a app.
    final depois = RegistoDeFichasPostasDeLado(
      await SharedPreferences.getInstance(),
    );

    final ficha = depois.todas.single;
    expect(ficha.revisaoLocal, 3);
    expect(ficha.revisaoDoServidor, 7);
    expect(ficha.payload, contains('Terraforte'));
  });

  test('a mais recente aparece primeiro', () async {
    final balde = await registo();
    await balde.guardar(posta(quando: DateTime.utc(2026, 8, 1)));
    await balde.guardar(posta(quando: DateTime.utc(2026, 8, 9)));
    await balde.guardar(posta(quando: DateTime.utc(2026, 8, 5)));

    expect(
      balde.todas.map((f) => f.quando.day),
      [9, 5, 1],
      reason: 'a que o gestor acabou de perder é a que ele precisa de ver',
    );
  });

  test('o resumo diz o que lá ia, em números', () async {
    final resumo = posta().resumo;

    expect(resumo.empresa, 'Terraforte');
    expect(resumo.rubricas, 2);
    expect(resumo.custosMensaisCents, 102500);
    expect(resumo.meses, 3);
  });

  test('payload ilegível ainda dá cartão — sem números', () async {
    // Uma ficha que não se consegue ler continua a ser uma ficha que se
    // perdeu. Rebentar aqui era esconder a perda por causa da forma dela.
    final resumo = posta(payload: '{isto não é json').resumo;

    expect(resumo.empresa, isNull);
    expect(resumo.rubricas, 0);
    expect(resumo.meses, 0);
  });

  test('uma linha estragada no disco não leva as outras', () async {
    SharedPreferences.setMockInitialValues({
      'punho_sync.fichas_postas_de_lado_v1': [
        'isto não é uma linha',
        jsonEncode(posta().paraDisco()),
      ],
    });
    final balde = RegistoDeFichasPostasDeLado(
      await SharedPreferences.getInstance(),
    );

    expect(balde.todas.single.revisaoDoServidor, 7);
  });

  test('tem tecto: guarda as últimas 20', () async {
    final balde = await registo();
    for (var dia = 1; dia <= 25; dia++) {
      await balde.guardar(posta(quando: DateTime.utc(2026, 7, dia)));
    }

    // As mais antigas caem. Isto é para ser visto e limpo, não para encher o
    // disco com fichas inteiras de meses atrás.
    expect(balde.todas, hasLength(20));
    expect(balde.todas.last.quando.day, 6);
  });

  test('limpar deixa o balde vazio', () async {
    final balde = await registo();
    await balde.guardar(posta());

    await balde.limpar();

    expect(balde.todas, isEmpty);
  });
}
