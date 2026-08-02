import 'package:flutter/material.dart';

import '../../core/orientacao/orientacao_do_contexto.dart';

/// Splash de arranque com o símbolo Punho.
///
/// Animação em 3 fases (~1.6s total):
///   0-30%   fundo azul + símbolo com fade-in
///   0-70%   símbolo cresce de 0.4 para 1.0 (elasticOut — bounce natural)
///   70-100% micro-pulse final (1.0 → 1.06 → 1.0)
///
/// Ao terminar chama [aoTerminar] — normalmente para revelar AuthGate/AppShell.
class SplashPunho extends StatefulWidget {
  const SplashPunho({super.key, required this.aoTerminar});
  final VoidCallback aoTerminar;

  @override
  State<SplashPunho> createState() => _SplashPunhoState();
}

class _SplashPunhoState extends State<SplashPunho>
    with SingleTickerProviderStateMixin {
  static const _duracao = Duration(milliseconds: 1600);
  // Cor do fundo do próprio símbolo — evita "flash" azul-claro por trás.
  static const _fundo = Color(0xFF1E2A44);

  late final AnimationController _c;
  late final Animation<double> _opacidade;
  late final Animation<double> _escala;
  late final Animation<double> _pulse;
  bool _jaTerminou = false;

  @override
  void initState() {
    super.initState();
    // O splash também é um ecrã e também declara o que precisa (Decisão 13).
    // Sem isto arrancava com a orientação do sensor: quem abrisse a app com o
    // telemóvel deitado via o símbolo em landscape durante os 1,6 s da animação
    // e depois um giro seco para retrato quando o AuthGate montava e pedia
    // portrait. O que se segue ao splash é sempre um formulário — retrato.
    OrientacaoDoContexto.portraitJa();
    _c = AnimationController(vsync: this, duration: _duracao)..forward();

    _opacidade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
    );
    _escala = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.70, curve: Curves.elasticOut),
      ),
    );
    _pulse =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _c,
            curve: const Interval(0.70, 1.0, curve: Curves.easeInOut),
          ),
        );

    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_jaTerminou) {
        _jaTerminou = true;
        widget.aoTerminar();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _fundo,
    body: Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Opacity(
          opacity: _opacidade.value,
          child: Transform.scale(
            scale: _escala.value * (_c.value > 0.70 ? _pulse.value : 1.0),
            child: SizedBox(
              width: 180,
              height: 180,
              child: Image.asset(
                'assets/brand/punho_elo_operacao_v010.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
