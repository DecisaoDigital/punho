import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma alteração local à espera de ser enviada.
///
/// O `id` é gerado no telemóvel, e não pelo servidor, para a operação poder
/// esperar em fila sem rede e ser reenviada sem risco de entrar duas vezes — a
/// tabela tem `unique (id)`.
class OperacaoPendente {
  const OperacaoPendente({
    required this.id,
    required this.entidade,
    required this.entidadeId,
    required this.payload,
    required this.feitoEm,
  });

  final String id, entidade, entidadeId;
  final Map<String, Object?> payload;
  final DateTime feitoEm;

  Map<String, Object?> paraFila() => {
    'id': id,
    'entidade': entidade,
    'entidade_id': entidadeId,
    'payload': payload,
    'feito_em': feitoEm.toUtc().toIso8601String(),
  };

  factory OperacaoPendente.daFila(Map<String, dynamic> json) =>
      OperacaoPendente(
        id: json['id'] as String,
        entidade: json['entidade'] as String,
        entidadeId: json['entidade_id'] as String,
        payload: Map<String, Object?>.from(json['payload'] as Map),
        // `toLocal` de propósito: guarda-se em UTC (é o que o servidor
        // entende) mas quem lê cá dentro trabalha na hora do telemóvel. Sem
        // isto, o mesmo instante voltava como um `DateTime` diferente do que
        // entrou.
        feitoEm:
            DateTime.tryParse(json['feito_em'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

/// Uma operação que o servidor recusou por ser inválida, e o motivo.
///
/// Não volta à fila: já se sabe que nunca vai ser aceite. Fica aqui para
/// alguém poder ver o que se perdeu e porquê — em vez de desaparecer, ou de
/// ficar a bater à porta do servidor para sempre.
class OperacaoRecusada {
  const OperacaoRecusada({
    required this.operacao,
    required this.motivo,
    required this.recusadaEm,
    this.codigo,
    this.mensagemDoServidor,
  });

  final OperacaoPendente operacao;
  final String motivo;
  final DateTime recusadaEm;

  /// O SQLSTATE, quando houve um (`23514`, `42501`, `P0001`…).
  final String? codigo;

  /// **A frase do servidor, tal como ele a disse.** Guardada à parte para a
  /// Fase 5 a poder mostrar — as mensagens do Punho estão escritas em português
  /// e para uma pessoa («Não podes alterar o preço por dia da máquina»), e
  /// deitá-las fora deixava o utilizador a olhar para um código.
  ///
  /// Nulo nas linhas gravadas antes de este campo existir; aí o [motivo] serve.
  final String? mensagemDoServidor;

  /// O que se mostra a quem está a usar a app.
  String get paraPessoa => mensagemDoServidor ?? motivo;

  Map<String, Object?> paraFila() => {
    'operacao': operacao.paraFila(),
    'motivo': motivo,
    if (codigo != null) 'codigo': codigo,
    if (mensagemDoServidor != null) 'mensagem': mensagemDoServidor,
    'recusada_em': recusadaEm.toUtc().toIso8601String(),
  };

  factory OperacaoRecusada.daFila(Map<String, dynamic> json) =>
      OperacaoRecusada(
        operacao: OperacaoPendente.daFila(
          Map<String, dynamic>.from(json['operacao'] as Map),
        ),
        motivo: json['motivo'] as String? ?? 'sem motivo registado',
        codigo: json['codigo'] as String?,
        mensagemDoServidor: json['mensagem'] as String?,
        recusadaEm:
            DateTime.tryParse(
              json['recusada_em'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
      );
}

/// A fila de saída e o cursor de leitura, guardados no telemóvel.
///
/// **A fila é o que torna a app utilizável sem rede.** Numa obra ou num
/// estaleiro não há sinal, e o trabalho não pode ficar à espera dele: regista-se
/// localmente, e sai quando houver ligação.
///
/// O cursor é o último `seq` aplicado. Guardá-lo evita voltar a puxar o
/// histórico inteiro a cada arranque — e, como o `seq` é atribuído pelo
/// servidor, não depende dos relógios dos telemóveis, que andam
/// dessincronizados entre si.
class RegistoDeOperacoes {
  RegistoDeOperacoes(this._prefs);

  final SharedPreferences _prefs;

  static const _kFila = 'punho_sync.fila_v1';

  /// Subir este número faz **cada** aparelho reler o histórico do princípio,
  /// uma vez. Não é higiene, é reparação — e por isso só se sobe com um estrago
  /// concreto para desfazer.
  ///
  /// Corrigir o código nunca chega, e a razão é sempre a mesma: o cursor
  /// guardado continua a apontar para onde apontava, e o estado errado continua
  /// gravado no telemóvel. Só a releitura os desfaz aos dois.
  ///
  /// * **v2**, 4 de Agosto de 2026 — a leitura vinha do servidor por ordem
  ///   descendente (ver [prepararLote]): cursor parado quase no princípio, e
  ///   entidades com o estado mais **antigo** por cima do mais recente.
  /// * **v3**, no mesmo dia — a consulta nunca usava o cursor (ver `_receber`).
  ///   Cada volta reaplicava o histórico inteiro por cima do presente, e os
  ///   aparelhos que já tinham corrido a v2 ficaram com o cursor no fim e o
  ///   estado desfeito na mesma: uma reserva entregue voltava a "confirmada" e
  ///   lá ficava, com o servidor a dizer o contrário.
  ///
  /// Custa uma leitura do histórico da empresa, uma só vez, em lotes de 500.
  static const _kCursor = 'punho_sync.cursor_v3';
  static const _kDispositivo = 'punho_sync.dispositivo_v1';
  static const _kPerdidas = 'punho_sync.operacoes_perdidas_v1';
  static const _kQuarentena = 'punho_sync.quarentena_v1';
  static const _kConflitos = 'punho_sync.conflitos_reserva_v1';

  /// Limite de segurança da fila.
  ///
  /// Sem ele, meses sem rede encheriam o armazenamento do telemóvel. Ao chegar
  /// aqui **comprime-se primeiro** ([_comprimida]), que não perde nada; só se
  /// ainda assim não couber é que se descarta — e aí fica registado em
  /// [operacoesPerdidas], porque trabalho de um empresário a desaparecer sem
  /// ninguém saber é a pior coisa que esta fila pode fazer.
  static const maximoNaFila = 2000;

  /// Quantas operações esta app já deitou fora por não caberem na fila.
  ///
  /// Persiste entre arranques de propósito: é uma dívida, não um aviso de
  /// momento. Enquanto for > 0, houve trabalho registado no telemóvel que
  /// nunca chegou ao servidor.
  int get operacoesPerdidas => _prefs.getInt(_kPerdidas) ?? 0;

  /// Chamar quando a perda já tiver sido mostrada e reconhecida.
  Future<void> esquecerPerdas() => _prefs.remove(_kPerdidas);

  /// Operações que o servidor recusou por serem inválidas.
  ///
  /// Uma recusa destas é definitiva: insistir só prende a fila. Foi o que
  /// aconteceu à ficha de empresa com NIF inválido — reenviada de 20 em 20
  /// minutos, indefinidamente, sem ninguém ver o erro.
  List<OperacaoRecusada> get quarentena {
    final cru = _prefs.getStringList(_kQuarentena) ?? const [];
    final resultado = <OperacaoRecusada>[];
    for (final linha in cru) {
      try {
        resultado.add(
          OperacaoRecusada.daFila(
            Map<String, dynamic>.from(jsonDecode(linha) as Map),
          ),
        );
      } catch (erro) {
        debugPrint('[Sync] linha da quarentena ilegível, ignorada: $erro');
      }
    }
    return resultado;
  }

  /// [codigo] e [mensagemDoServidor] guardam-se **à parte** do [motivo], que é
  /// os dois colados. É o que permite mostrar a frase do servidor a quem está a
  /// usar a app sem lhe pôr um SQLSTATE à frente dos olhos.
  Future<void> porEmQuarentena(
    OperacaoPendente operacao,
    String motivo, {
    String? codigo,
    String? mensagemDoServidor,
  }) {
    _emFila = _emFila.then((_) async {
      final actual = _prefs.getStringList(_kQuarentena) ?? <String>[];
      actual.add(
        jsonEncode(
          OperacaoRecusada(
            operacao: operacao,
            motivo: motivo,
            codigo: codigo,
            mensagemDoServidor: mensagemDoServidor,
            recusadaEm: DateTime.now(),
          ).paraFila(),
        ),
      );
      // Tecto próprio: a quarentena é para ser vista, não para crescer sem
      // fim. Se houver muitas, as primeiras chegam para perceber o padrão.
      if (actual.length > 100) actual.removeRange(0, actual.length - 100);
      await _prefs.setStringList(_kQuarentena, actual);
    });
    return _emFila;
  }

  Future<void> limparQuarentena() => _prefs.remove(_kQuarentena);

  /// Conflitos de reserva que o servidor barrou (`23P01`): a máquina já estava
  /// ocupada nesse período. Ao contrário da [quarentena], **não é lixo** — é
  /// uma decisão de negócio à espera de uma pessoa. Fica à parte, visível, para
  /// o gestor resolver (remarcar, recusar), e nunca prende a fila enquanto
  /// espera. Mesmo tecto de 100 e mesma durabilidade da quarentena.
  List<OperacaoRecusada> get conflitosDeReserva {
    final cru = _prefs.getStringList(_kConflitos) ?? const [];
    final resultado = <OperacaoRecusada>[];
    for (final linha in cru) {
      try {
        resultado.add(
          OperacaoRecusada.daFila(
            Map<String, dynamic>.from(jsonDecode(linha) as Map),
          ),
        );
      } catch (erro) {
        debugPrint('[Sync] linha de conflito ilegível, ignorada: $erro');
      }
    }
    return resultado;
  }

  Future<void> porEmConflitoDeReserva(
    OperacaoPendente operacao,
    String motivo,
  ) {
    _emFila = _emFila.then((_) async {
      final actual = _prefs.getStringList(_kConflitos) ?? <String>[];
      actual.add(
        jsonEncode(
          OperacaoRecusada(
            operacao: operacao,
            motivo: motivo,
            recusadaEm: DateTime.now(),
          ).paraFila(),
        ),
      );
      if (actual.length > 100) actual.removeRange(0, actual.length - 100);
      await _prefs.setStringList(_kConflitos, actual);
    });
    return _emFila;
  }

  Future<void> limparConflitosDeReserva() => _prefs.remove(_kConflitos);

  int get cursor => _prefs.getInt(_kCursor) ?? 0;
  Future<void> guardarCursor(int seq) => _prefs.setInt(_kCursor, seq);

  /// Identificador estável deste telemóvel, para ignorar o eco do que foi ele
  /// próprio a enviar.
  String get dispositivo {
    final guardado = _prefs.getString(_kDispositivo);
    if (guardado != null) return guardado;
    final novo = 'd${DateTime.now().microsecondsSinceEpoch}';
    unawaitedSet(_kDispositivo, novo);
    return novo;
  }

  @protected
  void unawaitedSet(String chave, String valor) {
    _prefs.setString(chave, valor);
  }

  List<OperacaoPendente> get pendentes {
    final cru = _prefs.getStringList(_kFila) ?? const [];
    final resultado = <OperacaoPendente>[];
    for (final linha in cru) {
      try {
        resultado.add(
          OperacaoPendente.daFila(
            Map<String, dynamic>.from(jsonDecode(linha) as Map),
          ),
        );
      } catch (erro) {
        // Uma linha corrompida não pode bloquear a fila inteira.
        debugPrint('[Sync] linha da fila ilegível, ignorada: $erro');
      }
    }
    return resultado;
  }

  /// Escritas em fila indiana.
  ///
  /// Sem isto, gravar várias entidades de seguida perdia quase todas: cada
  /// chamada lê a lista, acrescenta a sua e escreve — e como quem chama não
  /// espera pelo resultado, onze chamadas ao mesmo tempo liam **a mesma** lista
  /// e escreviam por cima umas das outras. Sobrava a última.
  ///
  /// Não é hipótese: aconteceu na primeira carga inicial a sério, com 11
  /// entidades enfileiradas e nenhuma a chegar ao servidor.
  Future<void> _emFila = Future.value();

  Future<void> acrescentar(OperacaoPendente operacao) =>
      acrescentarVarias([operacao]);

  /// Espera que todas as escritas pendentes na fila indiana terminem.
  ///
  /// Quem enfileira à solta (o `aoRegistarOperacao` do repositório não espera
  /// por nada) precisa disto antes de ler `pendentes`, senão lê uma fila que
  /// ainda não foi gravada.
  Future<void> esperarEscritas() => _emFila;

  /// Acrescenta várias de uma vez — uma só leitura e uma só escrita.
  Future<void> acrescentarVarias(List<OperacaoPendente> operacoes) {
    if (operacoes.isEmpty) return Future.value();
    _emFila = _emFila.then((_) async {
      var fila = _prefs.getStringList(_kFila) ?? <String>[];
      for (final operacao in operacoes) {
        fila.add(jsonEncode(operacao.paraFila()));
      }
      // Comprimir antes de descartar. Quem esteve um mês na obra sem rede tem
      // a fila cheia de versões sucessivas das mesmas poucas entidades, não de
      // milhares de entidades diferentes — e dessas só a última interessa.
      if (fila.length > maximoNaFila) fila = _comprimida(fila);
      if (fila.length > maximoNaFila) {
        final perdidas = fila.length - maximoNaFila;
        fila.removeRange(0, perdidas);
        await _prefs.setInt(_kPerdidas, operacoesPerdidas + perdidas);
        debugPrint(
          '[Sync] fila cheia mesmo depois de comprimir — '
          '$perdidas operações descartadas',
        );
      }
      await _prefs.setStringList(_kFila, fila);
    });
    return _emFila;
  }

  /// Reduz a fila ao que ainda diz alguma coisa: por entidade, só a última.
  ///
  /// Cada `payload` é o **estado completo** da entidade e não um delta — a
  /// última gravação de uma máquina contém tudo o que as anteriores diziam.
  /// Corrigir o preço da mesma máquina trinta vezes offline põe trinta linhas
  /// na fila, e vinte e nove são história que o servidor nunca precisa de ver.
  ///
  /// A ordem é a da **primeira** aparição de cada entidade, não a da última:
  /// se o cliente foi criado antes da reserva que o refere, tem de continuar a
  /// sair primeiro, senão o servidor recebe uma reserva órfã.
  static List<String> _comprimida(List<String> fila) {
    final ultima = <String, String>{};
    final ordem = <String>[];
    for (final linha in fila) {
      final String chave;
      try {
        final json = Map<String, dynamic>.from(jsonDecode(linha) as Map);
        chave = '${json['entidade']}:${json['entidade_id']}';
      } catch (_) {
        // Ilegível: nunca seria enviada nem lida (ver `pendentes`). Sai aqui,
        // que é o único sítio onde a podemos varrer sem custo.
        continue;
      }
      if (!ultima.containsKey(chave)) ordem.add(chave);
      ultima[chave] = linha;
    }
    return [for (final chave in ordem) ultima[chave]!];
  }

  /// Remove as que já foram aceites pelo servidor.
  ///
  /// Entra na mesma fila indiana das escritas: remover enquanto se acrescenta
  /// fazia ressuscitar operações já enviadas, ou perder operações novas.
  Future<void> remover(Set<String> ids) {
    if (ids.isEmpty) return Future.value();
    _emFila = _emFila.then((_) async {
      final fila = (_prefs.getStringList(_kFila) ?? const <String>[]).where((
        linha,
      ) {
        try {
          final json = Map<String, dynamic>.from(jsonDecode(linha) as Map);
          return !ids.contains(json['id']);
        } catch (_) {
          return false;
        }
      }).toList();
      await _prefs.setStringList(_kFila, fila);
    });
    return _emFila;
  }

  /// A carga inicial desta empresa já foi feita neste aparelho?
  ///
  /// Por empresa e não global: quem entra noutra empresa tem de voltar a subir
  /// o que tem, senão os dados ficavam presos na primeira.
  /// `v2` e não `v1`: a primeira versão marcava a carga como feita mesmo
  /// quando as operações se perdiam na corrida de escritas (ver
  /// [acrescentarVarias]). Quem tiver a marca antiga tem de repetir a carga uma
  /// vez, senão os dados ficam presos no aparelho para sempre.
  bool cargaInicialFeita(String empresaId) =>
      _prefs.getBool('punho_sync.carga_inicial_v3.$empresaId') ?? false;

  Future<void> marcarCargaInicialFeita(String empresaId) =>
      _prefs.setBool('punho_sync.carga_inicial_v3.$empresaId', true);

  Future<void> limpar() async {
    await _prefs.remove(_kFila);
    await _prefs.remove(_kCursor);
  }
}
