import 'package:supabase_flutter/supabase_flutter.dart';

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
}
