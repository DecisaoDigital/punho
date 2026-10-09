import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/licenca/machine_id.dart';

/// Resposta do César a uma sugestão deste terminal.
class RespostaSugestao {
  const RespostaSugestao({
    required this.sugestao,
    required this.texto,
    required this.lida,
  });
  final String sugestao;
  final String texto;
  final bool lida;
}

/// Sugestões do utilizador, a chegar ao mesmo sítio onde já chegam as do
/// WashInvoice: a tabela `sugestoes`, partilhada entre as duas apps no mesmo
/// projecto Supabase, lida pelo Control. `app: 'punho'` é o que distingue de
/// onde veio cada linha.
///
/// A escrita passa pela Edge Function `enviar-sugestao` (service_role), em
/// vez de um insert directo: mantém a tabela sem depender de RLS para saber
/// de que empresa veio cada sugestão. Quem identifica a empresa é sempre o
/// servidor, a partir do [machineId] já registado em `licencas` — nunca o que
/// o cliente diga que é (não se envia `nif` nenhum).
class SugestoesService {
  SugestoesService(this._cliente);
  final SupabaseClient _cliente;

  Future<void> enviar(String texto, {required String machineId}) async {
    final resposta = await _cliente.functions.invoke(
      'enviar-sugestao',
      body: {'texto': texto, 'app': 'punho', 'machine_id': machineId},
    );
    if (resposta.status != 200) {
      throw Exception('enviar-sugestao devolveu ${resposta.status}');
    }
  }

  /// Respostas do César às sugestões deste terminal (edge function
  /// `respostas-sugestoes`, que identifica o terminal por `licencas`). Com
  /// [marcarLidas] regista que já foram vistas.
  Future<List<RespostaSugestao>> respostas({
    required String machineId,
    bool marcarLidas = false,
  }) async {
    final r = await _cliente.functions.invoke(
      'respostas-sugestoes',
      body: {
        'machine_id': machineId,
        'app': 'punho',
        if (marcarLidas) 'marcar_lidas': true,
      },
    );
    if (r.status != 200) {
      throw Exception('respostas-sugestoes devolveu ${r.status}');
    }
    final dados = r.data as Map<String, dynamic>;
    return [
      for (final e in (dados['respostas'] as List).cast<Map<String, dynamic>>())
        RespostaSugestao(
          sugestao: (e['sugestao'] as String?) ?? '',
          texto: e['texto'] as String,
          lida: e['lida'] as bool? ?? false,
        ),
    ];
  }
}

/// Respostas às sugestões deste terminal. Falha em silêncio (sem rede, sem
/// Supabase): é um extra, nunca pode estragar o perfil.
final respostasSugestoesProvider =
    FutureProvider.autoDispose<List<RespostaSugestao>>((ref) async {
      try {
        return await SugestoesService(
          Supabase.instance.client,
        ).respostas(machineId: await resolverMachineId());
      } catch (_) {
        return const [];
      }
    });
