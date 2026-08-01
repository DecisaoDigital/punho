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
      // Ocupa o que sobra até à margem, em vez de 300 dp centrados.
      //
      // Centrada, esta caixa deixava 64,8 dp de vazio entre o último nome e a
      // margem direita — o resto do painel encosta a 15. E os 300 dp repartidos
      // por três davam 100 a cada nome: "Primeiro impulso" não cabe em 100 e
      // saía "Primeiro imp…", com o nome cortado ao lado do nome inteiro que já
      // está à esquerda.
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NomeDoSlide(
                  nome: activo > 0 ? nomes[activo - 1] : null,
                  onTap: activo > 0 ? () => onEscolher(activo - 1) : null,
                ),
              ),
            ),
            Expanded(
              child: Center(
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
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _NomeDoSlide(
                  nome: activo < nomes.length - 1 ? nomes[activo + 1] : null,
                  onTap: activo < nomes.length - 1
                      ? () => onEscolher(activo + 1)
                      : null,
                  // Este é o último da linha: desconta o seu próprio ar para a
                  // letra cair na margem, e não 4 dp aquém dela. À esquerda o
                  // "1/3 · …" é texto nu e encosta certo — sem isto, os dois
                  // extremos do rodapé não batiam um com o outro.
                  encostadoADireita: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _NomeDoSlide extends StatelessWidget {
  const _NomeDoSlide({
    required this.nome,
    required this.onTap,
    this.encostadoADireita = false,
  });
  final String? nome;
  final VoidCallback? onTap;

  /// Tira o ar do lado de fora, para a letra ficar à distância da margem que
  /// todos os outros textos têm.
  final bool encostadoADireita;

  @override
  Widget build(BuildContext context) {
    if (nome == null) return const SizedBox(height: 32);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.only(left: 4, right: encostadoADireita ? 0 : 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFF6B6A64),
      ),
      child: Text(nome!, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
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
