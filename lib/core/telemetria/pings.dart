import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Assinatura de vida da app: uma linha em `pings` a dizer que este terminal
/// correu, quando, e com que versão.
///
/// O Punho já se registava (`registar-terminal`) e já validava licença — mas
/// isso acontece **uma vez** e não deixa rasto. No Control via-se que o
/// terminal existe e que a licença está activa, e mais nada: nem o último
/// acesso, nem a versão que lá está agora — só a que estava no dia do registo.
/// Os 93 pings da tabela eram todos do POS.
///
/// A tabela é partilhada com o POS e já estava preparada para isto: a coluna
/// `app` é `NOT NULL` e o Control já distingue `pos` de `punho`. Não houve
/// migração nenhuma a fazer — faltava alguém escrever a linha.
///
/// Falha sempre em silêncio. Um terminal sem rede continua a ser um terminal
/// que trabalha, e ninguém vê um erro de telemetria no arranque.
class PunhoPings {
  PunhoPings(SupabaseClient cliente)
    : _inserir = ((linha) => cliente.from('pings').insert(linha));

  /// Para testes: injecta o destino sem precisar de Supabase.
  PunhoPings.com(this._inserir);

  final Future<void> Function(Map<String, dynamic> linha) _inserir;

  /// O mesmo ritmo do POS. Mais frequente não acrescenta informação — o que se
  /// quer saber é "isto continua a ser usado", não o minuto exacto.
  static const intervalo = Duration(hours: 6);

  Future<void> enviar({
    required String machineId,
    required String origem,
    String? nif,
    bool? termosAceites,
    String? estadoLicenca,
  }) async {
    try {
      final versao = await _versao();
      await _inserir({
        'app': 'punho',
        'machine_id': machineId,
        'origem': origem,
        // Só se preenche o que se sabe: o NIF chega quando a empresa já está
        // criada, e nos primeiros arranques ainda não está. Uma chave a `null`
        // é mais honesta do que uma string vazia que depois se confunde com
        // um NIF por preencher.
        if (nif != null && nif.isNotEmpty) 'nif': nif,
        if (versao != null) 'versao': versao,
        if (termosAceites != null) 'termos_aceites': termosAceites,
        if (estadoLicenca != null) 'estado_licenca': estadoLicenca,
      });
    } catch (erro) {
      debugPrint('ping falhou: $erro');
    }
  }

  Future<String?> _versao() async {
    try {
      final pacote = await PackageInfo.fromPlatform();
      // Versão e build juntos: no Android é o build que manda na comparação de
      // actualizações, e sem ele "1.0.0" não distingue duas instalações.
      return '${pacote.version}+${pacote.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
