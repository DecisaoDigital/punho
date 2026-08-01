import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/operations/operations_controller.dart';
import '../../core/sync/registo_de_operacoes.dart';
import '../../core/sync/sincronizacao_entre_dispositivos.dart';
import '../../data/repositories/operation_repository.dart';
import '../auth/acesso_providers.dart';

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

class SyncController extends Notifier<InfoSync> {
  SincronizacaoEntreDispositivos? _motor;
  RegistoDeOperacoes? _registo;
  Timer? _timer;
  Timer? _debounce;
  _ObservadorDeRegresso? _observador;
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
    ref.onDispose(() {
      _vivo = false;
      _timer?.cancel();
      _debounce?.cancel();
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
      }
    });

    final motor = ref.watch(motorSyncProvider).valueOrNull;
    if (motor == null) return const InfoSync(estado: EstadoSync.desligada);

    // `Future.microtask` e não `unawaited` directo: `_arrancar` corre até ao
    // primeiro `await` de forma síncrona, e lá dentro `sincronizar()` escreve
    // no `state` — escrever no estado a meio do próprio `build` é proibido pelo
    // Riverpod e rebentava a construção do provider.
    Future.microtask(() => _arrancar(motor));
    return const InfoSync(estado: EstadoSync.emEspera);
  }

  Future<void> _arrancar(SincronizacaoEntreDispositivos motor) async {
    _motor = motor;
    _registo = motor.registo;

    // Cada alteração local entra em fila e agenda um envio.
    motor.ouvirAlteracoesLocais();
    final repo = ref.read(operationRepositoryProvider);
    if (repo is PersistentOperationRepository) {
      final anterior = repo.aoRegistarOperacao;
      repo.aoRegistarOperacao = (entidade, id, payload) {
        anterior?.call(entidade, id, payload);
        _agendar();
      };
    }

    _observador = _ObservadorDeRegresso(() => unawaited(sincronizar()));
    WidgetsBinding.instance.addObserver(_observador!);
    _timer = Timer.periodic(_intervalo, (_) => unawaited(sincronizar()));
    await sincronizar();
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

    // O que chegou já está no repositório; falta o estado da app dar por isso.
    if (resultado.recebidas > 0) {
      ref.read(operationsProvider.notifier).recarregarDoRepositorio();
    }
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
