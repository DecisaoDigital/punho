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
      // O ponto desenha 8 dp e o alvo tinha 16 — um terço do mínimo de 48.
      //
      // A linha já mede 32 dp de altura, imposta pelos botões dos nomes ao
      // lado, portanto **subir o alvo a 32 não custa um pixel de painel**. Em
      // largura fica-se por 26: com 5 dp entre pontos, alvos mais largos
      // sobrepunham-se e passava-se a tocar no ponto errado, que é pior do que
      // um alvo pequeno.
      //
      // Não chega a 48, e é uma escolha e não um esquecimento: 48 obrigava a
      // engordar a barra ou a afastar os pontos até já não se lerem como um
      // grupo. O que torna isto aceitável é o ponto ser um atalho — o carrossel
      // anda a swipe (`PageView`), com setas de teclado, e os nomes dos slides
      // ao lado são alvos grandes para a mesma acção.
      child: SizedBox(
        height: 32,
        width: activo ? 34 : 26,
        child: Center(
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
    ),
  );
}
