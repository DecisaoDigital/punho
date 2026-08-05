import 'package:flutter/material.dart';

import '../../../core/orientacao/orientacao_do_contexto.dart';
import 'ecra_de_contexto.dart';

/// Último ecrã do onboarding do gestor, antes de entrar na app.
///
/// Até aqui o gestor passava do último campo directamente para o painel, sem
/// nunca lhe ter sido dito o que a app é. Este ecrã fecha o onboarding: diz
/// que está feito, avisa que "por apurar" é normal no início, e avisa que o
/// ecrã vai rodar.
///
/// **Já não apresenta a app.** Chamava-se "Bem-vindo à Punho." e explicava o
/// que a Punho é — o que fazia sentido enquanto era o único ecrã a fazê-lo.
/// Desde 5/8/2026 quem entra por pedido aprovado é recebido logo à entrada
/// pelo [BemVindoScreen], com o texto do Cesar; ele percorreu o onboarding
/// todo e deu por si a ser recebido outra vez, no fim — «cheguei ao menu Bem
/// vindo 2 porque antes era o primeiro». Duas boas-vindas no mesmo percurso é
/// uma a mais, e a que se corta é a que chega quando a pessoa já lá está
/// dentro. Ficou-lhe o trabalho que só ele pode fazer: fechar.
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
      // A mão do Punho é do ecrã de entrada. Aqui o que se diz é "está feito".
      icone: Icons.check_circle_outline,
      titulo: 'Está tudo pronto.',
      paragrafos: const [
        'As respostas ficam guardadas quando entrares. Podes mudar qualquer '
            'uma mais tarde, em Definições.',
        'Não te preocupes se algum número aparecer como "por apurar": à medida '
            'que usas a app, ela vai aprendendo o teu ritmo e melhorando as '
            'sugestões.',
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
                'ecrã vai rodar sozinho.',
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
