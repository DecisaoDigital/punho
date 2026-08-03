import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Um erro à espera de subir para o servidor.
class ErroRegistado {
  const ErroRegistado({
    required this.tipo,
    required this.mensagem,
    required this.acontecidoEm,
    this.pilha,
    this.contexto = const {},
  });

  /// 'flutter' (erro de widget), 'zona' (excepção não apanhada), 'plataforma'
  /// (erro do motor) ou 'manual' (reportado por código nosso).
  final String tipo;
  final String mensagem;
  final String? pilha;
  final DateTime acontecidoEm;
  final Map<String, Object?> contexto;

  Map<String, Object?> paraFila() => {
    'tipo': tipo,
    'mensagem': mensagem,
    'pilha': pilha,
    'acontecido_em': acontecidoEm.toUtc().toIso8601String(),
    'contexto': contexto,
  };

  factory ErroRegistado.daFila(Map<String, dynamic> json) => ErroRegistado(
    tipo: json['tipo'] as String? ?? 'manual',
    mensagem: json['mensagem'] as String? ?? 'sem mensagem',
    pilha: json['pilha'] as String?,
    acontecidoEm:
        DateTime.tryParse(json['acontecido_em'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    contexto: json['contexto'] is Map
        ? Map<String, Object?>.from(json['contexto'] as Map)
        : const {},
  );
}

/// O que substitui a cegueira em produção.
///
/// Todos os `catch` da app acabavam em `debugPrint` — que **não existe numa
/// build release**. Um erro em casa de um cliente ao sábado não chegava a
/// ninguém.
///
/// **Grava primeiro, envia depois**, e é isso que o torna útil: um erro que
/// mata a app não tem tempo de fazer um pedido HTTP. Fica no disco e sobe no
/// arranque seguinte — que é exactamente quando os erros fatais se contam.
class RelatorDeErros {
  RelatorDeErros(
    this._prefs, {
    required this.machineId,
    required this.versao,
    this.contextoBase = const {},
  });

  final SharedPreferences _prefs;
  final String machineId;
  final String versao;

  /// Modelo do aparelho, versão do Android — o que não muda entre erros.
  final Map<String, Object?> contextoBase;

  static const _kFila = 'punho_erros.fila_v1';

  /// Poucos de propósito. Uma app em ciclo de erro escreveria sem fim, e os
  /// primeiros erros de um ciclo dizem tudo o que os seguintes repetem.
  static const maximoNaFila = 20;

  /// Mensagens e pilhas são cortadas: uma pilha inteira do Flutter passa dos
  /// 20 mil caracteres, e o que interessa está sempre no princípio.
  static const _limiteMensagem = 1000;
  static const _limitePilha = 4000;

  List<ErroRegistado> get pendentes {
    final cru = _prefs.getStringList(_kFila) ?? const [];
    final resultado = <ErroRegistado>[];
    for (final linha in cru) {
      try {
        resultado.add(
          ErroRegistado.daFila(
            Map<String, dynamic>.from(jsonDecode(linha) as Map),
          ),
        );
      } catch (_) {
        // Uma linha ilegível não pode impedir os outros erros de subir.
      }
    }
    return resultado;
  }

  /// Grava no disco. Nunca lança — um relator de erros que rebenta é pior do
  /// que não ter relator nenhum.
  Future<void> registar({
    required String tipo,
    required Object erro,
    StackTrace? pilha,
    Map<String, Object?> contexto = const {},
  }) async {
    try {
      final registado = ErroRegistado(
        tipo: tipo,
        mensagem: _cortar('$erro', _limiteMensagem),
        pilha: pilha == null ? null : _cortar('$pilha', _limitePilha),
        acontecidoEm: DateTime.now(),
        contexto: {...contextoBase, ...contexto},
      );
      final fila = _prefs.getStringList(_kFila) ?? <String>[];
      fila.add(jsonEncode(registado.paraFila()));
      if (fila.length > maximoNaFila) {
        fila.removeRange(0, fila.length - maximoNaFila);
      }
      await _prefs.setStringList(_kFila, fila);
      debugPrint('[Erro/$tipo] $erro');
    } catch (falha) {
      debugPrint('[Erro] não consegui sequer registar o erro: $falha');
    }
  }

  /// Sobe o que está em fila e limpa. Best-effort: sem rede, fica para a
  /// próxima.
  Future<int> enviarPendentes(SupabaseClient cliente, {String? empresaId}) async {
    final fila = pendentes;
    if (fila.isEmpty) return 0;
    try {
      await cliente.from('punho_erros').insert([
        for (final erro in fila)
          {
            'machine_id': machineId,
            'app': 'punho',
            'versao': versao,
            'empresa_id': empresaId,
            'utilizador': cliente.auth.currentUser?.id,
            'tipo': erro.tipo,
            'mensagem': erro.mensagem,
            'pilha': erro.pilha,
            'contexto': erro.contexto,
            'acontecido_em': erro.acontecidoEm.toUtc().toIso8601String(),
          },
      ]);
      await _prefs.remove(_kFila);
      return fila.length;
    } catch (falha) {
      // Sem rede, ou servidor em baixo. Fica na fila — é para isso que ela
      // existe. O que não pode é esta falha matar o arranque da app.
      debugPrint('[Erro] envio adiado: $falha');
      return 0;
    }
  }

  static String _cortar(String texto, int limite) =>
      texto.length <= limite ? texto : '${texto.substring(0, limite)}…';
}
