import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import 'registo_de_operacoes.dart';

/// Um lote de operações pronto a aplicar, e o cursor que fica depois dele.
class LoteDeOperacoes {
  const LoteDeOperacoes({required this.linhas, required this.cursor});

  /// Por `seq` **crescente**: é essa ordem que faz a última escrita ganhar.
  final List<Map<String, dynamic>> linhas;

  /// O maior `seq` visto — não o da última linha da lista.
  final int cursor;
}

/// Põe um lote em ordem e diz onde fica o cursor. Puro, para poder ser testado
/// sem servidor nenhum.
///
/// **Porque existe.** A 4 de Agosto de 2026, num Redmi, um trabalho fechado na
/// app voltava sozinho a "em curso" um segundo depois, e assim ficava mesmo
/// depois de reiniciar — o servidor dizia `completed`, o telemóvel dizia
/// `rented`. A causa era uma palavra que não estava escrita: `.order('seq')`,
/// que no postgrest-dart é **descendente** por omissão. Daí saíam dois estragos
/// de uma vez:
///
/// 1. **A precedência invertia-se.** Aplicando do mais novo para o mais velho,
///    quem ficava por cima era o mais velho — o contrário da regra da casa, que
///    é ganhar a última escrita a chegar ao servidor.
/// 2. **O cursor recuava para o mínimo do lote.** `cursor = seq` a cada volta
///    acabava na linha mais baixa, e não na mais alta: cada sincronização
///    avançava uma linha e voltava a puxar todo o resto. O histórico inteiro era
///    reaplicado de dez em dez segundos, e o que o gestor acabara de fazer
///    desaparecia por baixo dele.
///
/// Ordenar aqui dentro, em vez de confiar na ordem que vier do fio, é de
/// propósito: a regra de precedência é da app, não do cliente HTTP. Se um dia
/// alguém voltar a mexer no `order`, isto continua correcto.
LoteDeOperacoes prepararLote(
  Iterable<Map<String, dynamic>> cruas, {
  required int cursor,
}) {
  int seqDe(Map<String, dynamic> linha) => (linha['seq'] as num).toInt();
  final linhas = cruas.toList()..sort((a, b) => seqDe(a).compareTo(seqDe(b)));
  return LoteDeOperacoes(
    linhas: linhas,
    // `fold` e não `linhas.last`: o cursor é o ponto até onde se leu, e nunca
    // pode recuar — nem por um lote fora de ordem, nem por um lote vazio.
    cursor: linhas.fold(cursor, (maior, linha) {
      final seq = seqDe(linha);
      return seq > maior ? seq : maior;
    }),
  );
}

/// Aplica um lote já ordenado, **sem deixar uma linha má levar o resto atrás**.
///
/// Era o que acontecia: qualquer excepção a meio — um payload escrito por uma
/// versão mais nova da app, um campo que este parser não reconhece, uma
/// referência que já não existe — saltava para fora da leitura, e o
/// `guardarCursor` que vem a seguir **nunca chegava a correr**. O cursor ficava
/// parado, a sincronização seguinte voltava a puxar o mesmo lote, a rebentar na
/// mesma linha e a reaplicar tudo o que vinha antes dela. O aparelho ficava
/// preso no passado, e o que o gestor fizesse era enterrado a cada cinco
/// minutos — que foi exactamente o que se viu no Redmi a 4 de Agosto de 2026.
///
/// A fila de **saída** já tinha aprendido isto: uma operação que o servidor
/// nunca vai aceitar sai da fila em vez de a prender (ver `porEmQuarentena`).
/// Faltava a mesma regra do lado da entrada.
({int aplicadas, int recusadas}) aplicarLinhas(
  PersistentOperationRepository repositorio,
  Iterable<Map<String, dynamic>> linhas,
) {
  var aplicadas = 0;
  var recusadas = 0;
  for (final json in linhas) {
    try {
      repositorio.aplicarOperacaoRemota(
        json['entidade'] as String,
        Map<String, dynamic>.from(json['payload'] as Map),
      );
      aplicadas++;
    } catch (erro) {
      recusadas++;
      debugPrint(
        '[Sync] linha ${json['seq']} '
        '(${json['entidade']}/${json['entidade_id']}) não se aplicou: $erro '
        '— segue-se em frente',
      );
    }
  }
  return (aplicadas: aplicadas, recusadas: recusadas);
}

/// Como correu uma sincronização.
class ResultadoDaSincronizacao {
  const ResultadoDaSincronizacao({
    required this.enviadas,
    required this.recebidas,
    this.erro,
  });

  const ResultadoDaSincronizacao.falhou(String this.erro)
    : enviadas = 0,
      recebidas = 0;

  final int enviadas, recebidas;
  final String? erro;

  bool get correu => erro == null;
  bool get houveMudancas => enviadas > 0 || recebidas > 0;
}

/// Sincronização entre dispositivos, por operações em vez de instantâneos.
///
/// O que existia empurrava o **estado operacional completo** com uma revisão, e
/// detectava conflitos em vez de os resolver. Com um gestor no escritório e um
/// colaborador no terreno — que é o caso de uso da app — um dos dois perdia
/// sempre o trabalho.
///
/// Aqui cada alteração é uma linha só de acrescentar. Duas pessoas a mexer em
/// coisas diferentes não se pisam. Quando é mesmo a mesma entidade, ganha a
/// última a chegar ao servidor: previsível, e a ordem é a dele (`seq`), não a
/// dos relógios dos telemóveis, que andam dessincronizados.
///
/// **Fica de fora, de propósito:** os dados da empresa (onboarding, custos
/// fixos, histórico mensal), que continuam pelo caminho antigo. São editados
/// num sítio só, pelo gestor, e não têm o problema que isto resolve.
class SincronizacaoEntreDispositivos {
  SincronizacaoEntreDispositivos({
    required this.repositorio,
    required this.registo,
    required SupabaseClient cliente,
    required this.empresaId,
  }) : _cliente = cliente;

  final PersistentOperationRepository repositorio;
  final RegistoDeOperacoes registo;
  final SupabaseClient _cliente;
  final String empresaId;

  static const _tabela = 'punho_operacoes';

  /// Quantas operações se puxam de cada vez.
  ///
  /// Um telemóvel que esteve um mês fora não pode tentar trazer tudo numa
  /// resposta só e ficar sem memória a meio.
  static const _lote = 500;

  bool _aCorrer = false;

  /// Põe na fila tudo o que já está no aparelho, **uma vez por empresa**.
  ///
  /// [ouvirAlteracoesLocais] só apanha o que for gravado a partir daqui. Quem
  /// já usava a app antes de haver sincronização — ou antes de entrar numa
  /// empresa — tinha máquinas e clientes no telemóvel que nunca subiriam: não
  /// houve gravação nenhuma depois de a fila existir, portanto não havia nada
  /// para registar. Via os dados no seu aparelho, mais ninguém os via, e não
  /// aparecia erro nenhum.
  ///
  /// Devolve quantas foram enfileiradas (0 se já tinha sido feita).
  Future<int> cargaInicialSePreciso() async {
    if (registo.cargaInicialFeita(empresaId)) return 0;
    final quantas = repositorio.carregarTudoParaFila();
    // Esperar que a fila esteja mesmo gravada antes de seguir: `acrescentar`
    // devolve um future, e sincronizar sem o esperar lia uma fila ainda vazia.
    await registo.esperarEscritas();
    if (quantas > 0) {
      debugPrint('[Sync] carga inicial: $quantas entidades para enviar');
    }
    // A marca NÃO se põe aqui. Põe-se depois de o envio correr bem
    // ([marcarCargaInicialConcluida]) — marcá-la agora e falhar o envio deixava
    // os dados presos no aparelho sem nunca mais haver segunda tentativa. Foi
    // exactamente isso que aconteceu na primeira vez que isto correu a sério.
    return quantas;
  }

  /// Dá a carga inicial por concluída. Só depois de o servidor ter aceite.
  Future<void> marcarCargaInicialConcluida() =>
      registo.marcarCargaInicialFeita(empresaId);

  /// Liga o repositório à fila: cada alteração local passa a ficar registada.
  void ouvirAlteracoesLocais() {
    repositorio.aoRegistarOperacao = (entidade, id, payload) {
      registo.acrescentar(
        OperacaoPendente(
          // Sem colisão entre dispositivos: o id do aparelho entra na chave.
          id: _uuidSimples(),
          entidade: entidade,
          entidadeId: id,
          payload: payload,
          feitoEm: DateTime.now(),
        ),
      );
    };
  }

  /// Envia o que está em fila e traz o que os outros fizeram.
  ///
  /// **Recebe primeiro, envia depois.** Ao contrário, uma operação nossa entrava
  /// com `seq` mais baixo do que uma alheia acabada de chegar e perdia para ela
  /// sem razão — a nossa é que era a mais recente.
  Future<ResultadoDaSincronizacao> sincronizar() async {
    if (_aCorrer) {
      return const ResultadoDaSincronizacao(enviadas: 0, recebidas: 0);
    }
    _aCorrer = true;
    try {
      // A fila é escrita sem ninguém esperar pelo resultado (o repositório
      // chama e segue). Ler `pendentes` antes de as escritas assentarem
      // deixava operações por enviar até à sincronização seguinte.
      await registo.esperarEscritas();
      debugPrint(
        '[Sync] a correr: fila=${registo.pendentes.length} '
        'cursor=${registo.cursor} empresa=$empresaId',
      );
      final recebidas = await _receber();
      final enviadas = await _enviar();
      debugPrint(
        '[Sync] fim: enviadas=$enviadas recebidas=$recebidas '
        'recusadas=$recusadas cursor=${registo.cursor}',
      );
      return ResultadoDaSincronizacao(enviadas: enviadas, recebidas: recebidas);
    } catch (erro) {
      debugPrint('[Sync] falhou: $erro');
      return ResultadoDaSincronizacao.falhou('$erro');
    } finally {
      _aCorrer = false;
    }
  }

  /// Quantas linhas o último [_receber] não conseguiu aplicar. Zero é o normal;
  /// diferente de zero é sinal de que há dados que este aparelho não entende.
  int recusadas = 0;

  /// Vai buscar ao servidor as operações **posteriores** a [depoisDe].
  ///
  /// Isolado num campo para os testes poderem pôr um servidor de mentira no
  /// lugar e verificar o que se lhe pede — que foi precisamente onde o defeito
  /// morava, sem nenhum teste lá chegar.
  Future<List<Map<String, dynamic>>> Function(int depoisDe)? buscarOperacoes;

  Future<List<Map<String, dynamic>>> _buscar(int depoisDe) async {
    if (buscarOperacoes != null) return buscarOperacoes!(depoisDe);
    final linhas =
        await _cliente
                .from(_tabela)
                .select()
                .eq('empresa_id', empresaId)
                // **O cursor tem de entrar aqui.** Ele existia, era calculado e
                // era gravado — e não filtrava nada: a consulta trazia sempre o
                // histórico desde o princípio. Ver [_receber].
                .gt('seq', depoisDe)
                // `ascending: true` **explícito**. O postgrest-dart tem o
                // contrário por omissão (`ascending = false`) — ao contrário
                // do PostgREST e do cliente de JavaScript, onde `order` sem
                // mais nada é crescente. Sem esta palavra, isto trazia o
                // histórico do fim para o princípio, e daí saíam os dois
                // estragos que o [prepararLote] agora também trava por
                // dentro. Ver o comentário lá.
                .order('seq', ascending: true)
                .limit(_lote)
            as List;
    return [
      for (final linha in linhas) Map<String, dynamic>.from(linha as Map),
    ];
  }

  /// Traz o que os outros fizeram **desde a última vez** — e só isso.
  ///
  /// O que aconteceu a 4 de Agosto de 2026, com as três correcções anteriores
  /// já no telemóvel: tocar em *Entregar* gravava `rented`, a operação subia ao
  /// servidor (lá ficou, `seq 234`), e o ecrã continuava a dizer "Confirmado" —
  /// para sempre, mesmo depois de reiniciar a app.
  ///
  /// A causa estava na consulta, não na aplicação das linhas: **o cursor nunca
  /// era usado para filtrar**. Era lido, era passado ao [prepararLote], era
  /// gravado — e a consulta pedia à mesma o histórico todo desde o princípio.
  /// De cinco em cinco minutos, o passado inteiro voltava a ser aplicado por
  /// cima do presente. E como [sincronizar] recebe antes de enviar, a sequência
  /// era esta:
  ///
  /// 1. o gestor toca em *Entregar* → local fica `rented`, e a operação entra
  ///    na fila de saída com esse valor;
  /// 2. chega a sincronização: `_receber` reaplica a linha de origem do
  ///    trabalho (`seq 204`, `confirmed`) e o telemóvel volta atrás;
  /// 3. `_enviar` manda a operação da fila, que continua a dizer `rented`.
  ///
  /// Fim: servidor `rented`, telemóvel `confirmed`, nenhum erro. A app a
  /// desfazer o trabalho de quem a usa e a jurar ao servidor que o fez.
  ///
  /// Havia ainda uma bomba a prazo: com mais de [_lote] operações, `linhas
  /// .length` nunca ficava abaixo do lote, a consulta seguinte era idêntica à
  /// anterior, e o ciclo não acabava nunca.
  @visibleForTesting
  Future<int> receber() => _receber();

  Future<int> _receber() async {
    var aplicadas = 0;
    recusadas = 0;
    var cursor = registo.cursor;
    while (true) {
      final linhas = await _buscar(cursor);
      if (linhas.isEmpty) break;

      final lote = prepararLote(linhas, cursor: cursor);
      // Aplica-se **tudo**, incluindo o que fomos nós a escrever.
      //
      // Antes saltavam-se as linhas do próprio aparelho, com o argumento de que
      // já estavam aplicadas localmente. É verdade enquanto o estado local
      // estiver certo — e deixa de ser no minuto em que não estiver. Foi o que
      // trancou o Redmi: o estado local tinha sido pisado, as únicas linhas que
      // o podiam corrigir eram as nossas, e eram justamente essas que se
      // deitavam fora. A app ficava a divergir do servidor **para sempre**, sem
      // erro nenhum a dizê-lo.
      //
      // Reaplicar é idempotente: a gravação é a mesma, o conflito de reservas
      // tem id determinado pelos dois ids envolvidos (não duplica), e
      // `aplicarOperacaoRemota` não volta a pôr nada na fila.
      //
      // O que isto dá é a **reposição a partir do zero**: pôr o cursor a 0 e
      // deixar correr reconstrói o estado inteiro a partir do servidor, e é
      // assim que um aparelho divergido se endireita (foi o que a subida da
      // chave para `cursor_v2` fez a este). Repare-se no que *não* dá: em marcha
      // normal só entra o que é novo, portanto isto não anda a corrigir
      // sozinho, a cada volta, um estado local que se tenha estragado. Curar
      // exige a releitura; a releitura é decisão de quem sobe a chave.
      final resultado = aplicarLinhas(repositorio, lote.linhas);
      aplicadas += resultado.aplicadas;
      recusadas += resultado.recusadas;
      // Se o lote não fez o cursor andar, a consulta seguinte seria igual a
      // esta e o ciclo não acabava. Não devia acontecer com o `.gt` no sítio —
      // mas um ciclo infinito à volta de uma chamada de rede é caro de mais
      // para se deixar à confiança.
      if (lote.cursor <= cursor) break;
      cursor = lote.cursor;
      // Gravado a cada lote: se a app fechar a meio, retoma daqui em vez de
      // recomeçar do princípio.
      await registo.guardarCursor(cursor);
      if (linhas.length < _lote) break;
    }
    return aplicadas;
  }

  Future<int> _enviar() async {
    final pendentes = registo.pendentes;
    if (pendentes.isEmpty) return 0;
    final utilizador = _cliente.auth.currentUser?.id;
    final linhas = [
      for (final operacao in pendentes)
        {
          'id': operacao.id,
          'empresa_id': empresaId,
          'entidade': operacao.entidade,
          'entidade_id': operacao.entidadeId,
          'payload': operacao.payload,
          'feito_em': operacao.feitoEm.toUtc().toIso8601String(),
          'por_utilizador': utilizador,
          'por_dispositivo': registo.dispositivo,
        },
    ];
    // `upsert` e não `insert`: um reenvio depois de a rede cair a meio não pode
    // duplicar a operação. O `unique (id)` faz o resto.
    try {
      await _cliente.from(_tabela).upsert(linhas, onConflict: 'id');
      await registo.remover(pendentes.map((o) => o.id).toSet());
      return pendentes.length;
    } on PostgrestException catch (erro) {
      if (!ehRecusaDefinitiva(erro.code)) rethrow;
      // Uma operação inválida no meio do lote fazia falhar o lote inteiro, e
      // como nada saía da fila, a app reenviava tudo outra vez a cada ciclo —
      // para sempre, sem ninguém ver o erro. Aqui separa-se o trigo do joio:
      // vai-se uma a uma, as boas passam, e a má fica de lado identificada.
      debugPrint(
        '[Sync] lote recusado (${erro.code}) — a isolar a operação má',
      );
      return _enviarUmaAUma(pendentes, linhas);
    }
  }

  /// O servidor recusou por causa do **conteúdo**, e não por causa da ligação.
  ///
  /// É a distinção que faltava: sem ela, qualquer falha era tratada como "logo
  /// se tenta outra vez", e um payload que nunca ia ser aceite ficava a bater à
  /// porta do servidor indefinidamente.
  ///
  /// `23514` é o que o trigger `punho_operacoes_payload_coerente` levanta para
  /// payload incoerente; `23502`/`23503` são campo obrigatório em falta e
  /// referência inexistente; `22007`/`22P02` são data e número ilegíveis.
  /// Nenhum destes melhora por se insistir. Tudo o resto — timeout, 5xx, sem
  /// rede — fica na fila, que é o que a torna útil numa obra sem sinal.
  static bool ehRecusaDefinitiva(String? codigo) =>
      const {'23514', '23502', '23503', '22007', '22P02'}.contains(codigo);

  /// Envia uma a uma para descobrir qual é a inválida.
  ///
  /// Só corre depois de o lote falhar — o caminho normal continua a ser uma
  /// escrita só.
  Future<int> _enviarUmaAUma(
    List<OperacaoPendente> pendentes,
    List<Map<String, Object?>> linhas,
  ) async {
    var enviadas = 0;
    for (var i = 0; i < pendentes.length; i++) {
      final operacao = pendentes[i];
      try {
        await _cliente.from(_tabela).upsert([linhas[i]], onConflict: 'id');
        await registo.remover({operacao.id});
        enviadas++;
      } on PostgrestException catch (erro) {
        if (!ehRecusaDefinitiva(erro.code)) rethrow;
        // Sai da fila e vai para a quarentena: se ficasse, voltava a prender
        // tudo no ciclo seguinte.
        await registo.porEmQuarentena(
          operacao,
          '${erro.code}: ${erro.message}',
        );
        await registo.remover({operacao.id});
        debugPrint(
          '[Sync] operação ${operacao.entidade}/${operacao.entidadeId} '
          'recusada em definitivo: ${erro.message}',
        );
      }
    }
    return enviadas;
  }

  /// UUID v4 suficiente para chave — não precisa de ser criptográfico, só de
  /// não colidir entre telemóveis.
  String _uuidSimples() {
    final agora = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final aparelho = registo.dispositivo.hashCode
        .toUnsigned(32)
        .toRadixString(16);
    final cauda = identityHashCode(Object()).toUnsigned(32).toRadixString(16);
    final cru = (agora + aparelho + cauda + '0' * 32).substring(0, 32);
    return '${cru.substring(0, 8)}-${cru.substring(8, 12)}-4'
        '${cru.substring(13, 16)}-a${cru.substring(17, 20)}-'
        '${cru.substring(20, 32)}';
  }
}
