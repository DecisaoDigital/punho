import 'package:flutter/material.dart';

/// A mão do Punho — o símbolo da marca, o ficheiro verdadeiro.
///
/// Existe porque estava a ser desenhada em cada sítio outra vez, e porque num
/// deles não estava a ser desenhada de todo: o ecrã de boas-vindas abria com um
/// `Icons.back_hand_outlined`, a mão genérica do Material. «a mão no primeiro
/// bem-vindo não é a original, e quero que seja» — Cesar, 5/8/2026.
///
/// O ficheiro é um quadrado opaco de fundo branco (não tem transparência) com
/// cerca de 10% de margem à volta do desenho. Duas consequências, e as duas
/// estão resolvidas aqui:
///
/// * o fundo dos ecrãs claros é `#F5F7FA`, não é branco — pousar o quadrado tal
///   e qual deixava-lhe uma orla branca visível. O canto arredondado assume-o:
///   lê-se como o emblema da app, que é o que é;
/// * a margem do próprio ficheiro somava-se à do ecrã e encolhia o desenho. O
///   `scale` come-a, e o [lado] passa a ser mesmo o tamanho do que se vê.
///
/// As proporções vêm do lockup, onde estavam afinadas: 38 de lado para 10 de
/// raio, e `1.12` de escala.
class SimboloPunho extends StatelessWidget {
  const SimboloPunho({super.key, this.lado = 38});

  final double lado;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: lado,
    height: lado,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(lado * 10 / 38),
      child: Transform.scale(
        scale: 1.12,
        child: Image.asset(
          'assets/brand/punho_elo_operacao_v010.png',
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}
