import 'package:flutter/material.dart';

import '../../core/theme/punho_theme.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.compact = false,
    this.emFundoEscuro = false,
  });
  final bool compact;

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
      SizedBox(
        width: 38,
        height: 38,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Transform.scale(
            scale: 1.12,
            child: Image.asset(
              'assets/brand/punho_elo_operacao_v010.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Punho',
              style: TextStyle(
                color: emFundoEscuro ? Colors.white : PunhoTheme.navyDeep,
                fontSize: 21,
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
                    : PunhoTheme.navyDeep.withValues(alpha: 0.62),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
