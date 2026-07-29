import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/updates/update_info.dart';
import '../update_providers.dart';

/// O aviso em si. Quem o monta é o [PunhoUpdateBannerWrapper], por cima de
/// qualquer ecrã — o estado vive em `punhoUpdateProvider`, não aqui.
class PunhoUpdateBanner extends ConsumerWidget {
  const PunhoUpdateBanner({super.key, this.update});

  /// Quando é nulo, o aviso lê o estado global. Serve para o wrapper poder
  /// passar o que já leu, sem segunda leitura do provider.
  final PunhoUpdateInfo? update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = this.update ?? ref.watch(punhoUpdateProvider);
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
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Novidades da versão ${update.version}'),
                          content: SingleChildScrollView(
                            child: Text(update.releaseNotes!),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Ver detalhes'),
                    ),
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
