import 'package:flutter/material.dart';

import 'ecra_de_contexto.dart';

/// Aparece só quando o gestor diz que quer preencher os dados operacionais.
///
/// Fica **entre** o switch e o primeiro passo detalhado: o gestor acabou de
/// dizer "sim" a uma pergunta e a app respondia mudando de campo sem dizer
/// nada. Este ecrã diz-lhe o que vem a seguir e, sobretudo, o que ganha com
/// isso — as sugestões da semana só afinam com estes números.
class MaisDadosScreen extends StatelessWidget {
  const MaisDadosScreen({super.key, required this.aoAvancar, this.aoVoltar});

  final VoidCallback aoAvancar;
  final VoidCallback? aoVoltar;

  @override
  Widget build(BuildContext context) => EcraDeContexto(
    icone: Icons.playlist_add_check_outlined,
    titulo: 'Óptimo. Vamos afinar isto.',
    paragrafos: const [
      'Vais indicar mais alguns dados: colaboradores, veículos, máquinas e as '
          'receitas do último ano.',
      'Quanto mais completo, mais afinadas ficam as sugestões da tua semana — '
          'onde estás a perder dinheiro, o que está parado, o que já podes '
          'cobrar.',
      'Podes sempre voltar e editar em Definições da Empresa.',
    ],
    rotuloDoBotao: 'Continuar →',
    aoAvancar: aoAvancar,
    aoVoltar: aoVoltar,
  );
}
