import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import 'registo_de_operacoes.dart';

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
      debugPrint('[Sync] fim: enviadas=$enviadas recebidas=$recebidas');
      return ResultadoDaSincronizacao(enviadas: enviadas, recebidas: recebidas);
    } catch (erro) {
      debugPrint('[Sync] falhou: $erro');
      return ResultadoDaSincronizacao.falhou('$erro');
    } finally {
      _aCorrer = false;
    }
  }

  Future<int> _receber() async {
    var aplicadas = 0;
    var cursor = registo.cursor;
    while (true) {
      final linhas =
          await _cliente
                  .from(_tabela)
                  .select()
                  .eq('empresa_id', empresaId)
                  .gt('seq', cursor)
                  .order('seq')
                  .limit(_lote)
              as List;
      if (linhas.isEmpty) break;

      for (final linha in linhas) {
        final json = Map<String, dynamic>.from(linha as Map);
        cursor = (json['seq'] as num).toInt();
        // O que fomos nós a escrever já está aplicado localmente. Reaplicar
        // seria inofensivo, mas desperdício — e num lote grande, visível.
        if (json['por_dispositivo'] == registo.dispositivo) continue;
        repositorio.aplicarOperacaoRemota(
          json['entidade'] as String,
          Map<String, dynamic>.from(json['payload'] as Map),
        );
        aplicadas++;
      }
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
      debugPrint('[Sync] lote recusado (${erro.code}) — a isolar a operação má');
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
