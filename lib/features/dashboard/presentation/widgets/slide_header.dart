import 'package:flutter/material.dart';

import '../../../../core/theme/punho_theme.dart';

/// Cabeçalho de um slide: ícone, nome e a pergunta de gestão a que os 4 KPIs
/// respondem. A pergunta é o que faz o slide ser um slide e não uma gaveta de
/// números.
class SlideHeader extends StatelessWidget {
  const SlideHeader({
    super.key,
    required this.icone,
    required this.nome,
    required this.pergunta,
    this.acoes,
  });

  final IconData icone;
  final String nome;
  final String pergunta;
  final Widget? acoes;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PunhoTheme.orange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icone, size: 19, color: PunhoTheme.navy),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              pergunta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      if (acoes != null) acoes!,
    ],
  );
}
