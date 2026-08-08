import 'package:flutter/foundation.dart';

class SupabaseConfig {
  const SupabaseConfig._();
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;

  /// Trava contra um APK de release compilado **sem** `--dart-define`.
  ///
  /// A v0.0.5 saiu assim: o APK partiu para o utilizador sem saber que existia
  /// um Supabase, e a auto-actualização ficou muda durante duas versões. O
  /// `catch (_)` a jusante só diagnosticou — não impediu o lançamento. Isto
  /// impede.
  ///
  /// Em debug e profile deixa passar: quem corre `flutter run` sem defines
  /// quer ver o ecrã, não levar com um crash.
  ///
  /// Isto já cá esteve uma vez ([b0d83e3]) e desapareceu num merge ([59d6865])
  /// — a função e a chamada, as duas. Por isso é que há um teste a segurá-la e
  /// outro a segurar a chamada no `main`.
  static void assertConfiguredOrCrash() =>
      verificar(release: kReleaseMode, configurada: enabled);

  /// O miolo da trava, sem depender de como a app foi compilada.
  ///
  /// Existe separado para poder ser posto à prova: `kReleaseMode` é constante
  /// de compilação e num teste vale sempre `false`, o que deixaria o ramo que
  /// interessa — o do release mal compilado — por testar.
  @visibleForTesting
  static void verificar({required bool release, required bool configurada}) {
    if (!release) return;
    if (configurada) return;
    throw StateError(
      'SUPABASE_URL e SUPABASE_ANON_KEY em falta no APK release. '
      'Recompilar com --dart-define. Ver docs/PROCESSO_DE_RELEASE.md.',
    );
  }
}
