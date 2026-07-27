import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/licenca/licenca_provider.dart';
import 'core/licenca/licenca_service.dart';
import 'core/licenca/machine_id.dart';
import 'core/operations/operations_controller.dart';
import 'core/theme/punho_theme.dart';
import 'core/config/supabase_config.dart';
import 'data/repositories/operation_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/updates/presentation/update_banner_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.enabled) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    // Auto-onboarding: não bloqueia o arranque e falha em silêncio. As Edge
    // Functions aceitam a chave pública, por isso corre antes do login.
    unawaited(_registarTerminal());
  }
  await bloquearLandscape();
  final operationsRepository = await PersistentOperationRepository.create();
  runApp(
    ProviderScope(
      overrides: [
        operationRepositoryProvider.overrideWithValue(operationsRepository),
      ],
      child: const PunhoApp(),
    ),
  );
}

/// O Punho é uma app de landscape.
///
/// Quem a usa é o empresário, no tablet ou no PC, e o painel de gestão foi
/// desenhado para essa forma: cinco slides com quatro KPIs cada, lado a lado.
/// Em portrait não caberia sem espremer os números até não se lerem, portanto
/// portrait não é suportado em vez de ser mal suportado.
///
/// Excepção deliberada: a shell do colaborador continua a pedir portrait quando
/// está montada (`PhoneOrientationLock` dentro dela). Aquele ecrã é para o
/// telemóvel na mão, no terreno, com seis botões grandes — outro utilizador,
/// outro dispositivo, outra forma.
Future<void> bloquearLandscape() => SystemChrome.setPreferredOrientations(const [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

Future<void> _registarTerminal() async {
  try {
    final machineId = await resolverMachineId();
    await PunhoLicencaService(
      Supabase.instance.client,
    ).registarTerminal(machineId);
  } catch (erro) {
    debugPrint('auto-onboarding falhou: $erro');
  }
}

class PunhoApp extends ConsumerWidget {
  const PunhoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém o timer de revalidação vivo durante a vida da app.
    ref.watch(licencaRefreshProvider);
    return MaterialApp(
      title: 'Punho',
      debugShowCheckedModeBanner: false,
      theme: PunhoTheme.light,
      // O aviso de nova versão envolve a raiz, e não um ecrã: tem de chegar a
      // quem está preso no login ou no gate de acesso.
      home: PunhoUpdateBannerWrapper(
        child: SupabaseConfig.enabled ? const AuthGate() : const AppShell(),
      ),
    );
  }
}
