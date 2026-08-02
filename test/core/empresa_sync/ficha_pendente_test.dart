import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/ficha_pendente.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A ficha pendente é um estado — "como é a empresa agora, ainda por
/// confirmar" — e não uma fila de eventos. Estes testes fixam isso: guardar
/// de novo substitui, nunca acumula, e o que fica gravado sobrevive a fechar
/// a app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sem nada gravado, não há ficha pendente', () async {
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );

    expect(pendente.ficha, isNull);
  });

  test('o que se guarda é o que se lê', () async {
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );

    await pendente.guardar({'nif': '509442129', 'nome_comercial': 'Mare Alta'});

    expect(pendente.ficha, {
      'nif': '509442129',
      'nome_comercial': 'Mare Alta',
    });
  });

  test('guardar de novo substitui a anterior, não acumula', () async {
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );

    await pendente.guardar({'nif': '111', 'nome_comercial': 'Primeira'});
    await pendente.guardar({'nif': '222', 'nome_comercial': 'Segunda'});

    expect(pendente.ficha, {'nif': '222', 'nome_comercial': 'Segunda'});
  });

  test('a pendência sobrevive a fechar a app', () async {
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );
    await pendente.guardar({'nif': '509442129'});

    // Uma instância nova, como no arranque seguinte.
    final outra = FichaEmpresaPendente(await SharedPreferences.getInstance());

    expect(outra.ficha, {'nif': '509442129'});
  });

  test('limpar apaga a pendência', () async {
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );
    await pendente.guardar({'nif': '509442129'});

    await pendente.limpar();

    expect(pendente.ficha, isNull);
  });

  test('uma linha corrompida conta como ausente, não como erro', () async {
    SharedPreferences.setMockInitialValues({
      'punho_empresa_sync.pendente_v1': '{isto não é json',
    });
    final pendente = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );

    expect(pendente.ficha, isNull);
  });
}
