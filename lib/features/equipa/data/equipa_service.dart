// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/funcao_na_equipa.dart';

/// A equipa de gestão: quem é gerente, quem é administrativa e o que esta não vê.
abstract class EquipaService {
  Future<FuncaoNaEquipa> minhaFuncao();
  Future<List<MembroDaEquipa>> listar();
  Future<void> definir(
    String userId, {
    required String funcao,
    required Set<String> ecrasOcultos,
  });
}

class SupabaseEquipaService implements EquipaService {
  SupabaseEquipaService(this._client);
  final SupabaseClient _client;

  @override
  Future<FuncaoNaEquipa> minhaFuncao() async {
    final linhas = await _client.rpc('punho_minha_funcao') as List<dynamic>;
    if (linhas.isEmpty) return FuncaoNaEquipa.gerente;
    return FuncaoNaEquipa.fromJson(
      Map<String, dynamic>.from(linhas.first as Map),
    );
  }

  @override
  Future<List<MembroDaEquipa>> listar() async {
    final linhas = await _client.rpc('punho_listar_equipa') as List<dynamic>;
    return [
      for (final l in linhas)
        MembroDaEquipa.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
  }

  @override
  Future<void> definir(
    String userId, {
    required String funcao,
    required Set<String> ecrasOcultos,
  }) async {
    await _client.rpc(
      'punho_definir_funcao',
      params: {
        'p_user_id': userId,
        'p_funcao': funcao,
        'p_ecras_ocultos': ecrasOcultos.toList(),
      },
    );
  }
}
