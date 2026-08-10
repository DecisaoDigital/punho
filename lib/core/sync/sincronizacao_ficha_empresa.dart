import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import '../config/supabase_config.dart';
import 'sync_engine.dart';

/// **A ficha da empresa, e mais nada:** o onboarding (com os custos fixos) e o
/// histórico mensal, pelo instantâneo `punho_estado_operacional`.
///
/// ## Os três canais desta app
///
/// | Canal | O quê | Quem ganha |
/// |---|---|---|
/// | [SincronizacaoOperacionalPorOperacoes] | máquinas, clientes, leads, reservas, despesas, recebimentos, colaboradores, veículos | a última a chegar ao servidor (`seq`) |
/// | **este** | onboarding, custos fixos, histórico mensal | o servidor: revisão diferente, o local cede |
/// | `SincronizacaoDoPainel` | o arranjo do painel do gestor | o carimbo mais recente de quem arrumou |
///
/// Cada coisa tem um dono, e é essa a invariante que a Fase 3 veio repor. Este
/// canal chamava-se `SupabaseOperationalSync` e o nome dizia o contrário do que
/// ele agora é — «operational» é a palavra do canal de cima. Enquanto o payload
/// levava as entidades à boleia, era este que mandava nelas, e mandava com
/// dados velhos: a 4 de Agosto de 2026 um trabalho fechado voltava sozinho a
/// «em curso» segundos depois, sem erro nenhum a dizê-lo.
///
/// ## Porque é que o colaborador não passa por aqui
///
/// O payload tem custos e finanças. Quando o perfil não é de gestor, isto
/// chama `naoGuardarNoAparelho()` e sai: no telemóvel do operador não fica nada
/// da empresa entre arranques. O trabalho dele sobe e desce pelo canal das
/// operações, que tem permissões por entidade e por campo.
class SincronizacaoFichaEmpresa {
  const SincronizacaoFichaEmpresa(this._repository);

  final PersistentOperationRepository _repository;

  Future<SyncStatus> synchronize() async {
    if (!SupabaseConfig.enabled) return SyncStatus.synchronized;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return SyncStatus.pendingChanges;

    try {
      final member = await client
          .from('punho_membros')
          .select('empresa_id, perfil')
          .eq('user_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
      if (member == null) return SyncStatus.requiresReview;
      if (member['perfil'] != 'gestor') {
        // No telemóvel do operador não fica nada da empresa entre arranques.
        // O perfil vem daqui, de `punho_membros`, e não de nada que a app
        // tenha guardado — quem decide o que este aparelho é não é ele.
        _repository.naoGuardarNoAparelho();
        return SyncStatus.synchronized;
      }

      final empresaId = member['empresa_id'] as String;
      final remote = await client
          .from('punho_estado_operacional')
          .select('revision, payload')
          .eq('empresa_id', empresaId)
          .maybeSingle();

      if (remote == null) {
        if (!_repository.hasPendingRemoteChanges) {
          return SyncStatus.synchronized;
        }
        return _push(client, expectedRevision: null);
      }

      final remoteRevision = (remote['revision'] as num).toInt();

      // **O servidor manda.**
      //
      // Se a revisão que lá está não é a que este aparelho conhece, o que ele
      // tem é velho — e velho perde, mesmo que tenha alterações por subir.
      // Um telemóvel que esteve uma semana sem rede abre a app e recebe a
      // ficha como ela está agora; não a impõe de volta com o que sabia
      // quando se desligou.
      //
      // Isto substituiu uma paragem: dava `requiresReview` e a sincronização
      // ficava encravada até alguém intervir — só que não há ninguém a
      // intervir, e o aparelho ficava indefinidamente a mostrar uma ficha que
      // já não era a da empresa.
      if (_repository.remoteRevision != remoteRevision) {
        final payload = Map<String, dynamic>.from(remote['payload'] as Map);
        final chegou = _repository.importarFichaDaEmpresa(
          jsonEncode(payload),
          revision: remoteRevision,
        );
        if (!chegou) return SyncStatus.requiresReview;
        // Quase sempre acaba aqui: o que vinha por subir cedeu ao servidor e
        // não há mais nada a fazer. A excepção é o painel — a arrumação deste
        // aparelho sobrevive à importação, e sobe **já**, na mesma passagem.
        // Deixá-la para o ciclo seguinte era voltar a expô-la à mesma janela
        // que a fazia desaparecer.
        if (!_repository.hasPendingRemoteChanges) {
          return SyncStatus.synchronized;
        }
        return _push(client, expectedRevision: remoteRevision);
      }

      // Revisões iguais: o que este aparelho tem por subir foi escrito **em
      // cima** do que está no servidor. Só essas alterações sobem — e passam a
      // ser a verdade para todos os outros.
      if (!_repository.hasPendingRemoteChanges) return SyncStatus.synchronized;
      return _push(client, expectedRevision: remoteRevision);
    } on PostgrestException {
      return SyncStatus.requiresReview;
    } catch (_) {
      return SyncStatus.pendingChanges;
    }
  }

  Future<SyncStatus> _push(
    SupabaseClient client, {
    required int? expectedRevision,
  }) async {
    try {
      final revision = await client.rpc(
        'punho_guardar_estado_operacional',
        params: {
          'novo_payload': jsonDecode(_repository.exportarFichaDaEmpresa()),
          'revisao_esperada': expectedRevision,
        },
      );
      _repository.markRemoteSynchronized((revision as num).toInt());
      return SyncStatus.synchronized;
    } on PostgrestException {
      // Alguém escreveu entre a leitura e esta escrita, e a função recusou por
      // a revisão já não bater certo. Não é caso de revisão humana: na volta
      // seguinte a revisão remota já é outra, o servidor manda, e este
      // aparelho recebe o que lá está.
      return SyncStatus.pendingChanges;
    } catch (_) {
      return SyncStatus.pendingChanges;
    }
  }
}
