import 'package:flutter/material.dart';

/// **O ecrã do painel com os dois gráficos:** até três KPIs em cima, todos do
/// mesmo tamanho, e em baixo os gráficos lado a lado, também iguais entre si.
///
/// Os cartões de número são mais baixos do que os de gráfico (5 para 5, depois de
/// altura), e nenhum muda de tamanho para o outro caber. Como [GrelhaDeKpis],
/// mede o espaço que lhe dão em vez de lhe impor uma proporção: o painel tem de
/// se ver inteiro, sem scroll.
class GrelhaComGraficos extends StatelessWidget {
  const GrelhaComGraficos({
    super.key,
    required this.celulas,
    required this.graficos,
  }) : assert(celulas.length <= 3);

  final List<Widget> celulas;
  final List<Widget> graficos;

  static const _entre = 10.0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(flex: 4, child: _linha(celulas)),
      const SizedBox(height: _entre),
      Expanded(flex: 6, child: _linha(graficos)),
    ],
  );

  Widget _linha(List<Widget> filhos) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < filhos.length; i++) ...[
        if (i > 0) const SizedBox(width: _entre),
        Expanded(child: filhos[i]),
      ],
    ],
  );
}

/// A moldura dos gráficos do painel: a mesma dos cartões de KPI (fundo, bordo,
/// canto), com menos ar por dentro, porque o gráfico precisa dele.
class CartaoDeGrafico extends StatelessWidget {
  const CartaoDeGrafico({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E3DA)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: child,
    ),
  );
}
