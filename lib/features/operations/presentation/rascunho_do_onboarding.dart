import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que já foi respondido no onboarding e ainda não foi entregue.
///
/// Nasceu de um relato do Cesar a 5 de Agosto de 2026: estava a preencher os
/// dados da empresa, a app saltou-lhe para fora do passo em que ia, e quando
/// voltou **estava tudo vazio** — «os dados nunca foram gravados/enviados para
/// o servidor, estavam todos vazios novamente enquanto deveriam estar
/// preenchidos e permitir alteração».
///
/// Até aqui as respostas viviam só nos `TextEditingController` do `State` do
/// onboarding. Enquanto aquele `State` existisse, tudo bem; morto ele — a app
/// mandada para segundo plano e o processo terminado pelo MIUI, que o faz sem
/// avisar —, as respostas iam com ele. Escrever quinze campos duas vezes não é
/// coisa que se peça a ninguém.
///
/// **Não é gravar o onboarding.** A regra continua a mesma: quem conclui é o
/// botão "Entrar na Punho", e só ele chama `completeOnboarding` e manda a ficha
/// ao servidor. Isto é papel de rascunho, local, e é [limpar]ado no momento em
/// que o onboarding termina — senão a conta seguinte a fazer onboarding neste
/// telemóvel herdava as respostas da anterior.
class RascunhoDoOnboarding {
  RascunhoDoOnboarding(this._prefs);

  final SharedPreferences _prefs;

  static const _chave = 'punho_onboarding.rascunho_v1';

  /// O que estava escrito, ou `null` se não houver rascunho — ou se o que lá
  /// está for ilegível. Um rascunho corrompido conta como nenhum: perde-se o
  /// que lá estava, mas o onboarding abre.
  Map<String, dynamic>? ler() {
    final cru = _prefs.getString(_chave);
    if (cru == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(cru) as Map);
    } catch (erro) {
      debugPrint('[Onboarding] rascunho ilegível, ignorado: $erro');
      return null;
    }
  }

  /// Substitui o que estava. É sempre o estado inteiro, nunca um delta: o que
  /// interessa guardar é "como está o formulário agora".
  Future<void> guardar(Map<String, dynamic> estado) =>
      _prefs.setString(_chave, jsonEncode(estado));

  Future<void> limpar() => _prefs.remove(_chave);
}
