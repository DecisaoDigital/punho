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

  Future<void> acrescentar(OperacaoPendente operacao) async {
    final fila = _prefs.getStringList(_kFila) ?? <String>[];
    fila.add(jsonEncode(operacao.paraFila()));
    if (fila.length > maximoNaFila) {
      fila.removeRange(0, fila.length - maximoNaFila);
      debugPrint('[Sync] fila cheia — descartadas as mais antigas');
    }
    await _prefs.setStringList(_kFila, fila);
  }

  /// Remove as que já foram aceites pelo servidor.
  Future<void> remover(Set<String> ids) async {
    if (ids.isEmpty) return;
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
  }

  Future<void> limpar() async {
    await _prefs.remove(_kFila);
    await _prefs.remove(_kCursor);
  }
}
