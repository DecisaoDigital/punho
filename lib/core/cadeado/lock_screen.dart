import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/brand_lockup.dart';
import '../config/supabase_config.dart';
import 'cadeado_service.dart';

/// Ecrã de bloqueio. Aparece sobreposto ao resto da app quando o
/// [cadeadoBloqueadoProvider] está `true`.
///
/// Fluxo:
///   1. Se biometria activada e disponível → dispara automaticamente
///   2. Se biometria falha ou não disponível → oferece PIN
///   3. Após 5 tentativas falhadas → botão "Terminar sessão"
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  final _foco = FocusNode();
  bool _mostrarPin = false;
  bool _aTentarBio = false;
  int _falhas = 0;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tentarBiometria());
  }

  @override
  void dispose() {
    _pin.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _tentarBiometria() async {
    final svc = ref.read(cadeadoServiceProvider);
    if (!await svc.biometriaActivada()) {
      setState(() => _mostrarPin = true);
      return;
    }
    if (!await svc.biometriaDisponivelNoDispositivo()) {
      setState(() => _mostrarPin = true);
      return;
    }
    setState(() => _aTentarBio = true);
    final ok = await svc.pedirBiometria();
    if (!mounted) return;
    setState(() => _aTentarBio = false);
    if (ok) {
      ref.read(cadeadoBloqueadoProvider.notifier).state = false;
    } else {
      setState(() => _mostrarPin = true);
    }
  }

  Future<void> _validarPin() async {
    final svc = ref.read(cadeadoServiceProvider);
    final ok = await svc.validarPin(_pin.text);
    if (!mounted) return;
    if (ok) {
      ref.read(cadeadoBloqueadoProvider.notifier).state = false;
    } else {
      setState(() {
        _falhas++;
        _erro = 'PIN errado.';
        _pin.clear();
      });
    }
  }

  Future<void> _terminarSessao() async {
    if (SupabaseConfig.enabled) {
      await Supabase.instance.client.auth.signOut();
    }
    // O AuthGate a seguir devolve ao Login. Desbloqueia o gate para o
    // fluxo continuar.
    ref.read(cadeadoBloqueadoProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A44),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLockup(),
                  const SizedBox(height: 40),
                  if (_aTentarBio)
                    const _BiometriaPendente()
                  else if (!_mostrarPin)
                    FilledButton.icon(
                      onPressed: _tentarBiometria,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    )
                  else ...[
                    Text(
                      'Introduz o PIN',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pin,
                      focusNode: _foco,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        letterSpacing: 8,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _validarPin(),
                    ),
                    if (_erro != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _erro!,
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _validarPin,
                      child: const Text('Desbloquear'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _tentarBiometria,
                      icon: const Icon(Icons.fingerprint, color: Colors.white),
                      label: const Text(
                        'Usar biometria',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_falhas >= 5) ...[
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: _terminarSessao,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        child: const Text(
                          'Esqueci o PIN — terminar sessão',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometriaPendente extends StatelessWidget {
  const _BiometriaPendente();
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.fingerprint, color: Colors.white70, size: 56),
      SizedBox(height: 16),
      Text(
        'A aguardar biometria…',
        style: TextStyle(color: Colors.white70),
      ),
    ],
  );
}
