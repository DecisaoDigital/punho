import 'package:supabase_flutter/supabase_flutter.dart';

/// Se a app tem de pedir uma palavra-passe nova, e até quando.
///
/// **Isto é um trinco, não um interruptor.** Abrir o link do email de
/// recuperação *autentica*: o `supabase_flutter` chama `getSessionFromUrl` e a
/// partir daí há sessão. Se o porteiro lesse só o evento do momento, bastava um
/// `tokenRefreshed` a passar — e eles passam sozinhos, de hora a hora — para a
/// app se abrir com a palavra-passe antiga ainda válida e ninguém ter escolhido
/// nada. Um link de email a dar entrada silenciosa é pior do que o problema que
/// se foi corrigir.
///
/// Por isso só duas coisas o soltam: a palavra-passe mudou de facto
/// ([AuthChangeEvent.userUpdated]) ou a sessão fechou-se
/// ([AuthChangeEvent.signedOut]). Tudo o resto deixa-o como está.
bool modoDeRecuperacao(AuthChangeEvent? evento, {required bool actual}) =>
    switch (evento) {
      AuthChangeEvent.passwordRecovery => true,
      AuthChangeEvent.userUpdated || AuthChangeEvent.signedOut => false,
      _ => actual,
    };
