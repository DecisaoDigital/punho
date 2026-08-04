import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/modo_de_recuperacao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// O trinco que impede um link de email de dar entrada silenciosa na app.
///
/// Ver [modoDeRecuperacao] para o porquê. Em duas linhas: abrir o link de
/// recuperação autentica, e sem este trinco a pessoa entrava sem lhe ser pedida
/// palavra-passe nenhuma — a antiga continuava a valer, ela julgava tê-la
/// mudado, e no dia seguinte não entrava.
void main() {
  test('o link de recuperação fecha o trinco', () {
    expect(
      modoDeRecuperacao(AuthChangeEvent.passwordRecovery, actual: false),
      isTrue,
    );
  });

  test('um token renovado não o abre', () {
    // É este que faz a diferença toda: os `tokenRefreshed` passam sozinhos, de
    // hora a hora. Ler só o evento do momento dava entrada a quem estivesse
    // parado no ecrã da palavra-passe nova quando um deles passasse.
    expect(
      modoDeRecuperacao(AuthChangeEvent.tokenRefreshed, actual: true),
      isTrue,
    );
    expect(modoDeRecuperacao(AuthChangeEvent.signedIn, actual: true), isTrue);
    expect(modoDeRecuperacao(null, actual: true), isTrue);
  });

  test('a palavra-passe mudada abre-o', () {
    expect(
      modoDeRecuperacao(AuthChangeEvent.userUpdated, actual: true),
      isFalse,
    );
  });

  test('desistir também — a sessão fecha-se e não fica nada encostado', () {
    expect(modoDeRecuperacao(AuthChangeEvent.signedOut, actual: true), isFalse);
  });

  test('quem não veio por link nenhum não é incomodado', () {
    for (final evento in AuthChangeEvent.values) {
      if (evento == AuthChangeEvent.passwordRecovery) continue;
      expect(
        modoDeRecuperacao(evento, actual: false),
        isFalse,
        reason: '$evento não pode acender o modo de recuperação sozinho',
      );
    }
  });
}
