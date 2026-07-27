import 'package:flutter/material.dart';

import '../../../../core/theme/punho_theme.dart';

const _verde = Color(0xFF639922);
const _borda = Color(0xFFE5E3DA);

/// Barras diárias, sem eixos nem legendas.
///
/// Barras e não linha: os recebimentos são eventos em dias soltos, e uma linha
/// entre dois dias sugere um caudal contínuo que não existe. Dias a zero ficam
/// com um traço mínimo para se ver que o dia passou.
class SparklineDiaria extends StatelessWidget {
  const SparklineDiaria({
    super.key,
    required this.valores,
    this.cor = _verde,
    this.destacarIndice,
  });

  final List<int> valores;
  final Color cor;

  /// Dia a marcar (tipicamente hoje).
  final int? destacarIndice;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SparklinePainter(
      valores: valores,
      cor: cor,
      destacar: destacarIndice,
    ),
    child: const SizedBox.expand(),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.valores, required this.cor, this.destacar});
  final List<int> valores;
  final Color cor;
  final int? destacar;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty || size.height <= 0) return;
    final maximo = valores.fold(0, (a, b) => a > b ? a : b);
    final largura = size.width / valores.length;
    final barra = (largura * 0.62).clamp(1.0, 10.0);
    for (var i = 0; i < valores.length; i++) {
      final proporcao = maximo == 0 ? 0.0 : valores[i] / maximo;
      final altura = (size.height * proporcao).clamp(1.5, size.height);
      final x = largura * i + (largura - barra) / 2;
      final destacado = destacar == i;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - altura, barra, altura),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = valores[i] == 0
              ? _borda
              : (destacado ? PunhoTheme.orange : cor),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.valores != valores || old.cor != cor || old.destacar != destacar;
}

/// Anel de percentagem com o número no centro. `null` mostra o anel vazio e um
/// travessão — não 0%.
class AnelPercentagem extends StatelessWidget {
  const AnelPercentagem({
    super.key,
    required this.percent,
    this.tamanho = 108,
    this.cor = _verde,
  });

  final double? percent;
  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamanho,
    height: tamanho,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(tamanho),
          painter: _AnelPainter(percent: percent, cor: cor),
        ),
        Text(
          percent == null ? '—' : '${percent!.round()}%',
          style: TextStyle(
            fontSize: tamanho * 0.21,
            fontWeight: FontWeight.w800,
            color: PunhoTheme.navy,
          ),
        ),
      ],
    ),
  );
}

class _AnelPainter extends CustomPainter {
  _AnelPainter({required this.percent, required this.cor});
  final double? percent;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raio = size.width / 2 - 6;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = _borda;
    canvas.drawCircle(centro, raio, base);
    if (percent == null || percent! <= 0) return;
    final fraccao = (percent! / 100).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raio),
      -1.5708, // topo
      6.2832 * fraccao,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = cor,
    );
  }

  @override
  bool shouldRepaint(_AnelPainter old) =>
      old.percent != percent || old.cor != cor;
}

/// Barra horizontal com rótulo e valor à direita. Serve o top de máquinas e o
/// peso dos custos na receita.
class BarraHorizontal extends StatelessWidget {
  const BarraHorizontal({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.fraccao,
    this.cor = _verde,
  });

  final String rotulo;
  final String valor;

  /// 0..1 do comprimento total.
  final double fraccao;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Text(
              valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraccao.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFEFF1F3),
            valueColor: AlwaysStoppedAnimation(cor),
          ),
        ),
      ],
    ),
  );
}

/// Mini-calendário de N dias com marcador nos dias que têm reservas.
class MiniCalendario extends StatelessWidget {
  const MiniCalendario({super.key, required this.porDia, required this.inicio});

  final List<int> porDia;
  final DateTime inicio;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < porDia.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${inicio.add(Duration(days: i)).day}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6B6A64)),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: porDia[i] == 0
                        ? const Color(0xFFEFF1F3)
                        : _verde.withValues(
                            alpha: (0.35 + 0.2 * porDia[i]).clamp(0.35, 1.0),
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: porDia[i] == 0
                      ? null
                      : Text(
                          '${porDia[i]}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
