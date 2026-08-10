import 'package:flutter/material.dart';

/// [aguarda] não é um nível de urgência — é a ausência dela.
///
/// Um painel de empresa nova tinha onze células laranja a dizer "Por apurar".
/// Laranja é cor de aviso: quem abre a app pela primeira vez não lê "ainda não
/// me deste dados", lê "está tudo mal". A falta de dados não é um problema do
/// negócio, é o princípio dele — e tem de se ver que é diferente.
enum NivelSemaforo { verde, laranja, vermelho, aguarda }

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
    this.emLinha = false,
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

  /// **Rótulo e número na mesma linha**, para quando a célula ocupa a largura
  /// toda em vez de um quarto do ecrã.
  ///
  /// A célula do painel é feita para a grelha 2×2, onde quatro dividem o ecrã:
  /// aí o rótulo por cima e o número por baixo aproveitam uma caixa estreita e
  /// alta. Na bancada é uma por linha, e a mesma anatomia deixava a metade
  /// direita vazia — medido a 10 de Agosto de 2026 no Redmi deitado: das
  /// catorze do catálogo, **doze ocupavam entre 47% e 65%** dos 555 dp de
  /// largura, e a altura de 150 dp era esticada para conteúdo que precisa de
  /// 62. Dois KPIs por ecrã, numa lista de catorze.
  ///
  /// Deitada, a mesma informação usa a largura que já lá estava e o cartão
  /// desce de 150 para os 84 dp medidos (`AlturaDoKpi.deitado`). Nada se corta:
  /// o `texto` e o `subtexto` juntam-se na segunda linha.
  final bool emLinha;

  /// A mesma célula, deitada. Para quem recebe uma célula já construída — a
  /// bancada recebe-as do catálogo e não sabe fazê-las.
  CelulaSemaforo deitada() => CelulaSemaforo(
    nivel: nivel,
    rotulo: rotulo,
    valor: valor,
    unidade: unidade,
    texto: texto,
    subtexto: subtexto,
    valorEmDestaque: valorEmDestaque,
    emLinha: true,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = switch (nivel) {
      NivelSemaforo.verde => const Color(0xFF3DC97A),
      NivelSemaforo.laranja => const Color(0xFFFFB246),
      NivelSemaforo.vermelho => const Color(0xFFFF5C6E),
      // Do tema, e não uma constante: tem de se ler nos dois fundos, e o que
      // se quer aqui é presença discreta — a faixa existe, mas não chama.
      NivelSemaforo.aguarda => cs.outline,
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
            Expanded(
              child: emLinha ? _deitada(context, cor) : _conteudo(context, cor),
            ),
          ],
        ),
      ),
    );
  }

  /// A segunda linha da célula deitada: o que a de pé mostra em dois sítios.
  ///
  /// Junta-se em vez de se escolher um. O `texto` das células à espera de dados
  /// é o que diz o que fazer («Regista um recebimento») e o `subtexto` é o
  /// caminho («Toca para abrir Finanças») — deitar a célula não é razão para
  /// deixar cair metade da instrução.
  String? get _segundaLinha {
    final partes = [texto, subtexto].whereType<String>();
    return partes.isEmpty ? null : partes.join(' · ');
  }

  Widget _deitada(BuildContext context, Color cor) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final segunda = _segundaLinha;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            // Pela linha de base e não pelo centro: o rótulo pequeno assenta no
            // mesmo chão do número grande, que é o que os faz ler como uma
            // linha só em vez de duas coisas empilhadas ao lado uma da outra.
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            // Os dois em `Flexible` frouxo e `spaceBetween`: cada um mede-se
            // pelo que precisa e o que sobra fica no meio, com o número
            // encostado à direita. Quando não sobra, encolhem os dois em vez de
            // transbordar — e o número leva três quartos do que houver, porque
            // é o que a linha existe para dizer. Com um deles fora do `Flexible`
            // transbordava: medido, 7,5 px num cartão de 300 dp.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  rotulo.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (valor != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  flex: 3,
                  child: RichText(
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: tt.titleLarge?.copyWith(
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
                  ),
                ),
              ],
            ],
          ),
          if (segunda != null) ...[
            const SizedBox(height: 3),
            Text(
              segunda,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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
              // 3 linhas mais o rótulo e o subtexto não cabem nos 83 dp da
              // célula em ecrãs estreitos — a recomendação, que é o único
              // texto realmente longo, ganha reticências mais cedo em vez de
              // rebentar a caixa (achado no teste de margens, 2026-08-03).
              //
              // Uma linha só quando a célula está à espera de dados: aqui o
              // texto substituiu o "Por apurar", que tinha uma linha garantida
              // por ser curto. Com duas, o orçamento de altura estourava e o
              // painel transbordava 17 px — medido, não estimado.
              maxLines: nivel == NivelSemaforo.aguarda ? 1 : 2,
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
