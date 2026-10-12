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

/// Os quatro KPIs de um slide, 2×2, sempre inteiros no ecrã.
///
/// Os slides usavam `GridView.count` com `childAspectRatio` fixo — 2,2 em dois
/// deles, 1,8 no terceiro. Uma proporção fixa tira a altura da célula da
/// largura e ignora a altura que existe de facto: no telemóvel deitado davam
/// 277 dp para um espaço de 231, e a linha de baixo era cortada a meio. O
/// número aparecia, o rodapé do cartão não.
///
/// Aqui a conta é ao contrário: mede-se o espaço e divide-se em duas linhas e
/// duas colunas. A proporção é o que sair daí. Um KPI cortado não é um KPI —
/// quem olha para o painel tem de ver os quatro de uma vez, que é a razão de o
/// painel existir.
class GrelhaDeKpis extends StatelessWidget {
  const GrelhaDeKpis({super.key, required this.celulas});

  final List<Widget> celulas;

  /// Ar entre células, nos dois eixos.
  static const _entreCelulas = 10.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, restricoes) {
      // Windows: 3 colunas × 2 linhas (até 6 KPIs por ecrã). A última linha, se
      // incompleta, reparte a largura toda.
      if (Platform.isWindows && celulas.isNotEmpty) {
        final n = celulas.length;
        const colunas = 3;
        final linhas = (n + colunas - 1) ~/ colunas;
        // Duas linhas de altura fixa, mesmo com menos KPIs: os cartões não
        // crescem quando há poucos (decisão do Cesar, 12 Out 2026).
        return Column(
          children: [
            for (var r = 0; r < 2; r++) ...[
              if (r > 0) const SizedBox(height: _entreCelulas),
              Expanded(
                child: r >= linhas
                    ? const SizedBox.shrink()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var i = r * colunas;
                            i < n && i < (r + 1) * colunas;
                            i++
                          ) ...[
                            if (i > r * colunas)
                              const SizedBox(width: _entreCelulas),
                            Expanded(child: celulas[i]),
                          ],
                          // Linha incompleta: as colunas mantêm a largura das
                          // de cima (grelha 3×2 consistente), sem cartões
                          // largos desproporcionados.
                          for (
                            var i = n - r * colunas;
                            i < colunas && n - r * colunas < colunas;
                            i++
                          ) ...[
                            const SizedBox(width: _entreCelulas),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ],
                      ),
              ),
            ],
          ],
        );
      }
      final largura = (restricoes.maxWidth - _entreCelulas) / 2;
      final altura = (restricoes.maxHeight - _entreCelulas) / 2;
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: _entreCelulas,
        mainAxisSpacing: _entreCelulas,
        // Sem scroll: se a grelha rolasse, um KPI fora de vista continuaria a
        // ser um KPI que não se vê.
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: altura <= 0 ? 1 : largura / altura,
        children: celulas,
      );
    },
  );
}
