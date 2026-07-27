import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recomendações adiadas: id → data a partir da qual voltam a aparecer.
///
/// Vive só em memória, de propósito nesta versão: persistir implicava mais um
/// campo no armazenamento local e a decisão de o sincronizar. Consequência
/// assumida — fechar a app esquece os adiamentos. Está registado no backlog.
final recomendacoesAdiadasProvider =
    NotifierProvider<RecomendacoesAdiadas, Map<String, DateTime>>(
      RecomendacoesAdiadas.new,
    );

class RecomendacoesAdiadas extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  /// Adia por [dias]. A recomendação sai do painel e passa a constar em Tarefas
  /// como sugestão — adiar não é apagar.
  void adiar(String id, DateTime agora, {int dias = 7}) {
    state = {...state, id: agora.add(Duration(days: dias))};
  }

  /// Marcada como feita: não volta nesta sessão.
  void concluir(String id, DateTime agora) {
    state = {...state, id: agora.add(const Duration(days: 3650))};
  }

  void limpar(String id) {
    final novo = {...state}..remove(id);
    state = novo;
  }
}
