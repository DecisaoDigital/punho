// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

enum SyncStatus { synchronized, syncing, pendingChanges, requiresReview }

class OutboxEvent {
  const OutboxEvent({
    required this.id,
    required this.empresaId,
    required this.kind,
    required this.payload,
  });
  final String id, empresaId, kind;
  final Map<String, Object?> payload;
}

class LocalOutbox {
  final _events = <String, OutboxEvent>{};
  void enqueue(OutboxEvent event) => _events.putIfAbsent(event.id, () => event);
  List<OutboxEvent> forCompany(String id) =>
      _events.values.where((e) => e.empresaId == id).toList();
  void acknowledge(String id) => _events.remove(id);
}

class SyncEngine {
  SyncEngine(this.outbox);
  final LocalOutbox outbox;
  SyncStatus status = SyncStatus.synchronized;
  Future<void> synchronize(
    String empresaId,
    Future<bool> Function(OutboxEvent) send,
  ) async {
    status = SyncStatus.syncing;
    for (final event in List.of(outbox.forCompany(empresaId))) {
      final ok = await send(event);
      if (ok) {
        outbox.acknowledge(event.id);
      } else {
        status = SyncStatus.requiresReview;
        return;
      }
    }
    status = outbox.forCompany(empresaId).isEmpty
        ? SyncStatus.synchronized
        : SyncStatus.pendingChanges;
  }
}

class CompanyScope<T> {
  CompanyScope(this.empresaId, this.items);
  final String empresaId;
  final List<ScopedRecord<T>> items;
  List<T> visibleTo(String empresaId) =>
      items.where((x) => x.empresaId == empresaId).map((x) => x.value).toList();
}

class ScopedRecord<T> {
  const ScopedRecord(this.empresaId, this.value);
  final String empresaId;
  final T value;
}
