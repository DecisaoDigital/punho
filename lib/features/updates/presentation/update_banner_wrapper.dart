import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../update_providers.dart';
import 'update_banner.dart';

/// Barreira que tapa a app quando o update é obrigatório. Tem chave para os
/// testes a distinguirem das barreiras que o `Navigator` cria por sua conta.
const barreiraUpdateObrigatorio = Key('barreira-update-obrigatorio');

/// Põe o aviso de nova versão por cima de **qualquer** ecrã da app.
///
/// Envolve a raiz mostrada depois do `Supabase.initialize`, e não um ecrã em
/// particular: assim o aviso aparece a quem está no login, a quem tem o pedido
/// em análise, a quem teve o acesso recusado ou revogado, e às duas shells.
/// Antes disto o banner vivia dentro do `DashboardPage`, ou seja só um gestor
/// com adesão activa o via — que hoje é a minoria dos utilizadores.
///
/// O wrapper não decide acessos nem os contorna: o `AcessoGate` continua a
/// mandar no que se vê por baixo. Só desenha por cima.
class PunhoUpdateBannerWrapper extends ConsumerWidget {
  const PunhoUpdateBannerWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(punhoUpdateProvider);
    if (update == null) return child;

    if (update.mandatory) {
      // Obrigatório é obrigatório: o ecrã por baixo continua montado (para não
      // mudar o comportamento de quem já estava lá) mas fica intocável até a
      // app ser actualizada. Não há botão para dispensar.
      return Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned.fill(
            child: ModalBarrier(
              key: barreiraUpdateObrigatorio,
              dismissible: false,
              color: Color(0xB3000000),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: PunhoUpdateBanner(update: update),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Opcional: uma Column e não uma Stack. O aviso empurra o conteúdo em vez
    // de o tapar, portanto nada fica escondido nem se perde um toque num botão
    // que o banner cobrisse — e o ecrã por baixo não precisa de saber que ele
    // existe. A Stack fica reservada ao caso obrigatório, onde tapar é o ponto.
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: PunhoUpdateBanner(update: update),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
