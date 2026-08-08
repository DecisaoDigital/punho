import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REGRESSÃO — a fila perdia quase tudo quando várias operações entravam ao
/// mesmo tempo.
///
/// `acrescentar` lê a lista guardada, junta a sua e grava. Como quem chama não
/// espera pelo resultado (o repositório regista e segue), onze chamadas
/// simultâneas liam **a mesma** lista e gravavam por cima umas das outras.
/// Sobrava uma.
///
/// Não é hipótese de laboratório: aconteceu na primeira carga inicial a sério,
/// com 11 entidades enfileiradas no telemóvel e **zero** a chegar ao servidor,
/// sem erro nenhum à vista.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegistoDeOperacoes registo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registo = RegistoDeOperacoes(await SharedPreferences.getInstance());
  });

  OperacaoPendente op(String id) => OperacaoPendente(
    id: id,
    entidade: 'machine',
    entidadeId: id,
    payload: {'id': id},
    feitoEm: DateTime(2026, 8, 2, 1),
  );

  test('onze escritas à solta não se perdem umas às outras', () async {
    // Exactamente o padrão que falhou: enfileirar sem esperar por cada uma.
    for (var i = 0; i < 11; i++) {
      unawaited(registo.acrescentar(op('op$i')));
    }
    await registo.esperarEscritas();

    expect(registo.pendentes, hasLength(11));
    expect(registo.pendentes.map((o) => o.id).toSet(), {
      for (var i = 0; i < 11; i++) 'op$i',
    });
  });

  test('ler antes de esperar era o que enganava: agora espera-se', () async {
    for (var i = 0; i < 5; i++) {
      unawaited(registo.acrescentar(op('x$i')));
    }
    // Sem `esperarEscritas`, `pendentes` podia vir vazia — e o envio dava
    // "0 enviadas", com a fila cheia por baixo.
    await registo.esperarEscritas();
    expect(registo.pendentes, hasLength(5));
  });

  test(
    'acrescentar e remover ao mesmo tempo não ressuscita nem perde',
    () async {
      await registo.acrescentarVarias([op('a'), op('b'), op('c')]);

      // Remover 'a' e 'b' enquanto entram duas novas.
      unawaited(registo.remover({'a', 'b'}));
      unawaited(registo.acrescentar(op('d')));
      unawaited(registo.acrescentar(op('e')));
      await registo.esperarEscritas();

      expect(registo.pendentes.map((o) => o.id).toSet(), {'c', 'd', 'e'});
    },
  );

  test('um lote grande entra inteiro numa só escrita', () async {
    final lote = [for (var i = 0; i < 200; i++) op('l$i')];
    await registo.acrescentarVarias(lote);
    expect(registo.pendentes, hasLength(200));
  });

  test('lote vazio não mexe na fila', () async {
    await registo.acrescentar(op('a'));
    await registo.acrescentarVarias(const []);
    expect(registo.pendentes, hasLength(1));
  });

  group('marca da carga inicial', () {
    const empresa = 'e1';

    test('começa por fazer, e fica feita quando se marca', () async {
      expect(registo.cargaInicialFeita(empresa), isFalse);
      await registo.marcarCargaInicialFeita(empresa);
      expect(registo.cargaInicialFeita(empresa), isTrue);
    });

    test('é por empresa: mudar de empresa obriga a subir outra vez', () async {
      // Sem isto os dados ficavam presos na primeira empresa em que se entrou.
      await registo.marcarCargaInicialFeita('e1');
      expect(registo.cargaInicialFeita('e2'), isFalse);
    });
  });
}
