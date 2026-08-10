import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/conflitos/sincronizacao_de_conflitos.dart';
import '../../core/operations/operations_controller.dart';
import '../../core/sync/registo_de_operacoes.dart';
import '../../core/sync/sincronizacao_entre_dispositivos.dart';
import '../../data/repositories/operation_repository.dart';
import '../auth/acesso_providers.dart';
import '../conflitos/conflitos_providers.dart';

/// Estado visível da sincronização, para a app poder dizer alguma coisa em vez
/// de mexer nos dados às escondidas.
enum EstadoSync { desligada, emEspera, aSincronizar, falhou }

class InfoSync {
  const InfoSync({
    required this.estado,
    this.pendentes = 0,
    this.ultimaVez,
    this.erro,
  });

  final EstadoSync estado;
  final int pendentes;
  final DateTime? ultimaVez;
  final String? erro;
}

/// Constrói o motor, ou `null` quando não há condições para sincronizar.
///
/// Existe como provider próprio para haver uma costura: nos testes substitui-se
/// por um duplo e exercita-se a política (quando sincronizar) sem rede, sem
/// Supabase e sem disco. Enquanto isto estava dentro do controlador, a política
/// era intestável — e é ela que tem os erros de ciclo de vida.
final motorSyncProvider = FutureProvider<SincronizacaoEntreDispositivos?>((
  ref,
) async {
  if (!SupabaseConfig.enabled) return null;
  final acesso = ref.watch(estadoAcessoProvider).valueOrNull;
  final empresaId = acesso?.empresaId;
  if (acesso == null || !acesso.membroAtivo || empresaId == null) return null;

  final repo = ref.read(operationRepositoryProvider);
  if (repo is! PersistentOperationRepository) return null;

  final registo = RegistoDeOperacoes(await SharedPreferences.getInstance());
  return SincronizacaoEntreDispositivos(
    repositorio: repo,
    registo: registo,
    cliente: Supabase.instance.client,
    empresaId: empresaId,
  );
});

/// Liga o repositório local à sincronização entre dispositivos.
///
/// Só arranca quando há **Supabase configurado, sessão iniciada e adesão activa
/// com empresa**. Fora disso fica desligada: em modo de demonstração não há
/// para onde sincronizar, e sem empresa não se adivinha qual é.
final syncProvider = NotifierProvider<SyncController, InfoSync>(
  SyncController.new,
);

/// Conflitos de reserva que o servidor barrou durante a sincronização
/// (`23P01`): saíram da fila para não a trancar, mas ficam aqui, **à parte da
/// quarentena**, para o gestor os ver e resolver (remarcar, recusar). Lê do
/// mesmo registo que o motor usa e é reavaliado a cada sincronização
/// (`SyncController.sincronizar`).
final conflitosDeReservaProvider = FutureProvider<List<OperacaoRecusada>>((
  ref,
) async {
  final motor = await ref.watch(motorSyncProvider.future);
  return motor?.registo.conflitosDeReserva ?? const [];
});

class SyncController extends Notifier<InfoSync> {
  SincronizacaoEntreDispositivos? _motor;
  RegistoDeOperacoes? _registo;
  // Conflitos pendentes (Fase 0, ver plano em curso): sem produtor ainda
  // (nem detecção nem banner), mas já sincroniza no mesmo temporizador em
  // vez de arranjar um segundo — mesmo raciocínio do `EmpresaSyncController`
  // para o estado operacional.
  SincronizacaoDeConflitos? _motorConflitos;
  Timer? _timer;
  Timer? _debounce;
  _ObservadorDeRegresso? _observador;
  RealtimeChannel? _canal;
  bool _vivo = true;

  /// De quanto em quanto tempo se volta a perguntar, com a app aberta.
  ///
  /// Cinco minutos e não trinta segundos: o que muda no terreno não muda ao
  /// segundo, e cada verificação é rede e bateria de quem está a trabalhar.
  static const _intervalo = Duration(minutes: 5);

  /// Espera depois de uma alteração local antes de enviar.
  ///
  /// Escrever uma reserva são vários `save` seguidos; sem esta pausa, cada
  /// tecla numa lista podia virar um pedido.
  static const _espera = Duration(seconds: 3);

  @override
  InfoSync build() {
    // O Riverpod reaproveita esta instância entre reconstruções, mas corre o
    // `onDispose` de cada uma antes da seguinte. Sem repor a bandeira aqui, o
    // primeiro `onDispose` deixava `_vivo` a `false` para sempre — e como o
    // motor só existe **depois** de o acesso resolver, ou seja depois de pelo
    // menos uma reconstrução, `sincronizar()` saía sempre na primeira linha,
    // em silêncio. A app dizia "em espera", a fila enchia e nada subia nem
    // descia. Foi assim que 15 máquinas ficaram presas no telemóvel.
    _vivo = true;
    ref.onDispose(() {
      _vivo = false;
      _timer?.cancel();
      _debounce?.cancel();
      final canal = _canal;
      _canal = null;
      if (canal != null) unawaited(canal.unsubscribe());
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
      }
    });

    final motor = ref.watch(motorSyncProvider).valueOrNull;
    if (motor == null) return const InfoSync(estado: EstadoSync.desligada);
    final motorConflitos = ref.watch(motorConflitosSyncProvider).valueOrNull;

    // `Future.microtask` e não `unawaited` directo: `_arrancar` corre até ao
    // primeiro `await` de forma síncrona, e lá dentro `sincronizar()` escreve
    // no `state` — escrever no estado a meio do próprio `build` é proibido pelo
    // Riverpod e rebentava a construção do provider.
    Future.microtask(() => _arrancar(motor, motorConflitos));
    return const InfoSync(estado: EstadoSync.emEspera);
  }

  Future<void> _arrancar(
    SincronizacaoEntreDispositivos motor,
    SincronizacaoDeConflitos? motorConflitos,
  ) async {
    try {
      await _montar(motor, motorConflitos);
    } catch (erro) {
      // Um erro aqui deixava a sincronização desligada sem ninguém saber: o
      // arranque corre numa microtarefa, e uma excepção lá dentro não tem quem
      // a apanhe. Silêncio é a pior forma de falhar numa coisa que só se nota
      // quando os dados não aparecem no outro telemóvel.
      debugPrint('[Sync] arranque falhou: $erro');
      state = InfoSync(estado: EstadoSync.falhou, erro: '$erro');
    }
  }

  Future<void> _montar(
    SincronizacaoEntreDispositivos motor,
    SincronizacaoDeConflitos? motorConflitos,
  ) async {
    _motor = motor;
    _motorConflitos = motorConflitos;
    _registo = motor.registo;

    // Cada alteração local entra em fila e agenda um envio.
    motor.ouvirAlteracoesLocais();
    // O repositório vem do motor e não de `ref.read`: isto corre numa
    // microtarefa, já depois de a dependência do provider ter mudado, e aí o
    // Riverpod recusa qualquer `ref` ("Cannot use ref functions after the
    // dependency of a provider changed"). O motor traz o mesmo objecto.
    final repo = motor.repositorio;
    final anterior = repo.aoRegistarOperacao;
    repo.aoRegistarOperacao = (entidade, id, payload) {
      anterior?.call(entidade, id, payload);
      _agendar();
    };

    // Duas reservas activas na mesma máquina, vindas de aparelhos diferentes,
    // deixam de se resolver em silêncio: fica registada a disputa para alguém
    // decidir. Sem esta linha, a infra de conflitos existia mas nunca era
    // chamada — estava construída e desligada desde a Fase 0.
    if (motorConflitos != null) {
      repo.aoDetectarConflito = (conflito) {
        unawaited(motorConflitos.registo.guardarLocal(conflito));
        _agendar();
      };
    }

    _observador = _ObservadorDeRegresso(() => unawaited(sincronizar()));
    WidgetsBinding.instance.addObserver(_observador!);
    _timer = Timer.periodic(_intervalo, (_) => unawaited(sincronizar()));

    // Antes da primeira sincronização: subir o que já estava no aparelho.
    // Depois de `ouvirAlteracoesLocais`, para as operações caírem na fila.
    final carga = await motor.cargaInicialSePreciso();

    _ligarCampainha(motor.empresaId);

    await sincronizar();

    // Só agora se dá a carga por feita: se o envio falhou, o próximo arranque
    // volta a tentar. Marcar antes de saber o resultado deixava os dados
    // presos no aparelho para sempre.
    if (carga > 0 && state.estado != EstadoSync.falhou) {
      await motor.marcarCargaInicialConcluida();
    } else if (carga == 0) {
      // Nada para subir (instalação de fresco): não vale a pena voltar a
      // percorrer tudo a cada arranque.
      await motor.marcarCargaInicialConcluida();
    }
  }

  /// Liga a campainha: os aparelhos da empresa avisam-se uns aos outros quando
  /// gravam alguma coisa.
  ///
  /// **O que chega é um aviso, não os dados.** Ao ouvir, faz-se o que já se
  /// fazia: puxar desde o cursor. A razão é que um WebSocket não é de confiança
  /// para entrega — cai, reconecta, e o que passou durante a queda perdeu-se.
  /// Aplicar o que chega deixaria buracos silenciosos nos dados; assim, o pior
  /// que uma campainha perdida causa é esperar pelo temporizador, que continua
  /// ligado de propósito.
  ///
  /// ## Porque é entre aparelhos e não a partir da base de dados
  ///
  /// O caminho melhor seria um trigger no `punho_operacoes` a chamar
  /// `realtime.send()` — funciona mesmo que quem escreveu feche a app logo a
  /// seguir. Está escrito e pronto (`supabase/punho_campainha_tempo_real.sql`),
  /// mas **não funciona neste projecto**: o `realtime.messages` é particionado
  /// por dia, o projecto não tem uma única partição, e o próprio Realtime
  /// recusa a subscrição com `MissingPartition`. Criar partições exige
  /// permissões no schema `realtime`, que não temos.
  ///
  /// Daí o canal ser **público**: um canal privado obriga o Realtime a validar
  /// as políticas contra o `realtime.messages` — e volta a esbarrar na mesma
  /// partição em falta.
  ///
  /// O que isso expõe: quem souber o UUID da empresa consegue ouvir "há
  /// novidades" e, no limite, provocar sincronizações extra. **Não há dados no
  /// canal** — nem payload, nem entidade, nem quem fez. O nome da empresa não
  /// vai lá, o UUID não é público, e o pior caso é gastar-se rede à toa.
  ///
  /// Falhar a ligar não é erro: sem campainha a app volta ao comportamento de
  /// antes, mais lenta e igualmente correcta. Por isso isto não mexe no
  /// [InfoSync] nem mostra nada ao utilizador.
  void _ligarCampainha(String empresaId) {
    try {
      _canal = Supabase.instance.client.channel('punho:empresa:$empresaId')
        ..onBroadcast(event: 'nova_operacao', callback: (_) => _agendar())
        ..subscribe((estado, erro) {
          if (estado == RealtimeSubscribeStatus.subscribed) {
            // Sincronizar SEMPRE ao (re)ligar, sem esperar por campainha: é
            // durante a queda que os avisos se perdem, e é ao voltar que se
            // apanha o que passou.
            unawaited(sincronizar());
          } else if (erro != null) {
            debugPrint('[Sync] campainha: $estado $erro');
          }
        });
    } catch (erro) {
      debugPrint('[Sync] campainha não ligou: $erro');
    }
  }

  /// Toca a campainha aos outros aparelhos, depois de termos enviado algo.
  ///
  /// Best-effort: se falhar, os outros vêem a novidade no temporizador
  /// seguinte. Nunca deve fazer barulho nem alterar o estado da sincronização.
  void _tocarCampainha() {
    final canal = _canal;
    if (canal == null) return;
    // O `payload` tem de ser um mapa **mutável**: o `realtime_client` escreve-lhe
    // dentro antes de enviar, e com um `const {}` rebentava com "Cannot modify
    // unmodifiable map" a cada envio. E o try/catch tinha de passar a envolver o
    // `await`: a excepção nascia dentro do future, não na chamada, por isso
    // escapava ao catch antigo e subia como erro não tratado — a campainha nunca
    // tocou uma única vez, e ninguém deu por isso.
    unawaited(() async {
      try {
        await canal.sendBroadcastMessage(
          event: 'nova_operacao',
          payload: <String, dynamic>{},
        );
      } catch (erro) {
        debugPrint('[Sync] não deu para tocar a campainha: $erro');
      }
    }());
  }

  void _agendar() {
    _debounce?.cancel();
    _debounce = Timer(_espera, () => unawaited(sincronizar()));
  }

  Future<void> sincronizar() async {
    final motor = _motor;
    if (motor == null || !_vivo) return;
    state = InfoSync(
      estado: EstadoSync.aSincronizar,
      pendentes: _registo?.pendentes.length ?? 0,
      ultimaVez: state.ultimaVez,
    );
    final resultado = await motor.sincronizar();
    if (!_vivo) return;

    // Best-effort e à parte do `InfoSync`: conflitos pendentes ainda não têm
    // consumidor nenhum (Fase 0), e mesmo quando tiverem, não são o mesmo
    // tipo de "houve alterações" que o resto desta função relata.
    final motorConflitos = _motorConflitos;
    if (motorConflitos != null) unawaited(motorConflitos.sincronizar());

    // O que chegou já está no repositório; falta o estado da app dar por isso.
    if (resultado.recebidas > 0) {
      ref.read(operationsProvider.notifier).recarregarDoRepositorio();
    }
    // Enviámos alguma coisa → avisar os outros aparelhos, para não esperarem
    // pelo temporizador.
    if (resultado.enviadas > 0) _tocarCampainha();
    // Um envio pode ter mandado uma reserva em conflito (23P01) para o balde:
    // reavaliar para a aba Estado do gestor o mostrar sem ter de reabrir a app.
    ref.invalidate(conflitosDeReservaProvider);
    state = InfoSync(
      estado: resultado.correu ? EstadoSync.emEspera : EstadoSync.falhou,
      pendentes: _registo?.pendentes.length ?? 0,
      ultimaVez: resultado.correu ? DateTime.now() : state.ultimaVez,
      erro: resultado.erro,
    );
  }
}

class _ObservadorDeRegresso extends WidgetsBindingObserver {
  _ObservadorDeRegresso(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}
