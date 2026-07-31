import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/operations/operations_controller.dart';
import 'data/leads_entrada_service.dart';

final leadsEntradaServiceProvider = Provider<LeadsEntradaService>(
  (ref) => LeadsEntradaService(Supabase.instance.client),
);

/// As leads que chegaram de fora e esperam um toque do gestor.
///
/// Só as `retida`. As `aceite` não param aqui — entram no pipeline sozinhas,
/// que é o ponto: uma caixa de entrada que obriga a aprovar tudo é só outro
/// sítio para acumular trabalho.
final leadsRetidasProvider =
    NotifierProvider<LeadsEntradaController, List<LeadEntrada>>(
      LeadsEntradaController.new,
    );

class LeadsEntradaController extends Notifier<List<LeadEntrada>> {
  bool _aPuxar = false;

  @override
  List<LeadEntrada> build() {
    if (!SupabaseConfig.enabled) return const [];
    unawaited(puxar());
    return const [];
  }

  /// Vai buscar o que está por processar: as aceites entram já no pipeline, as
  /// retidas ficam à espera de decisão.
  Future<void> puxar() async {
    // Duas chamadas ao mesmo tempo criariam a mesma lead duas vezes — o arranque
    // e o regresso do background podem coincidir.
    if (_aPuxar) return;
    _aPuxar = true;
    try {
      final servico = ref.read(leadsEntradaServiceProvider);
      final entradas = await servico.porProcessar();
      final retidas = <LeadEntrada>[];
      for (final entrada in entradas) {
        if (!entrada.aceite) {
          retidas.add(entrada);
          continue;
        }
        await _aceitar(entrada);
      }
      state = retidas;
    } catch (erro) {
      debugPrint('[LeadsEntrada] puxar falhou: $erro');
    } finally {
      _aPuxar = false;
    }
  }

  /// O gestor aceitou uma retida na triagem.
  Future<void> aceitar(LeadEntrada entrada) async {
    await _aceitar(entrada);
    state = state.where((e) => e.id != entrada.id).toList();
  }

  /// O gestor descartou. Marca-se como processada **sem criar lead** — a linha
  /// fica no servidor com o registo de que chegou, porque apagar tornaria
  /// impossível distinguir um canal que não trouxe nada de um canal que trouxe
  /// lixo.
  Future<void> descartar(LeadEntrada entrada) async {
    await ref.read(leadsEntradaServiceProvider).marcarProcessada(entrada.id);
    state = state.where((e) => e.id != entrada.id).toList();
  }

  Future<void> _aceitar(LeadEntrada entrada) async {
    // O id local deriva do id do servidor: se a mesma entrada for processada
    // duas vezes por engano, escreve por cima da mesma lead em vez de criar uma
    // segunda.
    final idLocal = 'entrada-${entrada.id}';
    ref.read(operationsProvider.notifier).addLead(entrada.paraLead(idLocal));
    await ref
        .read(leadsEntradaServiceProvider)
        .marcarProcessada(entrada.id, leadLocalId: idLocal);
  }
}
