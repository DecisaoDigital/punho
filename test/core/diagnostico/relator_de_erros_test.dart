import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/diagnostico/relator_de_erros.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que estes testes protegem: **um erro em casa do cliente tem de chegar a
/// alguém**.
///
/// Antes disto, todos os `catch` da app acabavam em `debugPrint`, que não
/// existe numa build release. O código já tinha a lição escrita: um catch mudo
/// escondeu durante duas versões que a app estava a ser compilada sem os
/// `--dart-define`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RelatorDeErros relator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    relator = RelatorDeErros(
      await SharedPreferences.getInstance(),
      machineId: 'maquina-de-teste',
      versao: '0.2.1+34',
      contextoBase: const {'modelo': 'Redmi Note 12'},
    );
  });

  test('grava o erro no disco em vez de o perder', () async {
    await relator.registar(
      tipo: 'flutter',
      erro: StateError('o cliente não existe'),
      pilha: StackTrace.fromString('#0 qualquer coisa'),
    );

    final fila = relator.pendentes;

    expect(fila, hasLength(1));
    expect(fila.single.tipo, 'flutter');
    expect(fila.single.mensagem, contains('o cliente não existe'));
    expect(fila.single.pilha, contains('#0'));
  });

  test('sobrevive a fechar a app — é esse o ponto todo', () async {
    // Um erro que mata a app não tem tempo de fazer um pedido HTTP. Se não
    // sobrevivesse ao arranque seguinte, os erros fatais nunca se saberiam,
    // e são precisamente os que mais interessam.
    await relator.registar(tipo: 'zona', erro: 'rebentou');

    final outro = RelatorDeErros(
      await SharedPreferences.getInstance(),
      machineId: 'maquina-de-teste',
      versao: '0.2.1+34',
    );

    expect(outro.pendentes.single.mensagem, 'rebentou');
  });

  test('junta o contexto do aparelho ao do erro', () async {
    await relator.registar(
      tipo: 'manual',
      erro: 'falhou',
      contexto: {'ecra': 'reservas'},
    );

    final contexto = relator.pendentes.single.contexto;

    expect(contexto['modelo'], 'Redmi Note 12');
    expect(contexto['ecra'], 'reservas');
  });

  test('uma app em ciclo de erro não enche o telemóvel', () async {
    for (var i = 0; i < RelatorDeErros.maximoNaFila + 7; i++) {
      await relator.registar(tipo: 'zona', erro: 'erro $i');
    }

    final fila = relator.pendentes;

    expect(fila, hasLength(RelatorDeErros.maximoNaFila));
    expect(
      fila.last.mensagem,
      'erro ${RelatorDeErros.maximoNaFila + 6}',
      reason: 'ficam os mais recentes',
    );
  });

  test('corta pilhas enormes — o que interessa está no princípio', () async {
    await relator.registar(
      tipo: 'flutter',
      erro: 'x' * 5000,
      pilha: StackTrace.fromString('y' * 20000),
    );

    final erro = relator.pendentes.single;

    expect(erro.mensagem.length, lessThan(1100));
    expect(erro.pilha!.length, lessThan(4100));
  });

  test('registar nunca lança, aconteça o que acontecer', () async {
    // Um relator de erros que rebenta é pior do que não ter relator nenhum:
    // transforma um erro visível num crash.
    await expectLater(
      relator.registar(tipo: 'manual', erro: Object()),
      completes,
    );
  });
}
