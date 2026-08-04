import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:punho/core/sync/sincronizacao_entre_dispositivos.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **O cursor tem de chegar à consulta.**
///
/// Este ficheiro existe porque os outros testes de sincronização não bastaram.
/// Cobriam bem o que se faz às linhas **depois** de chegarem — a ordem, o
/// cursor que fica, a linha má que não pode prender o lote — e passavam todos,
/// com o defeito lá dentro. Nenhum olhava para o que se *pede* ao servidor.
///
/// E era aí que estava. O cursor era lido, passado adiante e gravado, e a
/// consulta pedia à mesma o histórico inteiro desde o princípio. De cinco em
/// cinco minutos, o passado voltava a ser aplicado por cima do presente.
///
/// O que se via no Redmi, a 4 de Agosto de 2026: tocar em *Entregar* punha o
/// trabalho em curso, a operação subia (o servidor ficou com ela, `seq 234`), e
/// o ecrã voltava a "Confirmado" e lá ficava, reinícios incluídos. Como
/// [SincronizacaoEntreDispositivos.sincronizar] recebe antes de enviar, a app
/// desfazia localmente o trabalho de quem a usa **e** jurava ao servidor que o
/// tinha feito. As duas metades mentiam ao mesmo tempo, cada uma para o seu
/// lado, sem um erro sequer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> linha(int seq, String estado) => {
    'seq': seq,
    'entidade': 'booking',
    'entidade_id': 'res-13',
    'por_dispositivo': 'semente',
    'payload': {
      'id': 'res-13',
      'customerId': 'c1',
      'machineIds': ['m1'],
      'startsAt': '2026-08-08T08:00:00.000',
      'endsAt': '2026-08-11T18:00:00.000',
      'status': estado,
    },
  };

  late PersistentOperationRepository repo;
  late SincronizacaoEntreDispositivos sync;
  late List<Map<String, dynamic>> servidor;

  /// Que cursor foi pedido em cada consulta. É o que estes testes vieram ver.
  late List<int> pedidos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = await PersistentOperationRepository.create();
    servidor = [];
    pedidos = [];
    sync =
        SincronizacaoEntreDispositivos(
            repositorio: repo,
            registo: RegistoDeOperacoes(prefs),
            // Nunca é usado: [buscarOperacoes] substitui a única chamada de
            // recepção, e estes testes não enviam nada.
            cliente: SupabaseClient('https://exemplo.supabase.co', 'chave'),
            empresaId: 'e1',
          )
          ..buscarOperacoes = (depoisDe) async {
            pedidos.add(depoisDe);
            return servidor.where((l) => (l['seq'] as int) > depoisDe).toList();
          };
  });

  test('a segunda consulta parte de onde a primeira acabou', () async {
    servidor.addAll([linha(204, 'confirmed'), linha(234, 'rented')]);

    await sync.receber();
    await sync.receber();

    // Antes, a segunda volta pedia `0` outra vez — e trazia a linha 204 atrás.
    expect(pedidos, [0, 234]);
  });

  test('uma alteração local não é desfeita pelo histórico antigo', () async {
    // A origem do trabalho, do dia em que foi marcado.
    servidor.add(linha(204, 'confirmed'));
    await sync.receber();
    expect(repo.bookings.single.status, BookingStatus.confirmed);

    // O gestor toca em "Entregar".
    repo.saveBooking(
      repo.bookings.single.copyWith(status: BookingStatus.rented),
    );

    // E passa uma sincronização antes de a operação chegar ao servidor.
    await sync.receber();

    // É este o teste todo. Antes, a linha 204 voltava e escrevia `confirmed`
    // por cima — enquanto a operação na fila de saída continuava a dizer
    // `rented` ao servidor.
    expect(repo.bookings.single.status, BookingStatus.rented);
  });

  test('o que os outros escreveram depois continua a entrar', () async {
    servidor.add(linha(204, 'confirmed'));
    await sync.receber();

    // Filtrar pelo cursor não pode fechar a porta ao que é novo: o colega
    // fechou o trabalho no aparelho dele.
    servidor.add(linha(250, 'completed'));
    await sync.receber();

    expect(repo.bookings.single.status, BookingStatus.completed);
  });

  test('sem nada de novo, não se aplica nada', () async {
    servidor.add(linha(204, 'confirmed'));
    await sync.receber();

    expect(await sync.receber(), 0);
    // Duas consultas, a segunda já a partir de 204: uma app parada não fica a
    // reprocessar o passado de cinco em cinco minutos, para sempre.
    expect(pedidos, [0, 204]);
  });

  // Os testes acima põem um duplo no lugar de [buscarOperacoes] e por isso
  // provam o que [receber] *faz com* o cursor — mas saltam por cima da consulta
  // verdadeira, que era exactamente onde o defeito morava. Este grupo não a
  // salta: deixa o `SupabaseClient` construir o pedido e vai ler o URL que
  // saiu.
  group('a consulta que sai mesmo para a rede', () {
    late Uri pedido;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      sync = SincronizacaoEntreDispositivos(
        repositorio: await PersistentOperationRepository.create(),
        registo: RegistoDeOperacoes(prefs),
        cliente: SupabaseClient(
          'https://exemplo.supabase.co',
          'chave',
          httpClient: _ClienteQueSoAnota((uri) => pedido = uri),
        ),
        empresaId: 'e1',
      );
    });

    test('pede só o que vem depois do cursor', () async {
      await sync.receber();
      expect(pedido.query, contains('seq=gt.0'));

      await sync.registo.guardarCursor(204);
      await sync.receber();

      // Sem este `gt`, a consulta trazia o histórico inteiro desde o princípio
      // e reaplicava-o por cima do presente. O cursor era lido, passado adiante
      // e gravado — e não filtrava nada.
      expect(pedido.query, contains('seq=gt.204'));
    });

    test('pela ordem certa, da empresa certa, e com tecto', () async {
      await sync.receber();

      expect(pedido.query, contains('order=seq.asc'));
      expect(pedido.query, contains('empresa_id=eq.e1'));
      expect(pedido.query, contains('limit=500'));
    });
  });
}

/// Um cliente HTTP que não fala com ninguém: anota o URL pedido e devolve uma
/// lista vazia.
class _ClienteQueSoAnota extends http.BaseClient {
  _ClienteQueSoAnota(this.anotar);
  final void Function(Uri) anotar;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    anotar(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
