import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/kpis/break_even.dart';
import '../../../core/operations/operations_controller.dart';

/// **Um ano em colunas** — a faturação de cada mês, com o break even como a
/// única linha, a tracejado. Setas (ou arrastar para o lado) levam aos anos
/// transatos.
///
/// A coluna do mês a decorrer é o acumulado até hoje e vem esbatida; a de um
/// mês só com histórico do contabilista vem só com contorno. Tudo em euros, na
/// mesma escala.
class GraficoDoMes extends StatefulWidget {
  const GraficoDoMes({
    super.key,
    required this.estado,
    required this.now,
    this.altura = 190,
    this.compacto = false,
  });

  final OperationsState estado;
  final DateTime now;

  /// `null` enche a altura que lhe derem (o cartão do painel).
  final double? altura;

  /// Letra pequena e legenda numa linha só: o cartão do painel, que tem o
  /// tamanho dos outros e não o muda para o gráfico caber.
  final bool compacto;

  @override
  State<GraficoDoMes> createState() => _GraficoDoMesState();
}

class _GraficoDoMesState extends State<GraficoDoMes> {
  late int _ano = widget.now.year;

  void _ir(SerieAnual s, int passo) {
    final i = s.anos.indexOf(_ano) + passo;
    if (i < 0 || i >= s.anos.length) return;
    setState(() => _ano = s.anos[i]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final serie = serieAnual(widget.estado, widget.now, _ano);
    final i = serie.anos.indexOf(_ano);
    final cores = _Cores(
      coluna: corDoAno(_ano, Theme.of(context).brightness),
      mes: const Color(0xFF1E6FD9),
      media: cs.outline,
      eixo: cs.outlineVariant,
      texto: cs.onSurfaceVariant,
    );
    final compacto = widget.compacto;
    final pequeno = tt.labelSmall?.copyWith(fontSize: 10);
    final titulo = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Faturação mensal · '),
          TextSpan(
            text: '$_ano',
            style: TextStyle(color: cores.coluna, fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: '  (k = mil €)',
            style: TextStyle(color: cores.texto, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      style: compacto ? pequeno : tt.labelLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final grafico = !serie.temDados
        ? Text('Sem faturação registada em $_ano.', style: tt.bodySmall)
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 200) _ir(serie, -1);
              if (v < -200) _ir(serie, 1);
            },
            child: SizedBox(
              height: widget.altura,
              width: double.infinity,
              child: CustomPaint(painter: _ColunasPainter(serie, cores)),
            ),
          );
    final legenda = _legenda(serie, cores);
    return Column(
      mainAxisSize: compacto ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SetaDeAno(
              tooltip: 'Ano anterior',
              icone: Icons.chevron_left,
              compacta: compacto,
              onPressed: i > 0 ? () => _ir(serie, -1) : null,
            ),
            Flexible(child: titulo),
            _SetaDeAno(
              tooltip: 'Ano seguinte',
              icone: Icons.chevron_right,
              compacta: compacto,
              onPressed: i < serie.anos.length - 1 ? () => _ir(serie, 1) : null,
            ),
          ],
        ),
        if (widget.altura == null) Expanded(child: grafico) else grafico,
        SizedBox(height: compacto ? 2 : 6),
        if (compacto)
          FittedBox(fit: BoxFit.scaleDown, child: legenda)
        else
          legenda,
      ],
    );
  }

  Widget _legenda(SerieAnual serie, _Cores cores) {
    final itens = <Widget>[
      _Legenda('Faturação do mês', cores.coluna),
      if (serie.mesAtual != null)
        _Legenda('Mês a decorrer (até hoje)', cores.coluna, esbatida: true),
      if (serie.declarado.any((d) => d))
        _Legenda('Declarado pelo contabilista', cores.coluna, contorno: true),
      if (serie.breakEven.any((b) => b != null))
        _Legenda('Break even do mês', cores.mes, fina: true),
      if (serie.mediaDoAno != null)
        _Legenda(
          'Média do ano · ${_euros(serie.mediaDoAno!)}',
          cores.media,
          tracejada: true,
        ),
    ];
    if (widget.compacto) {
      // Numa linha só; a que não cabe encolhe em vez de partir o cartão.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in itens) ...[item, const SizedBox(width: 8)],
        ],
      );
    }
    return Wrap(spacing: 14, runSpacing: 4, children: itens);
  }
}

/// A cor de cada ano, a mesma no gráfico dos anos e no gráfico mensal desse
/// ano. Fixa por ano (2024 violeta, 2025 verde-azulado, 2026 verde) e a rodar
/// por três nos seguintes. O azul fica para o break even e o cinzento para a
/// média, para nenhuma coluna se confundir com uma linha.
Color corDoAno(int ano, Brightness brilho) {
  const claras = [Color(0xFF8A5CC4), Color(0xFF1D9A8C), Color(0xFF639922)];
  const escuras = [Color(0xFFB794EA), Color(0xFF4FCBBD), Color(0xFF86B840)];
  final i = ((ano - 2024) % 3 + 3) % 3;
  return (brilho == Brightness.dark ? escuras : claras)[i];
}

class _SetaDeAno extends StatelessWidget {
  const _SetaDeAno({
    required this.tooltip,
    required this.icone,
    required this.compacta,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icone;
  final bool compacta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: compacta
        ? const BoxConstraints.tightFor(width: 26, height: 22)
        : null,
    iconSize: compacta ? 18 : 24,
    onPressed: onPressed,
    icon: Icon(icone),
  );
}

/// O gráfico que compara os anos já contabilizados: a faturação de cada um em
/// coluna (com a cor do ano), a despesa do ano como traço fino azul, e o lucro
/// por baixo. O ano a decorrer vem esbatido, porque soma só até hoje.
class GraficoDosAnos extends StatelessWidget {
  const GraficoDosAnos({super.key, required this.estado, required this.now});

  final OperationsState estado;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final brilho = Theme.of(context).brightness;
    final anos = totaisPorAno(estado, now);
    final pequeno = tt.labelSmall?.copyWith(fontSize: 10);
    if (anos.isEmpty || anos.every((a) => a.faturacaoCents <= 0)) {
      return Text('Ainda sem anos para comparar.', style: tt.bodySmall);
    }
    const azul = Color(0xFF1E6FD9);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Total por ano'),
              TextSpan(
                text: '  (k = mil €)',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          style: pequeno,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _AnosPainter(
              anos,
              [for (final a in anos) corDoAno(a.ano, brilho)],
              azul,
              cs.outlineVariant,
              cs.onSurfaceVariant,
              now,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in anos) ...[
                _Legenda('${a.ano}', corDoAno(a.ano, brilho)),
                const SizedBox(width: 8),
              ],
              const _Legenda('Despesa do ano', azul, fina: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnosPainter extends CustomPainter {
  _AnosPainter(
    this.anos,
    this.cores,
    this.azul,
    this.eixo,
    this.texto,
    this.now,
  );
  final List<AnoTotal> anos;
  final List<Color> cores;
  final Color azul, eixo, texto;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    const esquerda = 44.0, fundo = 26.0, topo = 14.0, direita = 6.0;
    final area = Rect.fromLTRB(
      esquerda,
      topo,
      size.width - direita,
      size.height - fundo,
    );
    if (area.width <= 0 || area.height <= 0) return;
    var maximo = 0;
    for (final a in anos) {
      maximo = math.max(maximo, math.max(a.faturacaoCents, a.despesaCents));
    }
    if (maximo <= 0) return;
    final topoEscala = _escalaBonita(maximo);
    double y(int c) => area.bottom - area.height * c / topoEscala;

    final grelha = Paint()
      ..color = eixo
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 3; i++) {
      final yy = area.bottom - area.height * i / 3;
      canvas.drawLine(Offset(area.left, yy), Offset(area.right, yy), grelha);
      _texto(
        canvas,
        _euros(topoEscala * i ~/ 3),
        Offset(area.left - 4, yy),
        texto,
        alinhaDireita: true,
      );
    }
    final passo = area.width / anos.length;
    final larg = math.min(passo * 0.5, 64.0);
    for (var n = 0; n < anos.length; n++) {
      final a = anos[n];
      final cx = area.left + passo * (n + 0.5);
      final r = Rect.fromLTRB(
        cx - larg / 2,
        y(a.faturacaoCents),
        cx + larg / 2,
        area.bottom,
      );
      canvas.drawRect(
        r,
        Paint()..color = cores[n].withValues(alpha: a.parcial ? 0.45 : 1),
      );
      _texto(
        canvas,
        _compacto(a.faturacaoCents),
        Offset(cx, r.top - 6),
        texto,
        centrado: true,
      );
      _linha(
        canvas,
        [
          Offset(cx - larg / 2, y(a.despesaCents)),
          Offset(cx + larg / 2, y(a.despesaCents)),
        ],
        azul,
        1.3,
        false,
      );
      _texto(
        canvas,
        a.parcial
            ? '${a.ano} (até ${now.day} ${_meses[now.month - 1]})'
            : '${a.ano}',
        Offset(cx, area.bottom + 8),
        texto,
        centrado: true,
      );
      _texto(
        canvas,
        'lucro ${a.lucroCents >= 0 ? '+' : '-'}${_compacto(a.lucroCents.abs())}',
        Offset(cx, area.bottom + 19),
        texto,
        centrado: true,
      );
    }
  }

  @override
  bool shouldRepaint(_AnosPainter o) =>
      o.anos != anos || o.cores != cores || o.azul != azul;
}

const _meses = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

class _Cores {
  const _Cores({
    required this.coluna,
    required this.mes,
    required this.media,
    required this.eixo,
    required this.texto,
  });
  final Color coluna, mes, media, eixo, texto;
}

class _Legenda extends StatelessWidget {
  const _Legenda(
    this.texto,
    this.cor, {
    this.tracejada = false,
    this.esbatida = false,
    this.contorno = false,
    this.fina = false,
  });
  final String texto;
  final Color cor;
  final bool tracejada, esbatida, contorno, fina;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 22,
        height: 10,
        child: tracejada || fina
            ? CustomPaint(painter: _TracoPainter(cor, tracejada))
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: contorno
                      ? null
                      : cor.withValues(alpha: esbatida ? 0.45 : 1),
                  border: contorno ? Border.all(color: cor, width: 1.4) : null,
                ),
              ),
      ),
      const SizedBox(width: 5),
      Text(texto, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _TracoPainter extends CustomPainter {
  _TracoPainter(this.cor, this.tracejada);
  final Color cor;
  final bool tracejada;

  @override
  void paint(Canvas canvas, Size size) => _linha(
    canvas,
    [Offset(0, size.height / 2), Offset(size.width, size.height / 2)],
    cor,
    tracejada ? 1.2 : 1.3,
    tracejada,
  );

  @override
  bool shouldRepaint(_TracoPainter o) =>
      o.cor != cor || o.tracejada != tracejada;
}

void _linha(
  Canvas canvas,
  List<Offset> pontos,
  Color cor,
  double largura,
  bool tracejada,
) {
  final paint = Paint()
    ..color = cor
    ..strokeWidth = largura
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (!tracejada) {
    canvas.drawPath(Path()..addPolygon(pontos, false), paint);
    return;
  }
  const traco = 5.0, folga = 4.0;
  for (var i = 0; i < pontos.length - 1; i++) {
    final a = pontos[i], b = pontos[i + 1];
    final comp = (b - a).distance;
    if (comp == 0) continue;
    final dir = (b - a) / comp;
    for (var d = 0.0; d < comp; d += traco + folga) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + traco, comp), paint);
    }
  }
}

class _ColunasPainter extends CustomPainter {
  _ColunasPainter(this.s, this.c);
  final SerieAnual s;
  final _Cores c;

  static const _mesesCurtos = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const esquerda = 44.0, fundo = 16.0, topo = 14.0, direita = 6.0;
    final area = Rect.fromLTRB(
      esquerda,
      topo,
      size.width - direita,
      size.height - fundo,
    );
    if (area.width <= 0 || area.height <= 0) return;

    final maximo = s.maximoDeTodosOsAnos;
    if (maximo <= 0) return;
    // Folga de 30% acima do valor mais alto de qualquer ano (13,7k
    // pede 18k): as colunas não encostam ao tecto e o tecto nunca passa do
    // dobro. Sobe sozinho quando um mês bater o máximo.
    final topoEscala = _escalaBonita((maximo * 1.3).round(), folga: 1.0);
    double y(int cents) => area.bottom - area.height * cents / topoEscala;

    final grelha = Paint()
      ..color = c.eixo
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 3; i++) {
      final valor = topoEscala * i ~/ 3;
      final yy = area.bottom - area.height * i / 3;
      canvas.drawLine(Offset(area.left, yy), Offset(area.right, yy), grelha);
      _texto(
        canvas,
        _euros(valor),
        Offset(area.left - 4, yy),
        c.texto,
        alinhaDireita: true,
      );
    }

    final passo = area.width / 12;
    final larg = passo * 0.62;
    for (var m = 0; m < 12; m++) {
      final cx = area.left + passo * (m + 0.5);
      _texto(
        canvas,
        _mesesCurtos[m],
        Offset(cx, area.bottom + 8),
        c.texto,
        centrado: true,
      );
      final v = s.meses[m];
      if (v == null || v <= 0) continue;
      final r = Rect.fromLTRB(cx - larg / 2, y(v), cx + larg / 2, area.bottom);
      if (s.declarado[m]) {
        canvas.drawRect(
          r.deflate(0.7),
          Paint()
            ..color = c.coluna
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      } else {
        canvas.drawRect(
          r,
          Paint()
            ..color = c.coluna.withValues(
              alpha: s.mesAtual == m + 1 ? 0.45 : 1,
            ),
        );
      }
      _texto(
        canvas,
        _compacto(v),
        Offset(cx, r.top - 6),
        c.texto,
        centrado: true,
      );
    }

    if (s.mediaDoAno != null) {
      final yy = y(s.mediaDoAno!);
      _linha(
        canvas,
        [Offset(area.left, yy), Offset(area.right, yy)],
        c.media,
        1.2,
        true,
      );
    }
    // O break even de cada mês: um traço por cima da sua coluna.
    for (var m = 0; m < 12; m++) {
      final b = s.breakEven[m];
      if (b == null) continue;
      final cx = area.left + passo * (m + 0.5);
      final yy = y(b);
      _linha(
        canvas,
        [Offset(cx - larg / 2, yy), Offset(cx + larg / 2, yy)],
        c.mes,
        1.3,
        false,
      );
    }
  }

  @override
  bool shouldRepaint(_ColunasPainter o) => o.s != s || o.c != c;
}

void _texto(
  Canvas canvas,
  String texto,
  Offset pos,
  Color cor, {
  bool alinhaDireita = false,
  bool centrado = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: texto,
      style: TextStyle(fontSize: 10, color: cor),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = alinhaDireita
      ? pos.dx - tp.width
      : centrado
      ? pos.dx - tp.width / 2
      : pos.dx;
  tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
}

/// Arredonda o máximo para cima a um valor «redondo» divisível por 3, para os
/// três degraus do eixo caírem em números limpos — o mais baixo que o cabe, sem
/// deixar a coluna mais alta a meio do ecrã (8,7k pede 12k, não 15k). Nunca
/// passa do dobro do valor mais alto.
int _escalaBonita(int maximo, {double folga = 1.05}) {
  final base = math.pow(10, (math.log(maximo) / math.ln10).floor() - 1).toInt();
  for (var d = 0; d < 3; d++) {
    for (final m in [4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80]) {
      final degrau = m * base * math.pow(10, d).toInt();
      if (degrau * 3 >= maximo * folga) return degrau * 3;
    }
  }
  return base * 300;
}

/// O valor de uma coluna, curto para caber por cima dela (7,9k, 640).
String _compacto(int cents) {
  final e = cents / 100;
  if (e >= 10000) return '${(e / 1000).toStringAsFixed(0)}k';
  if (e >= 1000) {
    return '${(e / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
  }
  return '${e.round()}';
}

String _euros(int cents) {
  final e = cents / 100;
  if (e >= 10000) return '${(e / 1000).toStringAsFixed(0)} mil €';
  if (e >= 1000) {
    return '${(e / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil €';
  }
  return '${e.round()} €';
}
