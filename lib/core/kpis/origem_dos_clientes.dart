// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import '../../domain/models/operations.dart';
import '../operations/operations_controller.dart';

/// Um canal por onde as pessoas nos conhecem, e o que ele rendeu no mês.
class CanalDeOrigem {
  const CanalDeOrigem(this.nome, this.contactos, this.convertidos);

  final String nome;

  /// Contactos criados no mês com esta origem.
  final int contactos;

  /// Desses, quantos já se tornaram clientes (até hoje).
  final int convertidos;

  /// 0..100; `null` sem contactos.
  double? get taxa => contactos == 0 ? null : convertidos * 100 / contactos;
}

/// **De onde vêm os contactos de um mês.** Conta pela data em que o contacto foi
/// criado e agrupa pela origem que o operador escolheu. WhatsApp e agenda já não
/// são escolhas (são por onde se fala, não de onde se vem): os contactos antigos
/// com esses valores contam como «Outro / não sei». Sem origem é um canal à
/// parte, para se ver quanto falta registar.
class OrigemDosClientes {
  const OrigemDosClientes(this.canais);

  /// Ordenados do que mais contactos trouxe para o que menos; só os que trouxeram.
  final List<CanalDeOrigem> canais;

  int get contactos => canais.fold(0, (s, c) => s + c.contactos);
  int get convertidos => canais.fold(0, (s, c) => s + c.convertidos);

  /// 0..100; `null` sem contactos.
  double? get taxa => contactos == 0 ? null : convertidos * 100 / contactos;

  /// O canal que mais clientes fez; em empate, o que teve mais contactos.
  /// `null` se ninguém converteu.
  CanalDeOrigem? get melhor {
    final fechados = canais.where((c) => c.convertidos > 0).toList()
      ..sort((a, b) {
        final porClientes = b.convertidos.compareTo(a.convertidos);
        return porClientes != 0
            ? porClientes
            : b.contactos.compareTo(a.contactos);
      });
    return fechados.isEmpty ? null : fechados.first;
  }
}

const nomeSemOrigem = 'Sem origem';

String _canal(LeadSource? origem) => switch (origem) {
  null => nomeSemOrigem,
  LeadSource.whatsapp ||
  LeadSource.agenda ||
  LeadSource.other => leadSourceLabel(LeadSource.other),
  final o => leadSourceLabel(o),
};

bool _converteu(Lead l) =>
    l.status == LeadStatus.converted || l.convertedCustomerId != null;

/// A origem dos contactos do mês de [mes] (só conta o ano e o mês).
OrigemDosClientes origemDosClientes(OperationsState state, DateTime mes) {
  final contactos = <String, int>{};
  final convertidos = <String, int>{};
  for (final l in state.leads) {
    if (l.createdAt.year != mes.year || l.createdAt.month != mes.month) {
      continue;
    }
    final c = _canal(l.source);
    contactos[c] = (contactos[c] ?? 0) + 1;
    if (_converteu(l)) convertidos[c] = (convertidos[c] ?? 0) + 1;
  }
  final canais = [
    for (final e in contactos.entries)
      CanalDeOrigem(e.key, e.value, convertidos[e.key] ?? 0),
  ]..sort((a, b) => b.contactos.compareTo(a.contactos));
  return OrigemDosClientes(canais);
}
