import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/updates/instalador_de_update.dart';
import '../../../core/updates/update_info.dart';
import '../instalacao_providers.dart';
import '../update_providers.dart';

/// O aviso em si. Quem o monta é o [PunhoUpdateBannerWrapper], por cima de
/// qualquer ecrã — o estado vive em `punhoUpdateProvider`, não aqui.
///
/// O botão muda com a fase: a descarga acontece sozinha em segundo plano e o
/// gestor só decide **quando** instalar. É o mais perto de "não se dá por eles"
/// que o Android permite a uma app fora da loja.
class PunhoUpdateBanner extends ConsumerWidget {
  const PunhoUpdateBanner({super.key, this.update});

  /// Quando é nulo, o aviso lê o estado global. Serve para o wrapper poder
  /// passar o que já leu, sem segunda leitura do provider.
  final PunhoUpdateInfo? update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = this.update ?? ref.watch(punhoUpdateProvider);
    if (update == null) return const SizedBox.shrink();
    final instalacao = ref.watch(estadoDoUpdateProvider);
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
                    _titulo(update, instalacao),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (instalacao.fase == FaseDoUpdate.aDescarregar) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: instalacao.progresso == 0
                          ? null
                          : instalacao.progresso,
                    ),
                  ] else if (instalacao.erro != null) ...[
                    const SizedBox(height: 4),
                    Text(instalacao.erro!),
                  ] else if (update.releaseNotes?.trim().isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 4),
                    Text(
                      update.releaseNotes!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Accao(update: update, instalacao: instalacao),
            if (!update.mandatory) ...[
              // Só o opcional pode ser calado: o obrigatório não tem para
              // onde o gestor "continuar a trabalhar" sem ele.
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Agora não',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    ref.read(updateDispensadoProvider.notifier).state =
                        update.buildNumber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titulo(PunhoUpdateInfo update, EstadoDoUpdate instalacao) =>
      switch (instalacao.fase) {
        FaseDoUpdate.aDescarregar =>
          'A descarregar a versão ${update.version}…',
        FaseDoUpdate.pronta => 'Versão ${update.version} pronta a instalar',
        FaseDoUpdate.aInstalar => 'A instalar…',
        FaseDoUpdate.aguardaConfirmacao => 'Confirma no ecrã do Android',
        FaseDoUpdate.falhou => 'Não foi possível actualizar',
        FaseDoUpdate.disponivel =>
          update.mandatory
              ? 'Atualização obrigatória disponível'
              : 'Nova versão ${update.version} disponível',
      };
}

class _Accao extends ConsumerWidget {
  const _Accao({required this.update, required this.instalacao});
  final PunhoUpdateInfo update;
  final EstadoDoUpdate instalacao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(estadoDoUpdateProvider.notifier);

    switch (instalacao.fase) {
      case FaseDoUpdate.aDescarregar:
      case FaseDoUpdate.aInstalar:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case FaseDoUpdate.pronta:
        return FilledButton(
          onPressed: controller.instalar,
          child: const Text('Instalar'),
        );

      case FaseDoUpdate.aguardaConfirmacao:
        return const SizedBox.shrink();

      case FaseDoUpdate.falhou:
        // Sempre uma saída pelo browser: um instalador que falha não pode
        // deixar o gestor sem forma de actualizar.
        return TextButton(
          onPressed: () => launchUrl(
            Uri.parse(update.downloadUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Descarregar'),
        );

      case FaseDoUpdate.disponivel:
        // Sem hash publicado não há instalação automática — o ficheiro não pode
        // ser verificado, e o caminho antigo é melhor do que instalar às cegas.
        if ((update.sha256 ?? '').isEmpty) {
          return FilledButton(
            onPressed: () => launchUrl(
              Uri.parse(update.downloadUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Atualizar'),
          );
        }
        return FilledButton(
          onPressed: () => controller.descarregarAgora(update),
          child: const Text('Atualizar'),
        );
    }
  }
}
