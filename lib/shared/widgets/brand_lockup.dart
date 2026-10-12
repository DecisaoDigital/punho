// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter/material.dart';

import '../../core/theme/punho_theme.dart';
import 'simbolo_punho.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.compact = false,
    this.emFundoEscuro = false,
    this.grande = false,
  });
  final bool compact;

  /// Ecrã de entrada: símbolo ao dobro e letras maiores.
  final bool grande;

  /// O lockup vive em dois sítios de fundo oposto: a barra lateral e o cadeado
  /// são navy, o onboarding e os ecrãs de conta são claros.
  ///
  /// As cores estiveram fixas em branco, escolhidas para o navy — e nos ecrãs
  /// claros o nome da marca ficava branco sobre branco, invisível. Quem sabe o
  /// fundo é quem coloca o lockup, e é por isso que isto se diz de fora: um
  /// widget não tem como ler o que está pintado atrás dele.
  final bool emFundoEscuro;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SimboloFist(lado: grande ? 76 : 38),
      if (!compact) ...[
        SizedBox(width: grande ? 16 : 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fist',
              style: TextStyle(
                color: emFundoEscuro ? Colors.white : FistTheme.navyDeep,
                fontSize: grande ? 30 : 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Agarra o comando.',
              style: TextStyle(
                // O mesmo papel dos dois lados: um cinza que se lê sem competir
                // com o nome. No navy é o azulado claro de sempre; no claro, o
                // navy esbatido — e não um cinza neutro, que ao lado do nome
                // parecia de outra marca.
                color: emFundoEscuro
                    ? const Color(0xFFB7C5CE)
                    : FistTheme.navyDeep.withValues(alpha: 0.62),
                fontSize: grande ? 15 : 11,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
