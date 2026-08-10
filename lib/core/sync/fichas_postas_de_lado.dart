import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A ficha da empresa que este aparelho tinha por enviar quando o servidor
/// mandou receber outra por cima.
///
/// **Porque é que isto existe.** A regra do canal da ficha é "o servidor
/// manda": se a revisão que lá está não é a que este telemóvel conhece, o que
/// ele tem é velho, e velho perde. A regra está certa — a alternativa era a
/// sincronização encravar à espera de alguém que não existe. O que estava
/// errado era o *silêncio*: o gestor escrevia os custos fixos num telemóvel sem
/// rede, voltava a haver rede, e o trabalho desaparecia sem uma linha a dizê-lo.
/// Ficava a pensar que se tinha enganado a gravar.
///
/// Aqui não se desfaz a regra. Guarda-se o que ela deitou fora, e diz-se.
@immutable
class FichaPostaDeLado {
  const FichaPostaDeLado({
    required this.quando,
    required this.revisaoLocal,
    required this.revisaoDoServidor,
    required this.payload,
  });

  /// Quando é que este aparelho cedeu. Serve de [id] — duas cedências no mesmo
  /// milissegundo eram a mesma.
  final DateTime quando;

  /// A revisão que este telemóvel julgava ser a da empresa. `null` quando nunca
  /// tinha recebido nenhuma.
  final int? revisaoLocal;
  final int revisaoDoServidor;

  /// O JSON tal e qual ia subir, inteiro.
  ///
  /// Um resumo serve para o gestor perceber o que perdeu; o payload serve para
  /// se poder repor sem depender da memória de ninguém. Guardar só o resumo era
  /// dizer "tinhas aqui trabalho" e não ser capaz de o devolver.
  final String payload;

  String get id => quando.toIso8601String();

  /// O que ia lá dentro, em números que se possam mostrar.
  ///
  /// Lê o payload à defesa: uma ficha ilegível continua a ser uma ficha que se
  /// perdeu, e o cartão tem de aparecer na mesma — nem que seja só com a data.
  ({String? empresa, int rubricas, int custosMensaisCents, int meses})
  get resumo {
    try {
      final dados = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      final onboarding = dados['onboarding'] is Map
          ? Map<String, dynamic>.from(dados['onboarding'] as Map)
          : const <String, dynamic>{};
      final custos = (onboarding['custosFixos'] as List? ?? const []);
      return (
        empresa: onboarding['companyName'] as String?,
        rubricas: custos.length,
        custosMensaisCents: custos.fold<int>(
          0,
          (soma, linha) =>
              soma + ((linha as Map)['valorCents'] as num? ?? 0).toInt(),
        ),
        meses: (dados['historicalMonths'] as List? ?? const []).length,
      );
    } catch (erro) {
      debugPrint('[Ficha] payload posto de lado ilegível: $erro');
      return (empresa: null, rubricas: 0, custosMensaisCents: 0, meses: 0);
    }
  }

  Map<String, Object?> paraDisco() => {
    'quando': quando.toIso8601String(),
    'revisaoLocal': revisaoLocal,
    'revisaoDoServidor': revisaoDoServidor,
    'payload': payload,
  };

  static FichaPostaDeLado doDisco(Map<String, dynamic> dados) =>
      FichaPostaDeLado(
        quando: DateTime.parse(dados['quando'] as String),
        revisaoLocal: (dados['revisaoLocal'] as num?)?.toInt(),
        revisaoDoServidor: (dados['revisaoDoServidor'] as num).toInt(),
        payload: dados['payload'] as String,
      );
}

/// Onde ficam as fichas que o servidor mandou deitar fora, até o gestor as ver.
///
/// Mesma forma da quarentena e do balde de conflitos em `RegistoDeOperacoes`:
/// lista em `SharedPreferences`, tecto próprio, e uma linha ilegível nunca
/// tranca as outras. Não é uma fila de envio — daqui nada sobe.
class RegistoDeFichasPostasDeLado {
  const RegistoDeFichasPostasDeLado(this._prefs);

  final SharedPreferences _prefs;

  static const _kFichas = 'punho_sync.fichas_postas_de_lado_v1';

  /// Tecto baixo de propósito: isto é para ser visto e limpo, não para crescer.
  /// Uma ficha da empresa é grande, e vinte já são mais do que qualquer gestor
  /// consegue olhar de uma vez.
  static const _tecto = 20;

  List<FichaPostaDeLado> get todas {
    final cru = _prefs.getStringList(_kFichas) ?? const <String>[];
    final lista = <FichaPostaDeLado>[];
    for (final linha in cru) {
      try {
        lista.add(
          FichaPostaDeLado.doDisco(
            Map<String, dynamic>.from(jsonDecode(linha) as Map),
          ),
        );
      } catch (erro) {
        debugPrint('[Ficha] linha posta de lado ilegível, ignorada: $erro');
      }
    }
    // A mais recente primeiro: é a que o gestor acabou de perder.
    lista.sort((a, b) => b.quando.compareTo(a.quando));
    return lista;
  }

  Future<void> guardar(FichaPostaDeLado ficha) async {
    final actual = _prefs.getStringList(_kFichas) ?? <String>[];
    actual.add(jsonEncode(ficha.paraDisco()));
    if (actual.length > _tecto) {
      actual.removeRange(0, actual.length - _tecto);
    }
    await _prefs.setStringList(_kFichas, actual);
  }

  Future<void> limpar() => _prefs.remove(_kFichas);
}

/// O que a ficha da empresa perdeu para o servidor, para a aba Estado o poder
/// mostrar.
///
/// Lê do disco e não do motor de sincronização, de propósito: com o Supabase
/// desligado não há motor nenhum, e o que já ficou posto de lado tem de
/// continuar a aparecer. Quem o invalida é o `synchronizeRemote`, a seguir a
/// cada passagem do canal da ficha.
final fichasPostasDeLadoProvider = FutureProvider<List<FichaPostaDeLado>>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return RegistoDeFichasPostasDeLado(prefs).todas;
});
