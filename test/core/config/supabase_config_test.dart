import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/config/supabase_config.dart';

/// A trava que impede um APK de release sair sem Supabase.
///
/// Ela já existiu ([b0d83e3]) e desapareceu num merge ([59d6865]) sem que
/// nenhum teste desse por isso. Foram-se as duas metades — a função e a
/// chamada no `main` —, e cada uma precisa do seu guarda: uma função que
/// ninguém chama não trava nada, e uma chamada a uma função que já não lança
/// também não.
void main() {
  group('a trava dos dart-defines', () {
    test('release sem configuração rebenta, e diz o que fazer', () {
      // O caso que custou a v0.0.5: APK de release compilado sem
      // `--dart-define`. A app arrancava, não sabia que existia um Supabase, e
      // a auto-actualização ficou muda durante duas versões.
      expect(
        () => SupabaseConfig.verificar(release: true, configurada: false),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'a mensagem diz como se corrige',
            allOf(contains('SUPABASE_URL'), contains('--dart-define')),
          ),
        ),
      );
    });

    test('release configurado deixa passar', () {
      expect(
        () => SupabaseConfig.verificar(release: true, configurada: true),
        returnsNormally,
      );
    });

    test('debug sem configuração deixa passar', () {
      // Quem corre `flutter run` sem defines quer ver o ecrã, não levar com um
      // crash. Sem esta metade, a trava tornava-se um estorvo e alguém a
      // arrancava outra vez.
      expect(
        () => SupabaseConfig.verificar(release: false, configurada: false),
        returnsNormally,
      );
    });

    test('a chamada continua no main, antes da zona guardada', () {
      // Este lê o código-fonte de propósito. O que se perdeu no merge não foi
      // só a função: foi a chamada. Uma trava que ninguém aciona não se
      // distingue de uma trava que não existe, e nenhum teste de
      // comportamento apanha a diferença.
      final fonte = File('lib/main.dart').readAsStringSync();

      expect(
        fonte,
        contains('SupabaseConfig.assertConfiguredOrCrash()'),
        reason: 'o main deixou de accionar a trava dos dart-defines',
      );

      // E tem de ser **antes** da zona: lá dentro a excepção é apanhada pelo
      // handler, o `runApp` não corre, e fica ecrã preto sem explicação.
      expect(
        fonte.indexOf('SupabaseConfig.assertConfiguredOrCrash()'),
        lessThan(fonte.indexOf('runZonedGuarded')),
        reason: 'a trava ficou dentro da zona guardada — o crash seria engolido',
      );
    });
  });
}
