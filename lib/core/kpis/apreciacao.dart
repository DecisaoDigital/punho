import 'package:flutter/foundation.dart';

/// Como está o número, dito por palavras.
///
/// «cada KPI deve ter na sua frente as regras de apreciação do próprio. "Estás
/// com 50% de conversão, estás acima da média em 3%!" Se for inferior à média,
/// também deve ter uma frase para mostrar» — Cesar, 5/8/2026.
///
/// Um número sozinho não ensina nada a quem o lê: 1 240 € de caixa é bom ou é
/// mau? Só se sabe ao pé de outra coisa. Esta é a regra que transforma o valor
/// numa leitura — e é uma só, partilhada por todos os KPIs, para que "acima da
/// média" queira dizer o mesmo em todo o lado da app.
enum TomDaApreciacao {
  /// Melhor que a referência, com folga.
  acima,

  /// À volta da referência — a diferença não muda decisão nenhuma.
  emLinha,

  /// Pior que a referência, com folga.
  abaixo,

  /// Não há com que comparar. Não é mau nem bom: é cedo.
  semTermo,
}

@immutable
class ApreciacaoDoKpi {
  const ApreciacaoDoKpi({required this.frase, required this.tom});

  /// A frase inteira, pronta a mostrar. Em português, na segunda pessoa — é ao
  /// dono da empresa que se fala.
  final String frase;

  final TomDaApreciacao tom;

  /// Subir é boa notícia neste KPI? Em custos é ao contrário, e é o widget que
  /// pinta a frase que precisa de o saber.
  bool get boaNoticia => tom == TomDaApreciacao.acima;
}

/// Abaixo desta diferença não se diz nada de acima nem de abaixo.
///
/// Serve para uma coisa só: impedir a frase "acima da tua média em 0%", que é o
/// que sai de uma diferença de meio por cento depois de arredondada. Não é para
/// decidir o que é relevante — o Cesar deu "acima da média em 3%" como exemplo
/// do que quer ver, e três por cento tem de passar. Quem lê é que decide se
/// três por cento lhe interessa.
const _bandaEmLinha = 0.01;

/// Compara [valor] com [referencia] e escreve a frase.
///
/// [nomeDaReferencia] entra na frase tal e qual ("a tua média dos meses
/// anteriores"), porque o que se compara faz parte do que se diz: "acima da
/// média" sem dizer de que média é uma afirmação que não se pode verificar.
///
/// [formatar] transforma uma quantidade absoluta em texto — os euros do KPI da
/// caixa, os pontos percentuais de uma taxa de conversão. Serve para o caso em
/// que a percentagem não faz sentido.
ApreciacaoDoKpi apreciar({
  required num? valor,
  required num? referencia,
  required String nomeDaReferencia,
  required String Function(num) formatar,
  String semTermo = 'Sem termo de comparação.',
  bool maisEMelhor = true,
}) {
  if (valor == null || referencia == null) {
    return ApreciacaoDoKpi(frase: semTermo, tom: TomDaApreciacao.semTermo);
  }

  final diferenca = valor - referencia;
  final melhor = maisEMelhor ? diferenca > 0 : diferenca < 0;

  // A percentagem só se escreve quando tem significado. Com a referência a zero
  // não há divisão possível; com sinais trocados — média negativa e mês
  // positivo — a conta dá números como "+250%" que descrevem uma passagem de
  // prejuízo a lucro como se fosse um crescimento, e ninguém lê aquilo bem. Nos
  // dois casos diz-se a diferença em bruto, que é sempre verdade.
  final podePercentagem =
      referencia != 0 && (valor >= 0) == (referencia >= 0);
  final proporcao = podePercentagem ? diferenca.abs() / referencia.abs() : null;

  if (proporcao != null && proporcao < _bandaEmLinha) {
    return ApreciacaoDoKpi(
      frase: 'Em linha com $nomeDaReferencia.',
      tom: TomDaApreciacao.emLinha,
    );
  }

  final quanto = proporcao != null
      ? '${(proporcao * 100).round()}%'
      : formatar(diferenca.abs());
  final referida = _de(nomeDaReferencia);
  return ApreciacaoDoKpi(
    frase: melhor
        ? 'Estás acima $referida em $quanto.'
        : 'Estás abaixo $referida em $quanto.',
    tom: melhor ? TomDaApreciacao.acima : TomDaApreciacao.abaixo,
  );
}

/// "a tua média" → "da tua média". Sem isto sai "acima de a tua média", que é
/// como ninguém fala — e o KPI perde a credibilidade antes de o número ser
/// lido.
String _de(String nome) => switch (nome.split(' ').first) {
  'a' => 'da ${nome.substring(2)}',
  'o' => 'do ${nome.substring(2)}',
  'as' => 'das ${nome.substring(3)}',
  'os' => 'dos ${nome.substring(3)}',
  _ => 'de $nome',
};
