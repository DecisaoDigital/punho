import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import '../config/supabase_config.dart';
import 'fichas_postas_de_lado.dart';
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
  const SincronizacaoFichaEmpresa(this._repository, {this.postasDeLado});

  final PersistentOperationRepository _repository;

  /// Onde fica o que este aparelho tinha por enviar quando cedeu ao servidor.
  ///
  /// Opcional para quem só quer sincronizar sem contar a história — mas a app
  /// passa-o sempre. Ver [receberDoServidor].
  final RegistoDeFichasPostasDeLado? postasDeLado;

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
      //
      // O que **não** se mantém é o silêncio com que isto era feito. Ver
      // [receberDoServidor].
      if (_repository.remoteRevision != remoteRevision) {
        final payload = Map<String, dynamic>.from(remote['payload'] as Map);
        final chegou = await receberDoServidor(
          jsonEncode(payload),
          revisao: remoteRevision,
        );
        if (!chegou) return SyncStatus.requiresReview;
        // Acaba sempre aqui: o que vinha por subir cedeu ao servidor, e a
        // importação limpa a marca de "por subir". Havia um `_push` a seguir a
        // isto, para o painel poder subir na mesma passagem — o painel saiu
        // deste canal na Fase 3 e o `_push` passou a ser código que nunca
        // corria.
        return SyncStatus.synchronized;
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

  /// Recebe a ficha do servidor por cima da local — e **põe de lado** a que ia
  /// subir, em vez de a deitar fora sem dizer nada.
  ///
  /// A regra continua a ser a mesma: velho perde. O que muda é que a perda
  /// deixa de ser invisível. Enquanto foi, isto acontecia assim: o gestor
  /// escrevia os custos fixos no telemóvel sem rede; voltava a haver rede; a
  /// revisão do servidor já era outra porque alguém tinha mexido na ficha
  /// noutro aparelho; a importação escrevia por cima, punha
  /// `hasPendingRemoteChanges` a `false` — e as rubricas que ele tinha acabado
  /// de escrever não estavam em sítio nenhum. Nem no servidor, nem no
  /// telemóvel, nem num aviso. A app dava a sincronização por boa.
  ///
  /// Guarda-se **antes** de importar, porque a importação escreve por cima do
  /// que se quer guardar, e persiste-se **depois**, só se ela tiver corrido
  /// bem: uma ficha que não chegou a entrar não deitou nada fora.
  ///
  /// Devolve falso se o payload do servidor não deu para ler — aí ninguém
  /// perdeu nada, e quem chama trata disso.
  @visibleForTesting
  Future<bool> receberDoServidor(String payload, {required int revisao}) async {
    final porSubir = _repository.hasPendingRemoteChanges
        ? _repository.exportarFichaDaEmpresa()
        : null;
    final revisaoLocal = _repository.remoteRevision;

    final chegou = _repository.importarFichaDaEmpresa(
      payload,
      revision: revisao,
    );
    if (!chegou) return false;

    if (porSubir != null) {
      await postasDeLado?.guardar(
        FichaPostaDeLado(
          quando: DateTime.now().toUtc(),
          revisaoLocal: revisaoLocal,
          revisaoDoServidor: revisao,
          payload: porSubir,
        ),
      );
    }
    return true;
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
