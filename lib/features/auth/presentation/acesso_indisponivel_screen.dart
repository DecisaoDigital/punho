import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acesso_providers.dart';

/// Pedido recusado ou acesso revogado. Botão único: terminar sessão.
///
/// Não distingue recusado de revogado nem dá motivos: isso é informação
/// interna do Control e não tem de sair para o ecrã de quem ficou de fora.
class AcessoIndisponivelScreen extends ConsumerWidget {
  const AcessoIndisponivelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Acesso indisponível',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta conta não tem acesso ao Punho. Para mais informações, '
                'contacte a Decisão Digital.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () =>
                    ref.read(acessoServiceProvider).terminarSessao(),
                child: const Text('Terminar sessão'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
