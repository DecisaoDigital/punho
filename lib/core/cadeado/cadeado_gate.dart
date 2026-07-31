import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../orientacao/orientacao_do_contexto.dart';
import 'cadeado_service.dart';
import 'lock_screen.dart';

/// Envolve o resto da app. Escuta o lifecycle e activa o [cadeadoBloqueadoProvider]
/// quando é necessário desbloquear. Ao mostrar [LockScreen], não desmonta o
/// [child] — apenas o sobrepõe (para o utilizador retomar exactamente onde
/// estava).
class CadeadoGate extends ConsumerStatefulWidget {
  const CadeadoGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CadeadoGate> createState() => _CadeadoGateState();
}

class _CadeadoGateState extends ConsumerState<CadeadoGate>
    with WidgetsBindingObserver {
  bool _iniciado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: se PIN definido, bloquear já
    WidgetsBinding.instance.addPostFrameCallback((_) => _coldStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _coldStart() async {
    if (_iniciado) return;
    _iniciado = true;
    final svc = ref.read(cadeadoServiceProvider);
    if (await svc.temPinDefinido()) {
      _bloquear();
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final svc = ref.read(cadeadoServiceProvider);
    if (!await svc.temPinDefinido()) return;

    // Já bloqueado não há nada a fazer, e é também assim que se ignora o
    // ciclo do próprio prompt de biometria: ele rouba o foco à app e o Flutter
    // anuncia isso como saída.
    //
    // Antes isto dependia de uma marca no serviço (`aPedirBiometria`). Uma
    // marca que fica presa a `true` — e basta o prompt morrer de forma
    // estranha — desligava o cadeado para sempre: era o "saio da app, volto, e
    // não me pede o PIN". Ler o estado em vez de uma marca não pode encravar.
    if (ref.read(cadeadoBloqueadoProvider)) return;

    // `inactive` de fora: dispara ao puxar a barra de notificações, ao receber
    // uma chamada, no multitarefa. Nada disso é sair da app, e carimbar o
    // relógio a cada um destes deixava o cadeado a disparar por nada.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      await svc.registarPaused();
    } else if (state == AppLifecycleState.resumed) {
      if (await svc.deveBloquearAoRetomar()) {
        if (!mounted) return;
        _bloquear();
      }
    }
  }

  void _bloquear() {
    // Rearmar antes de mostrar: cada bloqueio novo merece uma tentativa
    // automática de digital, mas só uma.
    LockScreen.rearmar();
    ref.read(cadeadoBloqueadoProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = ref.watch(cadeadoBloqueadoProvider);
    // A orientação é decidida **aqui**, pelo estado, e não no `initState` /
    // `dispose` do ecrã de bloqueio.
    //
    // Estava lá, e no primeiro arranque a app dava voltas: landscape, retrato,
    // landscape, retrato, enquanto tentava ler a digital. O ecrã de bloqueio
    // monta e desmonta mais vezes do que parece — a resolução do acesso, o
    // banner de actualização e o próprio prompt do sistema mexem na árvore — e
    // a orientação ia atrás de cada uma dessas voltas.
    //
    // Ligada ao estado, roda uma vez ao bloquear e uma vez ao abrir.
    if (bloqueado) {
      OrientacaoDoContexto.sobreporJa(Orientacao.portrait);
    } else {
      OrientacaoDoContexto.largarSobreposicaoJa();
    }
    return Stack(children: [widget.child, if (bloqueado) const LockScreen()]);
  }
}
