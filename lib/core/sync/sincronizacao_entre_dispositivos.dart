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
      final recebidas = await _receber();
      final enviadas = await _enviar();
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
    await _cliente.from(_tabela).upsert(linhas, onConflict: 'id');
    await registo.remover(pendentes.map((o) => o.id).toSet());
    return pendentes.length;
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
