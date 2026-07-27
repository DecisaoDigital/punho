import 'package:flutter/material.dart';

import 'ecra_de_contexto.dart';

/// Último ecrã do onboarding do gestor, antes de entrar na app.
///
/// Até aqui o gestor passava do último campo directamente para o painel, sem
/// nunca lhe ter sido dito o que a app é. Este ecrã fecha o onboarding: diz o
/// que vai encontrar, avisa que "por apurar" é normal no início, e pede-lhe
/// para rodar o dispositivo.
///
/// **O aviso da rotação é um convite, não um bloqueio.** O ecrã continua em
/// retrato e não fixa orientação nenhuma: se o gestor rodar antes de tocar no
/// botão, o ecrã acompanha — e isso mostra-lhe que a app suporta o formato. O
/// bloqueio de paisagem entra depois, com o `completeOnboarding`.
///
/// Só é mostrado a gestores. Ao colaborador não se promete "o painel do teu
/// negócio em cinco vistas", porque o shell dele não tem painel nenhum e fica
/// em retrato — a mensagem estaria errada nas duas pontas.
class BoasVindasScreen extends StatelessWidget {
  const BoasVindasScreen({super.key, required this.aoEntrar, this.aoVoltar});

  /// Chama o `completeOnboarding`. É aqui, e só aqui, que os dados são
  /// gravados: até tocar neste botão o gestor pode voltar atrás e corrigir.
  final VoidCallback aoEntrar;
  final VoidCallback? aoVoltar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return EcraDeContexto(
      // Punho, a mão. É o nome da app.
      icone: Icons.back_hand_outlined,
      titulo: 'Bem-vindo à Punho.',
      paragrafos: const [
        'A Punho é o painel do teu negócio. Mostra o que entrou, o que saiu, o '
            'que está por cobrar e o que fazer esta semana — em cinco vistas.',
        'Não te preocupes se algum número aparecer como "por apurar": à medida '
            'que usas a app, ela vai aprendendo o teu ritmo e melhorando as '
            'sugestões.',
        'Ready?',
      ],
      rodape: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cores.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.screen_rotation, color: cores.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'A partir daqui a Punho passa a modo horizontal — roda o '
                'tablet ou o telemóvel para melhor aproveitamento.',
                style: TextStyle(color: cores.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
      rotuloDoBotao: 'Entrar na Punho →',
      aoAvancar: aoEntrar,
      aoVoltar: aoVoltar,
    );
  }
}
