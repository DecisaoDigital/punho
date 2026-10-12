// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// O título de página do Windows: alinhado à esquerda, no eixo dos cartões, com
/// a mesma tipografia em todos os ecrãs (a dos «Funcionários»).
///
/// [accao] fica na mesma linha, à direita, para o título não custar altura nos
/// ecrãs que já começavam por um botão. Fora do Windows não desenha o título —
/// o telemóvel gasta cada dp — e devolve só a acção, encostada à direita.
class TituloDePagina extends StatelessWidget {
  const TituloDePagina({super.key, required this.texto, this.accao});

  final String texto;
  final Widget? accao;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return accao == null
          ? const SizedBox.shrink()
          : Align(alignment: Alignment.centerRight, child: accao);
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estiloDoTituloDePagina(context),
          ),
        ),
        if (accao != null) accao!,
      ],
    );
  }
}

/// A tipografia única dos títulos de página.
TextStyle? estiloDoTituloDePagina(BuildContext context) => Theme.of(
  context,
).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
