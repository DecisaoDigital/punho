import 'package:supabase_flutter/supabase_flutter.dart';

/// Sugestões do utilizador, a chegar ao mesmo sítio onde já chegam as do
/// WashInvoice: a tabela `sugestoes`, partilhada entre as duas apps no mesmo
/// projecto Supabase, lida pelo Control. `app: 'punho'` é o que distingue de
/// onde veio cada linha.
///
/// A escrita passa pela Edge Function `enviar-sugestao` (service_role), em
/// vez de um insert directo: a tabela só tinha política de INSERT para o
/// papel `anon`, e alargá-la a `authenticated` mexia numa RLS partilhada com
/// o WashInvoice — a função evita essa alteração de schema.
class SugestoesService {
  SugestoesService(this._cliente);
  final SupabaseClient _cliente;

  Future<void> enviar(String texto, {String? nif}) async {
    final resposta = await _cliente.functions.invoke(
      'enviar-sugestao',
      body: {'texto': texto, 'app': 'punho', if (nif != null) 'nif': nif},
    );
    if (resposta.status != 200) {
      throw Exception('enviar-sugestao devolveu ${resposta.status}');
    }
  }
}
