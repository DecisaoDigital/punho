import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/conflito_pendente.dart';

/// Espelho local dos conflitos pendentes.
///
/// Diferente da `RegistoDeOperacoes`: aqui não há fila de eventos a crescer
/// sem limite — o número de disputas reais por máquina é pequeno por
/// natureza, por isso guarda-se o conjunto inteiro (por `id`) em vez de um
/// cursor incremental.
class RegistoDeConflitos {
  RegistoDeConflitos(this._prefs);

  final SharedPreferences _prefs;

  static const _kConflitos = 'punho_conflitos.registo_v1';
  static const _kPorEnviar = 'punho_conflitos.por_enviar_v1';

  Map<String, ConflitoPendente> get _todosPorId {
    final cru = _prefs.getStringList(_kConflitos) ?? const [];
    final mapa = <String, ConflitoPendente>{};
    for (final linha in cru) {
      try {
        final conflito = ConflitoPendente.daFila(
          Map<String, dynamic>.from(jsonDecode(linha) as Map),
        );
        mapa[conflito.id] = conflito;
      } catch (erro) {
        // Uma linha corrompida não pode bloquear o registo inteiro.
        debugPrint('[Conflitos] linha ilegível, ignorada: $erro');
      }
    }
    return mapa;
  }

  List<ConflitoPendente> get todos => _todosPorId.values.toList();

  List<ConflitoPendente> get pendentes =>
      todos.where((c) => c.estado == EstadoConflito.pendente).toList();

  ConflitoPendente? porId(String id) => _todosPorId[id];

  /// Escritas em fila indiana — mesmo motivo do `RegistoDeOperacoes`: sem
  /// isto, duas gravações a milissegundos de intervalo liam o mesmo estado
  /// antigo e a segunda apagava a primeira.
  Future<void> _emFila = Future.value();

  Future<void> esperarEscritas() => _emFila;

  /// Guarda um conflito detectado ou resolvido **neste** aparelho — fica
  /// marcado para subir na próxima sincronização.
  Future<void> guardarLocal(ConflitoPendente conflito) =>
      _guardar(conflito, marcarParaEnvio: true);

  /// Aplica um conflito recebido do servidor — nunca marca para reenviar,
  /// senão era eco sem fim entre dois aparelhos.
  Future<void> aplicarRemoto(ConflitoPendente conflito) =>
      _guardar(conflito, marcarParaEnvio: false);

  Future<void> _guardar(
    ConflitoPendente conflito, {
    required bool marcarParaEnvio,
  }) {
    _emFila = _emFila.then((_) async {
      final mapa = _todosPorId;
      final existente = mapa[conflito.id];
      // Nunca reabre um conflito já resolvido. Sem isto, uma reserva antiga
      // reaplicada (`carregarTudoParaFila`, correndo histórico, ou uma
      // reentrega de rede) ressuscitava uma disputa que o Gestor já tinha
      // fechado.
      if (existente != null && existente.estado == EstadoConflito.resolvido) {
        return;
      }
      mapa[conflito.id] = conflito;
      await _prefs.setStringList(
        _kConflitos,
        mapa.values.map((c) => jsonEncode(c.paraFila())).toList(),
      );
      if (marcarParaEnvio) {
        final porEnviar =
            (_prefs.getStringList(_kPorEnviar) ?? <String>[]).toSet()
              ..add(conflito.id);
        await _prefs.setStringList(_kPorEnviar, porEnviar.toList());
      }
    });
    return _emFila;
  }

  List<ConflitoPendente> get porEnviar {
    final ids = (_prefs.getStringList(_kPorEnviar) ?? const []).toSet();
    final mapa = _todosPorId;
    return [
      for (final id in ids)
        if (mapa[id] != null) mapa[id]!,
    ];
  }

  Future<void> marcarEnviados(Set<String> ids) {
    if (ids.isEmpty) return Future.value();
    _emFila = _emFila.then((_) async {
      final porEnviar = (_prefs.getStringList(_kPorEnviar) ?? const <String>[])
          .where((id) => !ids.contains(id))
          .toList();
      await _prefs.setStringList(_kPorEnviar, porEnviar);
    });
    return _emFila;
  }

  Future<void> limpar() async {
    await _prefs.remove(_kConflitos);
    await _prefs.remove(_kPorEnviar);
  }
}
