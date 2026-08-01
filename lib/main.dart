import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cadeado/cadeado_gate.dart';
import 'shared/widgets/splash_punho.dart';

import 'core/licenca/licenca_provider.dart';
import 'core/telemetria/pings_provider.dart';
import 'core/licenca/licenca_service.dart';
import 'core/licenca/machine_id.dart';
import 'core/operations/operations_controller.dart';
import 'core/theme/punho_theme.dart';
import 'core/config/supabase_config.dart';
import 'data/repositories/operation_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/sync/sync_providers.dart';
import 'features/updates/presentation/update_banner_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A área das notificações pertence visualmente à moldura da app. Sem esta
  // definição, alguns Android desenham ícones claros sobre o fundo claro do
  // conteúdo, sobretudo quando o telemóvel está em landscape.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: PunhoTheme.navyDeep,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  if (SupabaseConfig.enabled) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    // Auto-onboarding: não bloqueia o arranque e falha em silêncio. As Edge
    // Functions aceitam a chave pública, por isso corre antes do login.
    unawaited(_registarTerminal());
  }
  // Sem bloqueio de orientação no arranque: a app não sabe ainda quem a vai
  // usar. Cada ecrã decide (Decisão 13) — landscape só no shell do gestor
  // autenticado, portrait em todo o resto. Bloquear aqui era o que punha o
  // passo 4 do onboarding deitado num tablet.
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

class PunhoApp extends ConsumerStatefulWidget {
  const PunhoApp({super.key});
  @override
  ConsumerState<PunhoApp> createState() => _PunhoAppState();
}

class _PunhoAppState extends ConsumerState<PunhoApp> {
  bool _splashTerminou = false;

  @override
  Widget build(BuildContext context) {
    // Mantém o timer de revalidação vivo durante a vida da app.
    ref.watch(licencaRefreshProvider);
    // Idem para a sincronização entre dispositivos: observada aqui e não numa
    // shell, porque tem de correr tanto para o gestor como para o colaborador
    // — é entre os dois que os dados precisam de viajar.
    ref.watch(syncProvider);
    // E os pings: sem eles o Control sabe que o terminal existe, mas não sabe
    // quando foi usado nem que versão lá está agora.
    ref.watch(pingsProvider);
    final destino = CadeadoGate(
      child: PunhoUpdateBannerWrapper(
        child: SupabaseConfig.enabled ? const AuthGate() : const AppShell(),
      ),
    );
    return MaterialApp(
      title: 'Punho',
      debugShowCheckedModeBanner: false,
      theme: PunhoTheme.light,
      home: _splashTerminou
          ? destino
          : SplashPunho(
              aoTerminar: () => setState(() => _splashTerminou = true),
            ),
    );
  }
}
