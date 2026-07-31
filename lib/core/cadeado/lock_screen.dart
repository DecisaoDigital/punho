import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/brand_lockup.dart';
import '../config/supabase_config.dart';
import 'cadeado_service.dart';

/// Ecrã de bloqueio. Aparece sobreposto ao resto da app quando o
/// [cadeadoBloqueadoProvider] está `true`.
///
/// Fluxo:
///   1. Se a biometria estiver activada e disponível → dispara automaticamente
///   2. O PIN está **sempre** a um toque de distância, mesmo enquanto a
///      biometria está a ser pedida. Antes ficava escondido atrás dela, e quando
///      a biometria encravava não havia forma de entrar na app.
///   3. Após 5 tentativas falhadas → botão "Terminar sessão"
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

/// Os mesmos limites do `_DefinirPinScreen`: 4 a 6 dígitos.
const _minimoDigitos = 4;
const _maximoDigitos = 6;

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _navy = Color(0xFF1E2A44);

  String _pin = '';
  bool _mostrarPin = false;
  bool _aTentarBio = false;
  bool _bioPossivel = false;
  int _falhas = 0;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tentarBiometria());
  }

  Future<void> _tentarBiometria() async {
    final svc = ref.read(cadeadoServiceProvider);
    final activada = await svc.biometriaActivada();
    final disponivel = activada && await svc.biometriaDisponivelNoDispositivo();
    if (!mounted) return;
    setState(() => _bioPossivel = disponivel);
    if (!disponivel) {
      setState(() => _mostrarPin = true);
      return;
    }

    setState(() {
      _aTentarBio = true;
      _erro = null;
    });
    final resultado = await svc.pedirBiometria();
    if (!mounted) return;
    setState(() => _aTentarBio = false);

    if (resultado.autenticado) {
      ref.read(cadeadoBloqueadoProvider.notifier).state = false;
      return;
    }
    // Desistiu ou falhou: em qualquer dos casos cai no PIN, e se houver razão
    // para mostrar, mostra-se. Nunca ficar parado sem explicação.
    setState(() {
      _mostrarPin = true;
      _erro = resultado.erro;
    });
  }

  Future<void> _validarPin() async {
    final svc = ref.read(cadeadoServiceProvider);
    final ok = await svc.validarPin(_pin);
    if (!mounted) return;
    if (ok) {
      ref.read(cadeadoBloqueadoProvider.notifier).state = false;
      return;
    }
    setState(() {
      _falhas++;
      _erro = 'PIN errado.';
      _pin = '';
    });
  }

  void _digito(String d) {
    if (_pin.length >= _maximoDigitos) return;
    setState(() {
      _pin += d;
      _erro = null;
    });
  }

  void _apagarDigito() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _navy,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLockup(),
                  const SizedBox(height: 28),
                  if (_aTentarBio) ...[
                    const _BiometriaPendente(),
                    const SizedBox(height: 20),
                    // A saída de emergência. Enquanto isto não existiu, uma
                    // biometria encravada deixava a app inacessível.
                    TextButton(
                      onPressed: () => setState(() => _mostrarPin = true),
                      child: const Text(
                        'Usar PIN',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ] else if (!_mostrarPin)
                    FilledButton.icon(
                      onPressed: _tentarBiometria,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                  if (_mostrarPin) ...[
                    const Text(
                      'Introduz o PIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Pontos(preenchidos: _pin.length, erro: _erro != null),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 20,
                      child: _erro == null
                          ? null
                          : Text(
                              _erro!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontSize: 12.5,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    _Teclado(
                      onDigito: _digito,
                      onApagar: _apagarDigito,
                      onConfirmar: _pin.length >= _minimoDigitos
                          ? _validarPin
                          : null,
                      biometriaVisivel: _bioPossivel,
                      onBiometria: _tentarBiometria,
                    ),
                  ],
                  if (_falhas >= 5) ...[
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _terminarSessao,
                      child: const Text(
                        'Esqueci o PIN — terminar sessão',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Os pontos do PIN. Seis posições fixas seria mentir sobre o comprimento —
/// mostra-se um ponto cheio por dígito introduzido e um vazio para o próximo.
class _Pontos extends StatelessWidget {
  const _Pontos({required this.preenchidos, required this.erro});
  final int preenchidos;
  final bool erro;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(_maximoDigitos, (i) {
      final cheio = i < preenchidos;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 7),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cheio
              ? (erro ? const Color(0xFFFF8A80) : Colors.white)
              : Colors.transparent,
          border: Border.all(
            color: erro ? const Color(0xFFFF8A80) : Colors.white38,
            width: 1.4,
          ),
        ),
      );
    }),
  );
}

/// Teclado numérico próprio em vez do teclado do sistema.
///
/// O campo de texto com `letterSpacing: 8` que aqui estava parecia um
/// formulário a meio de fazer, e obrigava o teclado do Android a tapar metade do
/// ecrã. Um cadeado é a primeira coisa que se vê ao abrir a app — tem de estar
/// apresentável.
class _Teclado extends StatelessWidget {
  const _Teclado({
    required this.onDigito,
    required this.onApagar,
    required this.onConfirmar,
    required this.biometriaVisivel,
    required this.onBiometria,
  });

  final void Function(String) onDigito;
  final VoidCallback onApagar;
  final VoidCallback? onConfirmar;
  final bool biometriaVisivel;
  final VoidCallback onBiometria;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final linha in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (final d in linha) _Tecla(rotulo: d, onTap: onDigito)],
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TeclaIcone(
            icone: biometriaVisivel ? Icons.fingerprint : null,
            onTap: biometriaVisivel ? onBiometria : null,
            tooltip: 'Usar biometria',
          ),
          _Tecla(rotulo: '0', onTap: onDigito),
          _TeclaIcone(
            icone: Icons.backspace_outlined,
            onTap: onApagar,
            tooltip: 'Apagar',
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onConfirmar,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Desbloquear'),
        ),
      ),
    ],
  );
}

class _Tecla extends StatelessWidget {
  const _Tecla({required this.rotulo, required this.onTap});
  final String rotulo;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => _MolduraDeTecla(
    onTap: () => onTap(rotulo),
    child: Text(
      rotulo,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _TeclaIcone extends StatelessWidget {
  const _TeclaIcone({
    required this.icone,
    required this.onTap,
    required this.tooltip,
  });
  final IconData? icone;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (icone == null) return const SizedBox(width: 76, height: 60);
    return Tooltip(
      message: tooltip,
      child: _MolduraDeTecla(
        onTap: onTap,
        child: Icon(icone, color: Colors.white70, size: 24),
      ),
    );
  }
}

/// O alvo de toque de todas as teclas, num sítio só: 76x60 com o mesmo
/// `bounding box` do realce, que é a regra de hit target da app.
class _MolduraDeTecla extends StatelessWidget {
  const _MolduraDeTecla({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 76, height: 54, child: Center(child: child)),
      ),
    ),
  );
}

class _BiometriaPendente extends StatelessWidget {
  const _BiometriaPendente();
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.fingerprint, color: Colors.white70, size: 56),
      SizedBox(height: 16),
      Text('A aguardar biometria…', style: TextStyle(color: Colors.white70)),
    ],
  );
}
