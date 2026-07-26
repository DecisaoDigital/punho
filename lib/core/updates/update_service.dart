import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'update_info.dart';

/// Assinatura da chamada à Edge Function `versao-mais-recente`. Existe para os
/// testes poderem substituir a rede sem precisar de um package de mocking — o
/// mesmo padrão do `PunhoLicencaService`.
typedef InvocarVersao =
    Future<FunctionResponse> Function(
      Map<String, dynamic> corpo,
      Map<String, String>? cabecalhos,
    );

const _timeout = Duration(seconds: 10);

/// Consulta a versão publicada no Control.
///
/// **Não exige sessão iniciada.** A Edge Function está deployed com
/// `verify_jwt: true`, o que exige uma chave válida no header `Authorization`,
/// não um utilizador autenticado: sem sessão o `supabase_flutter` põe lá a
/// chave pública do projecto e o gateway aceita-a (ver `LICENCIAMENTO.md`,
/// secção "Porque é que funciona sem sessão").
///
/// Isto é o que permite avisar de updates a quem está preso no ecrã de login ou
/// bloqueado no `AcessoGate` com o pedido pendente ou recusado — a maioria dos
/// utilizadores nesta fase da app.
class PunhoUpdateService {
  PunhoUpdateService(SupabaseClient client)
    : _client = client,
      _invocar = ((corpo, cabecalhos) => client.functions
          .invoke('versao-mais-recente', body: corpo, headers: cabecalhos)
          .timeout(_timeout));

  /// Para testes: substitui a rede. Sem cliente, portanto sem sessão — é
  /// exactamente o cenário do utilizador que nunca chegou a entrar.
  PunhoUpdateService.comInvocador(this._invocar) : _client = null;

  final SupabaseClient? _client;
  final InvocarVersao _invocar;

  /// Devolve o update a anunciar, ou `null` se não houver — ou se não for
  /// possível saber. Falha em silêncio: um erro de rede no arranque não pode
  /// aparecer ao utilizador.
  Future<PunhoUpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      // Com sessão manda-se o token — deixa a Edge Function saber quem pediu,
      // se um dia isso for útil. Sem sessão não se manda header nenhum.
      final sessao = _client?.auth.currentSession;
      final resposta = await _invocar(
        {
          'app': 'punho',
          'plataforma': _platform,
          'build_number_local': build,
        },
        sessao == null
            ? null
            : {'Authorization': 'Bearer ${sessao.accessToken}'},
      );
      final dados = resposta.data;
      if (dados is! Map || dados['actualizacao_disponivel'] != true) {
        return null;
      }
      return PunhoUpdateInfo.fromJson(Map<String, dynamic>.from(dados));
    } catch (_) {
      return null;
    }
  }

  String get _platform => switch (Platform.operatingSystem) {
    'windows' => 'windows',
    'android' => 'android',
    'ios' => 'ios',
    _ => 'all',
  };
}
