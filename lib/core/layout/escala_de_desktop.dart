// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Medidas de referência do telemóvel deitado para que a app foi desenhada
/// (Redmi: ~873×392 dp, menos barras). Abaixo disto o layout aperta; acima,
/// sobra ar.
const double _larguraReferencia = 820;
const double _alturaReferencia = 392;

/// Até onde se amplia. A 1,25× um ecrã de 1080 px mostra o dobro do conteúdo
/// de um telemóvel deitado, ainda legível; a 1,5× (a barra lateral, de dez itens
/// de ~57 dp, ainda cabia) a letra já era de cartaz e a informação não crescia.
const double _escalaMaxima = 1.25;

/// Escala a interface inteira num ecrã grande (Windows), em vez de a esticar.
///
/// A app foi desenhada para um telemóvel deitado. Numa janela de 1920×1080 os
/// mesmos cartões ocupavam o ecrã todo com letra de 10 px e metade vazios.
/// Aqui a janela passa a ser vista como um telemóvel maior: o layout é
/// calculado num espaço lógico mais pequeno (`largura/escala × altura/escala`,
/// sempre pelo menos tão grande como o de referência) e depois ampliado. É o
/// mesmo desenho do telemóvel, mais fácil de ler, e os ecrãs, diálogos e
/// folhas — que vivem dentro do Navigator — ampliam com ele. O rato acerta
/// porque `Transform` também transforma os toques.
class EscalaDeDesktop extends StatelessWidget {
  const EscalaDeDesktop({super.key, required this.child});

  final Widget child;

  /// Escala a aplicar a uma janela deste tamanho. Visível para teste.
  static double escalaPara(Size janela) {
    if (janela.isEmpty) return 1;
    final s = math.min(
      janela.width / _larguraReferencia,
      janela.height / _alturaReferencia,
    );
    return s.clamp(1.0, _escalaMaxima);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final escala = escalaPara(mq.size);
    if (escala == 1.0) return child;
    final logico = Size(mq.size.width / escala, mq.size.height / escala);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: logico.width,
        maxHeight: logico.height,
        child: Transform.scale(
          scale: escala,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: logico.width,
            height: logico.height,
            child: MediaQuery(
              data: mq.copyWith(
                size: logico,
                padding: mq.padding / escala,
                viewPadding: mq.viewPadding / escala,
                viewInsets: mq.viewInsets / escala,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
