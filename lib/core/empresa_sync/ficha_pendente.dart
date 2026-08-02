import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A ficha da empresa à espera de o servidor confirmar — sempre a mais
/// recente, nunca uma fila.
///
/// Ao contrário da fila de operações ([RegistoDeOperacoes], em
/// `core/sync/registo_de_operacoes.dart`), aqui não faz sentido acumular: a
/// ficha é um estado ("como é a empresa agora"), não um histórico de eventos.
/// Se o gestor mexe duas vezes antes de haver rede, o que interessa enviar é a
/// versão mais recente — a anterior já não descreve a empresa, e reenviá-la
/// primeiro só atrasava a que importa.
class FichaEmpresaPendente {
  FichaEmpresaPendente(this._prefs);

  final SharedPreferences _prefs;

  static const _kFicha = 'punho_empresa_sync.pendente_v1';

  /// A última ficha ainda por confirmar, ou `null` se não houver nenhuma — ou
  /// se a que estiver gravada estiver corrompida (uma linha ilegível conta
  /// como nenhuma: fica-se sem enviar nada até a próxima alteração gravar por
  /// cima).
  Map<String, dynamic>? get ficha {
    final cru = _prefs.getString(_kFicha);
    if (cru == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(cru) as Map);
    } catch (erro) {
      debugPrint('[EmpresaSync] ficha pendente ilegível, ignorada: $erro');
      return null;
    }
  }

  /// Substitui o que estava — nunca acrescenta. Sobrevive a fechar a app,
  /// porque vive em [SharedPreferences] e não só em memória.
  Future<void> guardar(Map<String, dynamic> ficha) =>
      _prefs.setString(_kFicha, jsonEncode(ficha));

  /// O servidor confirmou a recepção: já não há nada por enviar.
  Future<void> limpar() => _prefs.remove(_kFicha);
}
