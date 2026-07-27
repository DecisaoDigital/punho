import 'package:flutter/material.dart';

import '../../../core/orientacao/orientacao_do_contexto.dart';
import 'ecra_de_contexto.dart';

/// Último ecrã do onboarding do gestor, antes de entrar na app.
///
/// Até aqui o gestor passava do último campo directamente para o painel, sem
/// nunca lhe ter sido dito o que a app é. Este ecrã fecha o onboarding: diz o
/// que vai encontrar, avisa que "por apurar" é normal no início, e avisa que o
/// ecrã vai rodar.
///
/// **A rotação é da app, não do gestor.** O ecrã abre em portrait — como todo o
/// onboarding — e é o botão "Entrar na Punho" que pede landscape, antes de
/// entrar.
///
/// Na sprint 1 este ecrã não mexia na orientação de propósito: a ideia era que o
/// gestor rodasse à mão e visse que a app aguentava. O bug do passo 4 mostrou
/// que o problema estava no bloqueio global do `main.dart`, e com esse fora, um
/// ecrã que não pede nada fica com o que o anterior deixou. Deixar isto ao
/// utilizador era deixá-lo ao acaso — daí a Decisão 13 e daí o texto passar a
/// prometer que o ecrã roda sozinho, em vez de lhe pedir para rodar.
///
/// Só é mostrado a gestores. Ao colaborador não se promete "o painel do teu
/// negócio em cinco vistas", porque o shell dele não tem painel nenhum e fica
/// em retrato — a mensagem estaria errada nas duas pontas.
class BoasVindasScreen extends StatefulWidget {
  const BoasVindasScreen({super.key, required this.aoEntrar, this.aoVoltar});

  /// Chama o `completeOnboarding`. É aqui, e só aqui, que os dados são
  /// gravados: até tocar neste botão o gestor pode voltar atrás e corrigir.
  final VoidCallback aoEntrar;
  final VoidCallback? aoVoltar;

  @override
  State<BoasVindasScreen> createState() => _BoasVindasScreenState();
}

class _BoasVindasScreenState extends State<BoasVindasScreen> {
  @override
  void initState() {
    super.initState();
    OrientacaoDoContexto.portraitJa();
  }

  /// Landscape **antes** de entrar, não depois: o painel aparece já na forma
  /// certa em vez de nascer deitado e rodar à frente do gestor.
  void _entrar() {
    OrientacaoDoContexto.landscapeJa();
    widget.aoEntrar();
  }

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
                'A partir daqui a Punho vai passar a modo horizontal — o teu '
                'tablet vai rodar sozinho.',
                style: TextStyle(color: cores.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
      rotuloDoBotao: 'Entrar na Punho →',
      aoAvancar: _entrar,
      aoVoltar: widget.aoVoltar,
    );
  }
}
