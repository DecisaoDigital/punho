// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter/material.dart';

/// Uma barra: o nome à esquerda, o comprimento pelo [valor], o [texto] à direita.
class BarraDoGrafico {
  const BarraDoGrafico(this.nome, this.valor, this.texto);

  final String nome;
  final double valor;
  final String texto;
}

/// **Barras horizontais com título e legenda**, para os gráficos do painel que
/// comparam categorias (canais, máquinas, colaboradores). Preenche o cartão: as
/// barras repartem a altura e encolhem se forem muitas.
class GraficoDeBarras extends StatelessWidget {
  const GraficoDeBarras({
    super.key,
    required this.titulo,
    required this.legenda,
    required this.barras,
    required this.cor,
    this.vazio = 'Ainda sem dados para desenhar.',
  });

  final String titulo, legenda, vazio;
  final List<BarraDoGrafico> barras;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pequeno = tt.labelSmall?.copyWith(fontSize: 10);
    final maximo = barras.fold<double>(0, (m, b) => b.valor > m ? b.valor : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: pequeno?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: barras.isEmpty
              ? Center(child: Text(vazio, style: tt.bodySmall))
              : Column(
                  children: [
                    for (final b in barras)
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 78,
                              child: Text(
                                b.nome,
                                style: pequeno?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, caixa) {
                                  final largura = maximo <= 0
                                      ? 0.0
                                      : (caixa.maxWidth - 44) *
                                            b.valor /
                                            maximo;
                                  return Row(
                                    children: [
                                      Container(
                                        width: largura < 1 && b.valor > 0
                                            ? 1
                                            : largura,
                                        height: 10,
                                        color: cor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(b.texto, style: pequeno),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(width: 12, height: 6, color: cor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                legenda,
                style: pequeno?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
