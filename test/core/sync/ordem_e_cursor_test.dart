import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/sincronizacao_entre_dispositivos.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **A ordem por que as operações se aplicam, e até onde se leu.**
///
/// O que isto protege está escrito no que aconteceu: a 4 de Agosto de 2026, num
/// Redmi, fechar um trabalho em *A minha semana* durava um segundo. O servidor
/// ficava com `completed` — está lá, com o id daquele telemóvel — e a app
/// voltava a mostrar "Em curso", inclusive depois de reiniciada.
///
/// A causa foi uma palavra que não estava escrita. `.order('seq')`, no
/// postgrest-dart, é **descendente** por omissão — ao contrário do PostgREST e
/// do cliente de JavaScript. Uma linha só de código, e dois estragos:
///
/// 1. o histórico era aplicado do fim para o princípio, portanto **ganhava o
///    estado mais antigo** de cada entidade;
/// 2. o cursor ficava no `seq` **mínimo** do lote em vez do máximo, portanto
///    cada sincronização avançava uma linha e reaplicava todo o resto — de
///    forma que o trabalho acabado de fazer era enterrado outra vez, e outra.
///
/// Dois defeitos com a mesma origem e o mesmo sintoma: o gestor carrega num
/// botão, vê acontecer, e no minuto seguinte está tudo como estava. É a pior
/// avaria que uma sincronização pode ter, porque não dá erro — mente em
/// silêncio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> linha(
    int seq,
    String estado, {
    String dispositivo = 'outro-aparelho',
    String id = 'res-9',
  }) => {
    'seq': seq,
    'entidade': 'booking',
    'entidade_id': id,
    'por_dispositivo': dispositivo,
    'payload': {
      'id': id,
      'customerId': 'c1',
      'machineIds': ['m1'],
      'startsAt': '2026-07-30T08:00:00.000',
      'endsAt': '2026-08-03T18:00:00.000',
      'status': estado,
      'expectedValueCents': 36000,
    },
  };

  group('a ordem em que se aplica', () {
    test('um lote que chega ao contrário é posto por seq crescente', () {
      // Exactamente o que o servidor devolvia: do maior para o menor.
      final lote = prepararLote([
        linha(227, 'completed'),
        linha(225, 'confirmed'),
        linha(200, 'rented'),
      ], cursor: 0);

      expect(lote.linhas.map((l) => l['seq']), [200, 225, 227]);
    });

    test('aplicado por esta ordem, ganha a escrita mais recente', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();

      final lote = prepararLote([
        linha(227, 'completed'),
        linha(200, 'rented'),
      ], cursor: 0);
      for (final l in lote.linhas) {
        repo.aplicarOperacaoRemota(
          l['entidade'] as String,
          Map<String, dynamic>.from(l['payload'] as Map),
        );
      }

      // Antes da correcção davam `rented`: o mais antigo aplicado por último.
      // O trabalho fechado voltava a "em curso" sozinho.
      expect(repo.bookings.single.status, BookingStatus.completed);
    });
  });

  group('até onde se leu', () {
    test('o cursor é o maior seq do lote, não o da última linha', () {
      // Com as linhas ao contrário, `cursor = seq` a cada volta acabava em 200.
      // Na sincronização seguinte, tudo a partir de 201 vinha outra vez.
      final lote = prepararLote([
        linha(227, 'completed'),
        linha(225, 'confirmed'),
        linha(200, 'rented'),
      ], cursor: 0);

      expect(lote.cursor, 227);
    });

    test('o cursor nunca recua', () {
      final lote = prepararLote([linha(5, 'rented')], cursor: 400);

      // Uma linha antiga que apareça num lote não pode mandar a app reler
      // quatrocentas operações.
      expect(lote.cursor, 400);
    });

    test('um lote vazio deixa o cursor onde estava', () {
      expect(prepararLote(const [], cursor: 227).cursor, 227);
    });

    test('lotes seguidos avançam de facto — não uma linha de cada vez', () {
      var cursor = 0;
      for (final bloco in [
        [linha(1, 'request'), linha(2, 'confirmed')],
        [linha(3, 'rented'), linha(4, 'completed')],
      ]) {
        cursor = prepararLote(bloco, cursor: cursor).cursor;
      }

      expect(cursor, 4);
    });
  });

  group('uma linha má não pode prender o canal', () {
    test('as boas passam à mesma, e a má fica contada', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();

      final resultado = aplicarLinhas(repo, [
        // Sem `machineIds` — o parser rebenta nesta linha.
        {
          'seq': 210,
          'entidade': 'booking',
          'entidade_id': 'res-mau',
          'payload': {'id': 'res-mau', 'customerId': 'c1'},
        },
        linha(227, 'completed'),
      ]);

      expect(resultado.aplicadas, 1);
      expect(resultado.recusadas, 1);
      // A que interessava entrou. Antes disto, a linha má levava o lote atrás
      // dela, o cursor não avançava, e o mesmo estrago repetia-se de cinco em
      // cinco minutos até alguém reinstalar a app.
      expect(repo.bookings.single.status, BookingStatus.completed);
    });

    test('uma entidade que esta versão não conhece é ignorada em silêncio', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();

      final resultado = aplicarLinhas(repo, [
        {
          'seq': 300,
          'entidade': 'orcamento',
          'entidade_id': 'o1',
          'payload': {'id': 'o1'},
        },
      ]);

      // Uma app antiga não pode rebentar por o servidor ter aprendido algo novo
      // — nem contar isso como recusa.
      expect(resultado.recusadas, 0);
    });
  });

  group('as linhas do próprio aparelho', () {
    test('vêm no lote como as outras, e é isso que cura o aparelho', () async {
      // Saltá-las só é seguro enquanto o estado local estiver certo. Quando não
      // está — e foi o caso —, as nossas linhas são as únicas que o podem
      // corrigir, e eram justamente as que se deitavam fora: a app divergia do
      // servidor para sempre, sem erro nenhum a dizê-lo.
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();

      // O estado local errado, como ficou no Redmi.
      repo.aplicarOperacaoRemota('booking', {
        'id': 'res-9',
        'customerId': 'c1',
        'machineIds': ['m1'],
        'startsAt': '2026-07-30T08:00:00.000',
        'endsAt': '2026-08-03T18:00:00.000',
        'status': 'rented',
      });

      final lote = prepararLote([
        linha(200, 'rented'),
        linha(227, 'completed', dispositivo: 'este-aparelho'),
      ], cursor: 0);
      for (final l in lote.linhas) {
        repo.aplicarOperacaoRemota(
          l['entidade'] as String,
          Map<String, dynamic>.from(l['payload'] as Map),
        );
      }

      expect(repo.bookings.single.status, BookingStatus.completed);
    });

    test('reaplicá-las não põe nada de volta na fila', () async {
      // Se pusesse, era um eco sem fim: aplicar gera operação, que sobe, que
      // desce, que volta a gerar.
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();
      var emitidas = 0;
      repo.aoRegistarOperacao = (_, __, ___) => emitidas++;

      repo.aplicarOperacaoRemota(
        'booking',
        Map<String, dynamic>.from(
          linha(227, 'completed', dispositivo: 'este-aparelho')['payload']
              as Map,
        ),
      );

      expect(emitidas, 0);
    });
  });
}
