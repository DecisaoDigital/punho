import 'package:flutter/foundation.dart';

class SupabaseConfig {
  const SupabaseConfig._();
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;

  /// Guard-rail contra release-mode compilada SEM `--dart-define`.
  ///
  /// A v0.0.5 do Punho saiu assim: o APK partiu para o utilizador sem saber
  /// que existia um Supabase, e o auto-update ficou mudo durante duas versoes
  /// (ate ao debugPrint chegar em codigo mais recente). O `catch (_)` a jusante
  /// so diagnosticou; nao impediu o release. Este assert impede.
  ///
  /// Em debug/profile, deixa passar — o dev que corre `flutter run` sem
  /// defines quer ver a UI, nao levar com um crash.
  static void assertConfiguredOrCrash() {
    if (!kReleaseMode) return;
    if (enabled) return;
    throw StateError(
      'SUPABASE_URL e SUPABASE_ANON_KEY em falta no APK release. '
      'Rebuild com --dart-define. Ver task #210/#236.',
    );
  }
}
