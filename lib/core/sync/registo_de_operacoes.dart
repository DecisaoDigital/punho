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
  static const _kCursor = 'punho_sync.cursor_v1';
  static const _kDispositivo = 'punho_sync.dispositivo_v1';

  /// Limite de segurança da fila.
  ///
  /// Sem ele, meses sem rede encheriam o armazenamento do telemóvel. Ao chegar
  /// aqui descartam-se as **mais antigas**: são as que já foram
  /// provavelmente substituídas por edições posteriores da mesma entidade.
  static const maximoNaFila = 2000;

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
      final fila = _prefs.getStringList(_kFila) ?? <String>[];
      for (final operacao in operacoes) {
        fila.add(jsonEncode(operacao.paraFila()));
      }
      if (fila.length > maximoNaFila) {
        fila.removeRange(0, fila.length - maximoNaFila);
        debugPrint('[Sync] fila cheia — descartadas as mais antigas');
      }
      await _prefs.setStringList(_kFila, fila);
    });
    return _emFila;
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
