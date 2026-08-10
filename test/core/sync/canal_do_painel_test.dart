import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/core/sync/sincronizacao_do_painel.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/arranjo_do_painel.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **O painel do gestor não fica no telemóvel dele — e tem canal próprio.**
///
/// Quem troca de aparelho, ou reinstala, tem de encontrar o painel como o
/// deixou. Uma preferência só local dava um painel por telemóvel.
///
/// Este ficheiro substitui o `painel_pelo_instantaneo_test.dart`, e o nome
/// antigo era o problema. O painel viajava no instantâneo
/// (`punho_estado_operacional`), à boleia da ficha da empresa, e a boleia
/// cobrava nos dois sentidos:
///
/// * **a subir** — marcar uma caixa punha a ficha inteira por subir e fazia
///   avançar a revisão. Nos outros telemóveis, a regra "o servidor manda"
///   mandava deitar fora a ficha que tivessem por entregar, por causa de um KPI
///   que alguém escolheu;
/// * **a descer** — entre o toque e o ciclo de sincronização cabe qualquer
///   coisa que outro aparelho faça à ficha. A revisão avançava, "o servidor
///   manda", e a arrumação ia-se sem erro nenhum. Havia um remendo para isso
///   (uma marca que sobrevivia à importação) que só existia por causa da boleia.
///
/// Desde a Fase 3 o painel tem `punho_painel`, com `punho_painel_gravar` à
/// frente e uma guarda de ordem lá dentro. Os casos abaixo são os mesmos de
/// antes — cada um custou um defeito — mais os que o canal novo trouxe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  final arranjo = ArranjoDoPainel.vazio
      .comEscolha('caixa', escolher: true)
      .comEscolha('entradas-mes', escolher: true);

  final doOutro = ArranjoDoPainel.vazio.comEscolha(
    'ticket-medio-mes',
    escolher: true,
  );

  /// Uma linha de `punho_painel` como o PostgREST a devolve.
  Map<String, dynamic> linha(ArranjoDoPainel a, {int revision = 1}) => {
    'dados': a.toJson(),
    'updated_at': '2026-08-10T12:00:00.000Z',
    'revision': revision,
  };

  /// O canal, com as duas idas à rede substituídas por duplos. O caminho a
  /// sério tem o seu grupo no fim do ficheiro.
  SincronizacaoDoPainel canal(
    PersistentOperationRepository repo, {
    Map<String, dynamic>? noServidor,
    void Function(ArranjoDoPainel, DateTime)? aoGravar,
    Map<String, dynamic>? devolveAoGravar,
  }) =>
      SincronizacaoDoPainel(
          repositorio: repo,
          cliente: SupabaseClient('https://exemplo.supabase.co', 'chave'),
        )
        ..lerDoServidor = (() async => noServidor)
        ..gravarNoServidor = ((a, quando) async {
          aoGravar?.call(a, quando);
          return devolveAoGravar ?? linha(a);
        });

  // ───────────────────────────────────────────────────────────────────────────
  group('a fronteira: o painel saiu do instantâneo', () {
    test('o painel não vai no payload que sobe ao instantâneo', () async {
      // Este teste é o inverso do que aqui esteve. Enquanto o painel viajava na
      // ficha, a chave tinha de lá estar; agora, se ela voltar, é porque alguém
      // reabriu a porta que a Fase 3 fechou.
      final repo = await repositorio();
      repo.savePainel(arranjo);

      final payload =
          jsonDecode(repo.exportarFichaDaEmpresa()) as Map<String, dynamic>;

      expect(
        payload.containsKey('painel'),
        isFalse,
        reason: 'o painel tem tabela própria — não anda à boleia da ficha',
      );
      // E a ficha continua a levar o que é dela.
      expect(payload.keys, containsAll(['onboarding', 'historicalMonths']));
    });

    test('marcar um KPI não põe a ficha da empresa por subir', () async {
      final repo = await repositorio();
      expect(repo.hasPendingRemoteChanges, isFalse);

      repo.savePainel(arranjo);

      // Antes ficava `true`, e a ficha inteira subia atrás de uma caixa
      // marcada. A revisão avançava para todos os outros aparelhos.
      expect(repo.hasPendingRemoteChanges, isFalse);
      // Mas o canal do painel tem de saber que há coisa para entregar.
      expect(repo.painelPorSubir, isTrue);
      expect(repo.painelArrumadoEm, isNotNull);
    });

    test('gravar uma máquina não põe o painel a subir', () async {
      // A divisão dos canais ao contrário: o trabalho de terreno sobe pela fila
      // de operações, e não pode arrastar nem a ficha nem o painel.
      final repo = await repositorio();
      repo.saveMachine(
        const Machine(
          id: 'm9',
          name: 'Giratória',
          reference: 'GIR-09',
          category: 'Escavação',
          status: MachineStatus.available,
        ),
      );

      expect(repo.hasPendingRemoteChanges, isFalse);
      expect(repo.painelPorSubir, isFalse);
    });

    test('um instantâneo que ainda traga `painel` não manda no painel', () async {
      // O que está no servidor foi escrito por versões anteriores à Fase 3, e
      // algumas levam a chave. Deixá-la entrar por aqui era pôr um payload
      // velho a mandar num canal que já não é dele.
      final repo = await repositorio();
      repo.savePainel(arranjo);
      repo.marcarPainelSincronizado();

      repo.importarFichaDaEmpresa(
        jsonEncode({
          'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
          'painel': {
            'ordem': ['ticket-medio-mes'],
            'escolhidos': ['ticket-medio-mes'],
          },
        }),
        revision: 7,
      );

      expect(repo.painel, arranjo);
      expect(repo.onboarding?.companyName, 'Terraforte');
    });

    test('importar a ficha não deixa nada por subir', () async {
      // Isto foi, durante uma semana, `_hasPendingRemoteChanges =
      // _painelPorSubir`: o painel obrigava a ficha a subir logo a seguir a
      // descer. Já não há razão nenhuma para isso.
      final repo = await repositorio();
      repo.savePainel(arranjo);

      repo.importarFichaDaEmpresa(
        jsonEncode({
          'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
        }),
        revision: 7,
      );

      expect(repo.hasPendingRemoteChanges, isFalse);
      // O painel, esse, continua à espera da vez dele — no canal dele.
      expect(repo.painelPorSubir, isTrue);
      expect(repo.painel, arranjo);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('o que o aparelho guarda', () {
    test('o painel sobrevive a fechar e abrir a app', () async {
      SharedPreferences.setMockInitialValues({});
      final primeiro = await PersistentOperationRepository.create();
      primeiro.savePainel(arranjo);

      final segundo = await PersistentOperationRepository.create();
      expect(segundo.painel, arranjo);
    });

    test('arrumar e fechar a app antes de haver rede não perde nada', () async {
      SharedPreferences.setMockInitialValues({});
      final primeiro = await PersistentOperationRepository.create();
      primeiro.savePainel(arranjo);
      final carimbo = primeiro.painelArrumadoEm;

      final segundo = await PersistentOperationRepository.create();

      expect(segundo.painel, arranjo);
      expect(segundo.painelPorSubir, isTrue);
      // O carimbo tem de atravessar o arranque. Reconstruí-lo aqui dava-lhe a
      // hora errada — a de abrir a app, não a de arrumar — e mandava este
      // aparelho ganhar uma disputa que devia perder.
      expect(segundo.painelArrumadoEm, carimbo);
    });

    test('recomeçar do zero leva o painel com ele', () async {
      final repo = await repositorio();
      repo.savePainel(arranjo);

      repo.resetAll();

      expect(repo.painel, ArranjoDoPainel.vazio);
      expect(repo.painelPorSubir, isFalse);
      expect(repo.painelArrumadoEm, isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('o canal do painel', () {
    test('o painel que está no servidor chega ao aparelho', () async {
      final repo = await repositorio();

      final r = await canal(repo, noServidor: linha(doOutro)).sincronizar();

      expect(r.correu, isTrue);
      expect(r.mudouAqui, isTrue);
      expect(repo.painel.noPainel, ['ticket-medio-mes']);
    });

    test('sem novidade no servidor, ninguém reconstrói o ecrã', () async {
      final repo = await repositorio();
      repo.savePainel(doOutro);
      repo.marcarPainelSincronizado();

      final r = await canal(repo, noServidor: linha(doOutro)).sincronizar();

      expect(r.correu, isTrue);
      expect(r.mudouAqui, isFalse);
    });

    test('ausente não é vazio: sem linha, o painel local fica', () async {
      // Não haver linha em `punho_painel` não é a empresa a dizer "não escolheu
      // nada" — é ela calada. Ler esse silêncio como vazio apagava a arrumação
      // do gestor sem erro nenhum à vista.
      final repo = await repositorio();
      repo.savePainel(arranjo);
      repo.marcarPainelSincronizado();

      await canal(repo, noServidor: null).sincronizar();

      expect(repo.painel, arranjo);
    });

    test('esvaziar de propósito continua a chegar aos outros', () async {
      // A outra metade: a linha existe, com as listas vazias. Aí é escolha
      // dele, e tem de valer.
      final repo = await repositorio();
      repo.savePainel(arranjo);
      repo.marcarPainelSincronizado();

      await canal(
        repo,
        noServidor: linha(ArranjoDoPainel.vazio),
      ).sincronizar();

      expect(repo.painel, ArranjoDoPainel.vazio);
    });

    group('a janela entre arrumar e sincronizar', () {
      test('a arrumação deste aparelho sobe, e não é atropelada', () async {
        // O caso concreto: marca-se uma caixa, e antes de haver ciclo de
        // sincronização outra pessoa mexe. Com o painel no instantâneo, a
        // revisão avançava e a arrumação ia-se calada.
        final repo = await repositorio();
        repo.savePainel(arranjo);

        ArranjoDoPainel? enviado;
        final r = await canal(
          repo,
          noServidor: linha(doOutro),
          aoGravar: (a, _) => enviado = a,
        ).sincronizar();

        expect(enviado, arranjo, reason: 'subiu o que ele arrumou');
        expect(r.subiu, isTrue);
        expect(repo.painel, arranjo);
        expect(repo.painelPorSubir, isFalse);
      });

      test('o carimbo que sobe é o de quando arrumou', () async {
        final repo = await repositorio();
        repo.savePainel(arranjo);
        final arrumouAs = repo.painelArrumadoEm!;

        DateTime? carimbo;
        await canal(repo, aoGravar: (_, q) => carimbo = q).sincronizar();

        // Não a hora de agora: um telemóvel que esteve a manhã sem rede não
        // pode chegar às duas da tarde e desfazer o que outra pessoa arrumou ao
        // meio-dia.
        expect(carimbo, arrumouAs);
      });

      test('quem chega tarde fica com o que já lá estava', () async {
        // A guarda de ordem barrou a escrita e a função devolveu **a linha como
        // ficou**, que é a de outra pessoa. Quem chama tem de olhar para o que
        // voltou, e não presumir que ganhou.
        final repo = await repositorio();
        repo.savePainel(arranjo);

        final r = await canal(
          repo,
          devolveAoGravar: linha(doOutro, revision: 9),
        ).sincronizar();

        expect(r.subiu, isFalse, reason: 'a guarda barrou-nos');
        expect(r.mudouAqui, isTrue);
        expect(repo.painel, doOutro);
        // E não fica a insistir: insistir era voltar a tentar perder.
        expect(repo.painelPorSubir, isFalse);
      });

      test('depois de subir, o painel do servidor volta a mandar', () async {
        final repo = await repositorio();
        repo.savePainel(arranjo);
        repo.marcarPainelSincronizado();

        await canal(repo, noServidor: linha(doOutro)).sincronizar();

        // Já teve a vez dele. Daqui em diante é de quem escreveu por último,
        // que é a regra normal de uma preferência partilhada pela empresa.
        expect(repo.painel.noPainel, ['ticket-medio-mes']);
      });
    });

    test('tabela vazia e painel no disco: a semente sobe', () async {
      // `punho_painel` nasceu vazia. Um gestor que já tivesse o painel arrumado
      // tinha-o só em disco e sem marca nenhuma por subir — o canal antigo já o
      // dera por entregue. Sem esta regra ficava com o painel no telemóvel dele
      // e vazio em todos os outros, que é o que a tabela veio resolver.
      SharedPreferences.setMockInitialValues({});
      final primeiro = await PersistentOperationRepository.create();
      primeiro.savePainel(arranjo);
      primeiro.marcarPainelSincronizado();

      final repo = await PersistentOperationRepository.create();
      expect(repo.painelPorSubir, isFalse, reason: 'nada por subir, e ainda assim');

      ArranjoDoPainel? enviado;
      await canal(
        repo,
        noServidor: null,
        aoGravar: (a, _) => enviado = a,
      ).sincronizar();

      expect(enviado, arranjo);
    });

    test('tabela vazia e painel vazio: não se escreve nada', () async {
      final repo = await repositorio();

      var gravou = false;
      final r = await canal(
        repo,
        noServidor: null,
        aoGravar: (_, _) => gravou = true,
      ).sincronizar();

      expect(gravou, isFalse);
      expect(r.correu, isTrue);
      expect(r.mudouAqui, isFalse);
    });

    test('sem rede, fica por entregar e tenta-se na volta seguinte', () async {
      final repo = await repositorio();
      repo.savePainel(arranjo);

      final r =
          await (SincronizacaoDoPainel(
                repositorio: repo,
                cliente: SupabaseClient('https://exemplo.supabase.co', 'chave'),
              )..lerDoServidor = (() async => throw const SocketExceptionFalsa()))
              .sincronizar();

      expect(r.correu, isFalse);
      expect(r.erro, isNotNull);
      // O que interessa: a arrumação continua à espera. Dá-la por entregue
      // porque a rede falhou era perdê-la em silêncio.
      expect(repo.painelPorSubir, isTrue);
      expect(repo.painel, arranjo);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Os testes acima põem duplos no lugar das duas idas à rede, e por isso
  // provam a política — mas saltam por cima do pedido verdadeiro. Este grupo
  // não o salta: deixa o `SupabaseClient` construí-lo e vai lê-lo.
  group('o pedido que sai mesmo para a rede', () {
    late _ClienteQueAnota fio;
    late PersistentOperationRepository repo;
    late SincronizacaoDoPainel sync;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = await PersistentOperationRepository.create();
      fio = _ClienteQueAnota();
      sync = SincronizacaoDoPainel(
        repositorio: repo,
        cliente: SupabaseClient(
          'https://exemplo.supabase.co',
          'chave',
          httpClient: fio,
        ),
      );
    });

    test('a subida vai pela função, com o carimbo de quem arrumou', () async {
      repo.savePainel(arranjo);
      final arrumouAs = repo.painelArrumadoEm!;

      await sync.sincronizar();

      // Pela função e não por um upsert do PostgREST: a guarda de ordem precisa
      // de um `where`, e um upsert não o tem.
      expect(fio.url!.path, endsWith('/rest/v1/rpc/punho_painel_gravar'));

      final corpo = jsonDecode(fio.corpo!) as Map<String, dynamic>;
      expect(corpo['p_updated_at'], arrumouAs.toIso8601String());
      expect(
        (corpo['p_dados'] as Map)['escolhidos'],
        containsAll(['caixa', 'entradas-mes']),
      );
    });

    test('a leitura vai à tabela do painel, e sem dizer de que empresa', () async {
      await sync.sincronizar();

      expect(fio.url!.path, endsWith('/rest/v1/punho_painel'));
      // A empresa sai de `punho_empresa_atual()` e da RLS. Um identificador que
      // o cliente enviasse era mais uma coisa que ele podia enviar errada.
      expect(fio.url!.query, isNot(contains('empresa_id')));
    });
  });
}

/// Uma falha de rede qualquer, sem depender de `dart:io` num teste que corre
/// na VM e no browser.
class SocketExceptionFalsa implements Exception {
  const SocketExceptionFalsa();
  @override
  String toString() => 'sem rede';
}

/// Não fala com ninguém: anota o que saiu e devolve uma linha vazia.
class _ClienteQueAnota extends http.BaseClient {
  Uri? url;
  String? corpo;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    url = request.url;
    if (request is http.Request) corpo = request.body;
    return http.StreamedResponse(
      // `null` é o que o PostgREST devolve a um `maybeSingle` sem linha, e o
      // que a função devolveria se não houvesse nada para devolver.
      Stream.value(utf8.encode('null')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
