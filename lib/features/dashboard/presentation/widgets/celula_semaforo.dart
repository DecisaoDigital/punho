import 'package:flutter/material.dart';

enum NivelSemaforo { verde, laranja, vermelho }

/// Célula reutilizável do dashboard, com bordo lateral colorido por urgência.
///
/// Padrão editorial: rótulo pequeno em maiúsculas, valor grande (ou texto se
/// não houver valor), unidade discreta ao lado, e sub-texto em baixo.
class CelulaSemaforo extends StatelessWidget {
  const CelulaSemaforo({
    super.key,
    required this.nivel,
    required this.rotulo,
    this.valor,
    this.unidade,
    this.texto,
    this.subtexto,
    this.valorEmDestaque = false,
  }) : assert(valor != null || texto != null, 'valor ou texto obrigatório');

  final NivelSemaforo nivel;
  final String rotulo;
  final String? valor;
  final String? unidade;
  final String? texto;
  final String? subtexto;

  /// Quando true, o número é pintado com a cor do semáforo (para valores
  /// financeiros positivos/negativos). Caso contrário fica na cor do texto.
  final bool valorEmDestaque;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = switch (nivel) {
      NivelSemaforo.verde => const Color(0xFF3DC97A),
      NivelSemaforo.laranja => const Color(0xFFFFB246),
      NivelSemaforo.vermelho => const Color(0xFFFF5C6E),
    };
    // O bordo lateral é uma faixa dentro de um `ClipRRect`, e não um
    // `Border(left: ...)` mais largo que os outros lados. Um bordo não-uniforme
    // com `borderRadius` é inválido no Flutter: rebenta a asserção do
    // `BoxDecoration` mal alguém pinte isto num teste. Em release as asserções
    // estão desligadas, e foi por isso que passou despercebido enquanto os
    // slides não tiveram teste nenhum.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: cor),
            Expanded(child: _conteudo(context, cor)),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context, Color cor) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (valor != null)
            RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valorEmDestaque ? cor : cs.onSurface,
                  height: 1.1,
                ),
                children: [
                  TextSpan(text: valor),
                  if (unidade != null)
                    TextSpan(
                      text: ' ${unidade!}',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            )
          else
            Text(
              texto!,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (subtexto != null)
            Text(
              subtexto!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
