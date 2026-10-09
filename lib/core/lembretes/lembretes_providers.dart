import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/acesso_providers.dart';
import '../operations/operations_controller.dart';
import 'agendador.dart';
import 'agendador_local.dart';
import 'reconciliar.dart';

final agendadorProvider = Provider<AgendadorDeLembretes>(
  (_) => agendadorDaPlataforma(),
);

/// Conta com sessão neste aparelho, ou `null`. Muda com cada evento de sessão,
/// que é o que faz o alarme desaparecer quando se sai ou se troca de conta.
final uidAtualProvider = Provider<String?>((ref) {
  try {
    ref.watch(eventosDeSessaoProvider);
    return ref.watch(acessoServiceProvider).utilizadorId;
  } catch (_) {
    return null;
  }
});

/// Mantém os alarmes do aparelho iguais às reuniões de quem tem sessão.
///
/// Reconcilia por inteiro, e não por diferenças: depois de qualquer mudança
/// (marcar, remarcar, cancelar, sincronizar, entrar, sair, voltar à app) o que
/// está agendado passa a ser exactamente `reconciliar(...)`. Um alarme órfão
/// seria uma reunião que já não existe a tocar.
class ObservadorDeLembretes extends ConsumerStatefulWidget {
  const ObservadorDeLembretes({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ObservadorDeLembretes> createState() => _ObservadorState();
}

class _ObservadorState extends ConsumerState<ObservadorDeLembretes>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconciliar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A janela de 30 dias anda com o tempo.
    if (state == AppLifecycleState.resumed) _reconciliar();
  }

  Future<void> _reconciliar() async {
    if (!mounted) return;
    try {
      final uid = ref.read(uidAtualProvider);
      final agendador = ref.read(agendadorProvider);
      if (uid == null) {
        await agendador.cancelarTudo();
        return;
      }
      final reunioes = ref.read(operationsProvider).reunioes;
      final agora = ref.read(relogioProvider)();
      await agendador.aplicar(reconciliar(reunioes, uid, agora));
    } catch (_) {
      // Um alarme que falha a agendar não pode derrubar a app.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(operationsProvider.select((s) => s.reunioes), (_, __) {
      _reconciliar();
    });
    ref.listen(uidAtualProvider, (_, __) => _reconciliar());
    return widget.child;
  }
}
