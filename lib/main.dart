import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/operations/operations_controller.dart';
import 'core/theme/punho_theme.dart';
import 'core/config/supabase_config.dart';
import 'data/repositories/operation_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/shell/presentation/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.enabled) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
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

class PunhoApp extends StatelessWidget {
  const PunhoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Punho',
    debugShowCheckedModeBanner: false,
    theme: PunhoTheme.light,
    home: SupabaseConfig.enabled ? const AuthGate() : const AppShell(),
  );
}
