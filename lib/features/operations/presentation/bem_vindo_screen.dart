import 'package:flutter/material.dart';

import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../shared/widgets/simbolo_punho.dart';
import 'ecra_de_contexto.dart';

/// Primeiro ecrã de quem entra na Punho depois de o pedido ser aprovado.
///
/// Pedido por o César a 5 de Agosto de 2026: «nesta nova entrada depois da
/// aceitação do pedido de licença, gostaria de ver um "bem-vindo!" e pequena
/// explicação do que é o Punho».
///
/// O que ele apanhou foi entrar numa app que nunca lhe tinha sido apresentada e
/// ser recebido com um formulário — «Forma jurídica e NIF da empresa». Quem
/// pediu acesso, esperou pela aprovação e voltou merece saber onde chegou antes
/// de lhe pedirem mais alguma coisa.
///
/// **Não repete o [BoasVindasScreen]**, que fecha o onboarding e trata da
/// entrada (e da rotação). Este abre-o: cumprimenta pelo nome e diz ao que a
/// app vem, antes de lhe ser pedido o primeiro dado.
///
/// O texto é do Cesar, escrito por ele a 5 de Agosto de 2026 e usado tal e
/// qual. **Não é para reescrever**: o que aqui está é a apresentação do
/// produto pela voz de quem o vende. Só o nome muda, e é dele.
///
/// A primeira versão deste ecrã dizia a que empresa o acesso tinha sido
/// aprovado e quantas perguntas faltavam. Saíram as duas: quem acabou de ser
/// aprovado sabe a que empresa pediu, e o contador do passo seguinte já diz
/// quantas faltam. O que ficou é o que só aqui se pode dizer.
///
/// Só aparece quando se sabe o nome de quem entra, que é o mesmo que dizer:
/// quando houve pedido aprovado. Em modo de demonstração não há aprovação
/// nenhuma e o onboarding começa como sempre começou.
class BemVindoScreen extends StatefulWidget {
  const BemVindoScreen({
    super.key,
    required this.nome,
    required this.aoAvancar,
  });

  /// Como a pessoa se apresentou no pedido de acesso.
  final String nome;

  final VoidCallback aoAvancar;

  @override
  State<BemVindoScreen> createState() => _BemVindoScreenState();
}

class _BemVindoScreenState extends State<BemVindoScreen> {
  @override
  void initState() {
    super.initState();
    // Portrait como todo o onboarding. Quem roda é o ecrã de entrada, no fim.
    OrientacaoDoContexto.portraitJa();
  }

  @override
  Widget build(BuildContext context) {
    return EcraDeContexto(
      // A mão do Punho — a nossa, não a do Material. «a mão no primeiro
      // bem-vindo não é a original, e quero que seja» — Cesar, 5/8/2026.
      simbolo: const SimboloPunho(lado: 56),
      titulo: 'Bem-vindo, ${widget.nome}.',
      paragrafos: const [
        'O teu acesso ao Punho está activo.',
        'O Punho é a sala de controlo da tua empresa: leads, cobranças, '
            'serviços, gastos e lucros num só sítio. Vês tudo à distância, em '
            'dois cliques, sem precisares de saber contabilidade.',
        'Não é só para controlar. É para decidir.',
        'O Punho foi feito para quem quer crescer sem se perder em papelada.',
      ],
      // A última linha é uma máxima, não é mais um parágrafo: fecha o texto e
      // muda de registo. Como sexta linha cinzenta perdia-se; num destaque
      // discreto — regra à esquerda, itálico — lê-se como o remate que é. O
      // `rodape` da casa é uma caixa cheia, e essa cor de aviso dá-lhe uma
      // urgência que a frase não tem.
      rodape: const _Maxima('O que não é medido, não é gerido.'),
      rotuloDoBotao: 'Vamos a isto',
      aoAvancar: widget.aoAvancar,
    );
  }
}

class _Maxima extends StatelessWidget {
  const _Maxima(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cores.primary, width: 3)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: cores.onSurface,
        ),
      ),
    );
  }
}
