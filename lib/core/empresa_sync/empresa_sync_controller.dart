import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../operations/operations_controller.dart';
import 'empresa_sync_service.dart';
import 'ficha_pendente.dart';

/// A política de "guardar e insistir" para a ficha da empresa — sem Timer,
/// sem WidgetsBinding, só a lógica de quando algo fica pendente e quando se
/// dá por entregue. Separado do [EmpresaSyncController] pela mesma razão que
/// `SincronizacaoEntreDispositivos` está separado do `SyncController` em
/// `lib/features/sync/sync_providers.dart`: isto testa-se sem Riverpod, sem
/// relógio a sério e sem widget nenhum.
class EmpresaSyncEngine {
  EmpresaSyncEngine({required EmpresaSyncService sync, required this.pendente})
    : _sync = sync;

  final EmpresaSyncService _sync;
  final FichaEmpresaPendente pendente;

  // Evita duas tentativas em paralelo (o arranque e o temporizador a
  // coincidirem, ou duas chamadas a `atualizarFicha` seguidas).
  bool _aEnviar = false;

  /// A ficha mudou: fica gravada como a mais recente — substitui a anterior,
  /// não se acumula — e tenta-se entregá-la já, sem esperar pelo
  /// temporizador. Nunca lança: quem chama isto está a gravar dados da
  /// empresa ou a concluir o onboarding, e nenhum dos dois pode ficar preso à
  /// espera da rede.
  Future<void> atualizarFicha(Map<String, dynamic> payload) async {
    await pendente.guardar(payload);
    await tentarEnviar();
  }

  /// Tenta entregar a ficha pendente, se houver alguma.
  ///
  /// Só se dá por entregue quando a Edge Function confirma (`ok == true`);
  /// qualquer outra coisa — sem rede, EF fora do ar, resposta inesperada —
  /// mantém a pendência para a próxima tentativa.
  Future<void> tentarEnviar() async {
    if (_aEnviar) return;
    final ficha = pendente.ficha;
    if (ficha == null) return;
    // Já foi recusada e continua exactamente igual: insistir dá o mesmo. Basta
    // o gestor corrigir o que falta (o NIF, na campanha de testes) para a
    // assinatura mudar e isto voltar a tentar sozinho.
    if (pendente.jaFoiRecusadaAssim) return;
    _aEnviar = true;
    try {
      final resultado = await _sync.sincronizar(ficha);
      if (resultado.entregou) {
        await pendente.limpar();
      } else if (resultado.foiRecusada) {
        await pendente.marcarRecusada(resultado.recusa!);
      }
      // Adiada: fica tudo como está, tenta-se na próxima ronda.
    } finally {
      _aEnviar = false;
    }
  }
}

/// Liga o motor acima ao resto da app: um temporizador de 20 em 20 minutos e
/// um observador que retenta ao voltar do fundo — o mesmo par que o
/// `SyncController` usa para os dados operacionais, só que aqui não há nada
/// para mostrar ao utilizador (Decisão do Cesar: "Control" é vocabulário
/// interno, sincronizar a ficha não é gesto de quem usa a app).
///
/// Fica desligado em modo de demonstração (sem Supabase): não há para onde
/// enviar, e a ficha fica só no aparelho até haver sessão real.
class EmpresaSyncController extends Notifier<bool> {
  Timer? _timer;
  _ObservadorDeRegresso? _observador;
  bool _vivo = true;

  /// O motor só existe depois de `SharedPreferences.getInstance()` resolver
  /// — é `async`, não dá para ter pronto dentro do `build()` síncrono. Um
  /// [Completer] só, partilhado por `_arrancar` e por `atualizarFicha`, evita
  /// a corrida óbvia: sem ele, uma ficha gravada antes de o motor estar
  /// montado ficava só em memória até ao motor aparecer, e nesse meio tempo
  /// o arranque podia já ter verificado "há pendência?" e respondido que não.
  Completer<EmpresaSyncEngine>? _pronto;

  /// De 20 em 20 minutos: não é dado operacional, não há pressa nenhuma —
  /// pedido explícito do Cesar.
  static const intervalo = Duration(minutes: 20);

  /// `state` é só "há uma ficha por confirmar?" — não há UI a lê-lo, mas
  /// facilita testar o fio todo sem espiar o SharedPreferences por fora.
  @override
  bool build() {
    _vivo = true;
    ref.onDispose(() {
      _vivo = false;
      _timer?.cancel();
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
      }
    });

    final sync = ref.watch(empresaSyncProvider);
    if (sync == null) return false; // modo demo: nada para onde enviar.

    _pronto = Completer<EmpresaSyncEngine>();
    // `Future.microtask`, não `unawaited` directo: o resto do arranque lê e
    // escreve `SharedPreferences` (é `async`), e escrever em `state` a meio
    // do `build` é proibido pelo Riverpod.
    Future.microtask(() => _arrancar(sync));
    return false;
  }

  Future<void> _arrancar(EmpresaSyncService sync) async {
    final prefs = await SharedPreferences.getInstance();
    final motor = EmpresaSyncEngine(
      sync: sync,
      pendente: FichaEmpresaPendente(prefs),
    );
    // Resolve para quem já estava à espera (por exemplo, um `atualizarFicha`
    // chamado antes de o arranque terminar) antes de mais nada — é essa
    // ordem que evita a corrida descrita acima.
    _pronto?.complete(motor);
    if (!_vivo) return;
    _observador = _ObservadorDeRegresso(() => unawaited(_tentar()));
    WidgetsBinding.instance.addObserver(_observador!);
    _timer = Timer.periodic(intervalo, (_) => unawaited(_tentar()));
    // Havia alguma coisa por enviar de uma sessão anterior (app fechada com a
    // rede em baixo, por exemplo)? Tenta já, sem esperar pelos 20 minutos.
    await _tentarComMotor(motor);
  }

  Future<void> _tentar() async {
    final pronto = _pronto;
    if (pronto == null || !_vivo) return;
    // Mesmo temporizador de 20 em 20 minutos e o mesmo regresso do fundo
    // servem também o outro canal — o estado operacional completo (onboarding,
    // custos fixos, histórico mensal), que só sobe/desce pelo
    // `synchronizeRemote()` do `OperationsController`, nunca pela fila de
    // operações por entidade. Sem isto dependia de um botão manual em
    // Finanças, que ninguém carregava depois de gravar dados da empresa. Um
    // segundo temporizador só para isto seria redundante com este que já
    // existe.
    unawaited(ref.read(operationsProvider.notifier).synchronizeRemote());
    await _tentarComMotor(await pronto.future);
  }

  Future<void> _tentarComMotor(EmpresaSyncEngine motor) async {
    await motor.tentarEnviar();
    if (_vivo) state = motor.pendente.ficha != null;
  }

  /// Ponto de entrada para quem grava a ficha (Definições da Empresa, fim do
  /// onboarding): entrega o payload ao motor e tenta logo enviá-lo.
  ///
  /// Nunca lança e nunca bloqueia quem chama para além do necessário: se o
  /// motor ainda não estiver montado, espera por ele (é questão de um
  /// `SharedPreferences.getInstance()`, não de rede) e segue.
  Future<void> atualizarFicha(Map<String, dynamic> payload) async {
    state = true;
    final pronto = _pronto;
    if (pronto == null) return; // modo demo: nada para onde enviar.
    final motor = await pronto.future;
    await motor.atualizarFicha(payload);
    if (_vivo) state = motor.pendente.ficha != null;
  }
}

final empresaSyncControllerProvider =
    NotifierProvider<EmpresaSyncController, bool>(EmpresaSyncController.new);

class _ObservadorDeRegresso extends WidgetsBindingObserver {
  _ObservadorDeRegresso(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}
