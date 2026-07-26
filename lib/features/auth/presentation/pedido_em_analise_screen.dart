import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acesso_providers.dart';

/// Conta criada, acesso ainda por libertar. Botão único: terminar sessão.
///
/// Não pré-carrega nada da empresa — os repositórios operacionais só arrancam
/// dentro da AppShell.
class PedidoEmAnaliseScreen extends ConsumerWidget {
  const PedidoEmAnaliseScreen({super.key});

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
              const Icon(Icons.hourglass_top, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Pedido em análise',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'A sua conta foi criada. O acesso é libertado manualmente pela '
                'Decisão Digital depois de confirmarmos os dados.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.read(acessoServiceProvider).terminarSessao(),
                child: const Text('Terminar sessão'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
