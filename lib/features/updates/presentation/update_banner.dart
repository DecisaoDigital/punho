import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/updates/update_info.dart';
import '../../../core/updates/update_service.dart';

final punhoUpdateProvider = FutureProvider<PunhoUpdateInfo?>((ref) {
  if (!SupabaseConfig.enabled) return null;
  return PunhoUpdateService(Supabase.instance.client).check();
});

class PunhoUpdateBanner extends ConsumerWidget {
  const PunhoUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(punhoUpdateProvider).valueOrNull;
    if (update == null) return const SizedBox.shrink();
    final color = update.mandatory
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(update.mandatory ? Icons.warning_amber : Icons.system_update),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.mandatory
                        ? 'Atualização obrigatória disponível'
                        : 'Nova versão ${update.version} disponível',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (update.releaseNotes?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(update.releaseNotes!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(update.downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
