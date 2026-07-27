import 'package:flutter/material.dart';

import '../../../../core/theme/punho_theme.dart';

/// Grelha 2×2 que enche a área que lhe dão.
///
/// A célula 1-1 é maior (`flexHero`) porque recebe o KPI-herói: número grande e
/// gráfico. As outras três dividem o resto por igual. Sem `Expanded` a grelha
/// deixava ar morto no fundo do ecrã em landscape, que é o formato em que esta
/// app se usa.
class KpiGrid2x2 extends StatelessWidget {
  const KpiGrid2x2({
    super.key,
    required this.heroi,
    required this.cimaDireita,
    required this.baixoEsquerda,
    required this.baixoDireita,
    this.flexHero = 3,
    this.flexRestantes = 2,
  });

  final Widget heroi, cimaDireita, baixoEsquerda, baixoDireita;
  final int flexHero, flexRestantes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Em ecrãs baixos (telemóvel em landscape) a coluna da esquerda com o
      // herói esticado a duas linhas fica ilegível: passa-se a 1×4 em coluna
      // com scroll, que é honesto, em vez de comprimir tudo até não se ler.
      if (constraints.maxHeight < 320) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: 200, child: heroi),
            const SizedBox(height: 12),
            SizedBox(height: 150, child: cimaDireita),
            const SizedBox(height: 12),
            SizedBox(height: 150, child: baixoEsquerda),
            const SizedBox(height: 12),
            SizedBox(height: 150, child: baixoDireita),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coluna da esquerda: o herói ocupa as duas linhas.
          Expanded(
            flex: flexHero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: flexHero, child: heroi),
                const SizedBox(height: 12),
                Expanded(flex: flexRestantes, child: baixoEsquerda),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: flexRestantes,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cimaDireita),
                const SizedBox(height: 12),
                Expanded(child: baixoDireita),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Card base dos KPIs. Todos os slides usam este — a diferença entre eles é a
/// cor de fundo e o bordo, não a estrutura.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.titulo,
    required this.child,
    this.fundo,
    this.corDoBordo,
    this.hint,
    this.acaoNoTitulo,
    this.rodape,
  });

  final String titulo;
  final Widget child;
  final Color? fundo;

  /// Quando presente, desenha um bordo esquerdo de 4 dp — o sinal de "olha para
  /// este".
  final Color? corDoBordo;

  /// Texto pequeno à direita do título ("este mês", "últimos 30 dias").
  final String? hint;

  /// Controlos no cabeçalho (por exemplo as setas de mês do slide 1).
  final Widget? acaoNoTitulo;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final corpo = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (acaoNoTitulo != null) acaoNoTitulo!,
              if (hint != null)
                Text(hint!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
          if (rodape != null) ...[const SizedBox(height: 8), rodape!],
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: corDoBordo == null
            ? Border.all(color: const Color(0xFFE5E3DA))
            : Border(left: BorderSide(color: corDoBordo!, width: 4)),
      ),
      child: corpo,
    );
  }
}

/// Número grande de um KPI. Cresce até 40 sp quando há espaço — pedido
/// explícito: se sobra ar na célula, o número aumenta em vez de ficar padding.
class KpiValor extends StatelessWidget {
  const KpiValor(this.texto, {super.key, this.cor, this.tamanho = 32});
  final String texto;
  final Color? cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      texto,
      maxLines: 1,
      style: TextStyle(
        fontSize: tamanho,
        height: 1.1,
        fontWeight: FontWeight.w800,
        color: cor ?? PunhoTheme.navy,
      ),
    ),
  );
}

/// Valor que não se sabe. Nunca se escreve "0 €" no lugar disto.
class KpiPorApurar extends StatelessWidget {
  const KpiPorApurar({super.key, this.explicacao});
  final String? explicacao;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const KpiValor('Por apurar', cor: Color(0xFF6B6A64), tamanho: 24),
      if (explicacao != null) ...[
        const SizedBox(height: 6),
        Text(explicacao!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

/// Botão de acção dentro de um card ("Cobrar →").
class KpiBotao extends StatelessWidget {
  const KpiBotao({super.key, required this.texto, required this.onPressed});
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(texto),
    ),
  );
}

String euros(int cents) {
  final valor = (cents / 100).toStringAsFixed(cents.abs() >= 100000 ? 0 : 2);
  return '${valor.replaceAll('.', ',')} €';
}

String percentagem(double? valor, {int decimais = 0}) =>
    valor == null ? '—' : '${valor.toStringAsFixed(decimais)}%';

/// Tendência com sinal e cor. `null` não inventa "0%".
class KpiTendencia extends StatelessWidget {
  const KpiTendencia({
    super.key,
    required this.variacao,
    required this.sufixo,
    this.maisEMelhor = true,
  });

  final double? variacao;
  final String sufixo;

  /// Em custos, subir é má notícia — a cor inverte-se.
  final bool maisEMelhor;

  @override
  Widget build(BuildContext context) {
    if (variacao == null) {
      return Text('Sem termo de comparação', style: Theme.of(context).textTheme.bodySmall);
    }
    final subiu = variacao! >= 0;
    final bom = subiu == maisEMelhor;
    return Row(
      children: [
        Icon(
          subiu ? Icons.trending_up : Icons.trending_down,
          size: 16,
          color: bom ? const Color(0xFF27500A) : const Color(0xFFB3261E),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${subiu ? '+' : ''}${variacao!.toStringAsFixed(0)}% $sufixo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: bom ? const Color(0xFF27500A) : const Color(0xFFB3261E),
            ),
          ),
        ),
      ],
    );
  }
}
