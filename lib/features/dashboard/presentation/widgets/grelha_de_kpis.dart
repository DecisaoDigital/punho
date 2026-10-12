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
      // Windows: 3 colunas × 3 linhas de cartões mais baixos (até 9 por ecrã),
      // em vez de 4 cartões esticados a metade do ecrã cada.
      if (Platform.isWindows) {
        final l = (restricoes.maxWidth - 2 * _entreCelulas) / 3;
        final a = (restricoes.maxHeight - 2 * _entreCelulas) / 3;
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: _entreCelulas,
          mainAxisSpacing: _entreCelulas,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: a <= 0 ? 1 : l / a,
          children: celulas,
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
