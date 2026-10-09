import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/licenca/licenca_fist.dart';

/// Texto do ecrã de bloqueio para cada fase que bloqueia.
({String titulo, String corpo, String? accao}) textoDoBloqueio(
  EstadoLicencaFist estado,
) {
  final r = estado.resposta;
  return switch (estado.fase) {
    FaseLicencaFist.sessaoPerdida => (
      titulo: 'Sessão aberta noutro aparelho',
      corpo:
          'Esta conta só pode estar aberta num aparelho de cada vez. '
          'Podes voltar a abri-la aqui, e o outro fecha.',
      accao: 'Usar neste aparelho',
    ),
    FaseLicencaFist.dispositivosExcedidos => (
      titulo: 'Esta conta já usa ${r?.aparelhosMaximo ?? 2} aparelhos',
      corpo:
          'Contacta a WashControl para libertar um dos aparelhos antes '
          'de usares este.',
      accao: null,
    ),
    FaseLicencaFist.semRedeDemais => (
      titulo: 'Sem ligação há demasiado tempo',
      corpo:
          'A app precisa de falar com o servidor pelo menos uma vez a '
          'cada 28 horas. Liga-te à internet e tenta outra vez.',
      accao: 'Tentar novamente',
    ),
    _ => (titulo: '', corpo: '', accao: null),
  };
}

/// Cobre a app quando a licença da conta o exige: sessão aberta noutro
/// aparelho, 3.º aparelho, ou mais de 28 horas sem o servidor responder.
class LicencaFistGate extends ConsumerWidget {
  const LicencaFistGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(licencaFistProvider);
    return Stack(
      children: [
        child,
        if (estado.fase.bloqueia)
          Positioned.fill(child: _EcraBloqueio(estado: estado)),
      ],
    );
  }
}

class _EcraBloqueio extends ConsumerWidget {
  const _EcraBloqueio({required this.estado});

  final EstadoLicencaFist estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = textoDoBloqueio(estado);
    final controlador = ref.read(licencaFistProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    t.titulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(t.corpo, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (t.accao != null)
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (estado.fase == FaseLicencaFist.sessaoPerdida) {
                          controlador.reabrirSessao();
                        } else {
                          controlador.revalidar();
                        }
                      },
                      child: Text(t.accao!),
                    ),
                  TextButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: const Text('Terminar sessão'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
