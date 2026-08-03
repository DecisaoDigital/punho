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
      // Os três nomes — anterior, activo, seguinte — são um conjunto único:
      // 50 dp entre cada um, encostados à margem direita (o resto do painel
      // encosta a 15, por isso o último nome desconta o seu próprio ar).
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (activo > 0) ...[
              Flexible(
                child: _NomeDoSlide(
                  nome: nomes[activo - 1],
                  onTap: () => onEscolher(activo - 1),
                ),
              ),
              const SizedBox(width: 50),
            ],
            Flexible(
              child: Text(
                nomes[activo],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: PunhoTheme.navyDeep,
                ),
              ),
            ),
            if (activo < nomes.length - 1) ...[
              const SizedBox(width: 50),
              Flexible(
                child: _NomeDoSlide(
                  nome: nomes[activo + 1],
                  onTap: () => onEscolher(activo + 1),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _NomeDoSlide extends StatelessWidget {
  const _NomeDoSlide({required this.nome, required this.onTap});
  final String nome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: const Color(0xFF6B6A64),
    ),
    child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis),
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
