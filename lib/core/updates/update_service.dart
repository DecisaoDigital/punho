import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'update_info.dart';

class PunhoUpdateService {
  PunhoUpdateService(this._client);
  final SupabaseClient _client;

  Future<PunhoUpdateInfo?> check() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final response = await _client.functions
          .invoke(
            'versao-mais-recente',
            body: {
              'app': 'punho',
              'plataforma': _platform,
              'build_number_local': build,
            },
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 10));
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['actualizacao_disponivel'] != true) {
        return null;
      }
      return PunhoUpdateInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  String get _platform => switch (Platform.operatingSystem) {
    'windows' => 'windows',
    'android' => 'android',
    'ios' => 'ios',
    _ => 'all',
  };
}
