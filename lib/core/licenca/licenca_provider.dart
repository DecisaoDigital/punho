import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'licenca_info.dart';
import 'licenca_service.dart';
import 'machine_id.dart';

/// De quanto em quanto tempo a licença é revalidada com o Control.
const intervaloRevalidacaoLicenca = Duration(hours: 6);

final licencaServiceProvider = Provider<PunhoLicencaService>(
  (ref) => PunhoLicencaService(Supabase.instance.client),
);

final machineIdProvider = FutureProvider<String>((ref) => resolverMachineId());

/// Estado actual da licença. `null` significa "não foi possível saber"
/// (sem Supabase configurado, offline ou timeout) — não significa "sem licença".
final licencaProvider = FutureProvider<LicencaInfo?>((ref) async {
  if (!SupabaseConfig.enabled) return null;
  final machineId = await ref.watch(machineIdProvider.future);
  return ref.watch(licencaServiceProvider).validar(machineId);
});

/// Timer que revalida a licença periodicamente. Basta observá-lo uma vez
/// (no arranque) para ficar activo durante a vida da app.
final licencaRefreshProvider = Provider<void>((ref) {
  if (!SupabaseConfig.enabled) return;
  final timer = Timer.periodic(
    intervaloRevalidacaoLicenca,
    (_) => ref.invalidate(licencaProvider),
  );
  ref.onDispose(timer.cancel);
});
