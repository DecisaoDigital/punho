import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ref.read(cadeadoBloqueadoProvider.notifier).state = true;
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final svc = ref.read(cadeadoServiceProvider);
    if (!await svc.temPinDefinido()) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      await svc.registarPaused();
    } else if (state == AppLifecycleState.resumed) {
      if (await svc.deveBloquearAoRetomar()) {
        if (!mounted) return;
        ref.read(cadeadoBloqueadoProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = ref.watch(cadeadoBloqueadoProvider);
    return Stack(
      children: [
        widget.child,
        if (bloqueado) const LockScreen(),
      ],
    );
  }
}
