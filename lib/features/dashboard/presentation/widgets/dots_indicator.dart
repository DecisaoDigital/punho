import 'package:flutter/material.dart';

import '../../../../core/theme/punho_theme.dart';

/// Barra do fundo do carrossel: "1/5 · Dinheiro" à esquerda, os restantes
/// slides clicáveis à direita.
///
/// Os nomes dos outros slides ficam à vista de propósito — com só bolinhas, o
/// utilizador não sabe o que está a perder de cada lado e não navega.
class DotsIndicator extends StatelessWidget {
  const DotsIndicator({
    super.key,
    required this.nomes,
    required this.activo,
    required this.onEscolher,
  });

  final List<String> nomes;
  final int activo;
  final ValueChanged<int> onEscolher;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '${activo + 1}/${nomes.length} · ${nomes[activo]}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      const SizedBox(width: 12),
      for (var i = 0; i < nomes.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: _Ponto(activo: i == activo, onTap: () => onEscolher(i)),
        ),
      const Spacer(),
      Flexible(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            children: [
              for (var i = 0; i < nomes.length; i++)
                if (i != activo)
                  TextButton(
                    onPressed: () => onEscolher(i),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF6B6A64),
                    ),
                    child: Text(nomes[i]),
                  ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Ponto extends StatelessWidget {
  const _Ponto({required this.activo, required this.onTap});
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: activo,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: activo ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: activo ? PunhoTheme.orange : const Color(0xFFCFD6DB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}
