/// **O break even do mês** — quanto é preciso vender para o mês se pagar.
///
/// É a Fase 6 do plano de KPIs, e nasceu de uma frase do César (13 Ago 2026),
/// a propósito de o lucro de um mês a meio aparecer em baixo: *«não faz mal,
/// porque é o previsto até hoje. poderia ser negativo ainda não se ter feito o
/// break even do mês»*.
///
/// Está lá a razão de ser deste ficheiro. A meio do mês a estrutura já entrou
/// quase toda — a renda e os salários caem nos primeiros dias — e as vendas
/// ainda vão a meio. Um lucro baixo a dia 13 não é uma má notícia: é um mês que
/// ainda não virou. Sem este número o gestor lê a queda como problema; com ele
/// lê **«faltam 400 € para o mês se pagar»**, que é uma frase sobre a qual se
/// pode agir hoje.
///
/// ## A conta
///
/// ```
///   margem de contribuição = (vendas − custos directos) / vendas
///   vendas necessárias     = estrutura / margem de contribuição
/// ```
///
/// A **estrutura** é o que se paga com a máquina parada; os **custos directos**
/// são os de servir o trabalho e sobem com ele. A margem de contribuição é o
/// que sobra de cada euro vendido para pagar a estrutura.
///
/// **A hipótese, escrita:** os custos directos acompanham as vendas na mesma
/// proporção do que já aconteceu este mês. É a única forma de projectar sem
/// inventar uma curva, e é exacta na conta — vendendo exactamente
/// `vendasNecessariasCents`, o lucro do mês dá zero.
///
/// ## Quando ainda não há vendas
///
/// No dia 2 do mês a renda já está lançada e ainda não acabou trabalho nenhum:
/// não há margem deste mês para dividir. Em vez de calar o indicador
/// justamente no dia em que ele é mais útil, usa-se a margem dos meses
/// anteriores e **diz-se que é essa** ([BreakEvenDoMes.margemDoProprioMes]).
/// Um número aproximado e rotulado vale mais do que um vazio; o que não se pode
/// é apresentá-lo como se fosse deste mês.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/kpis_da_cadeia.dart' show eEstrutura;
import '../operations/operations_controller.dart';

/// Quantos meses para trás se vai buscar a margem, quando o mês corrente ainda
/// não tem vendas. Três chegam para diluir um mês estranho sem ir buscar uma
/// realidade que já não é a da casa.
const _mesesDeRecurso = 3;

/// O mês a pagar-se a si próprio.
class BreakEvenDoMes {
  const BreakEvenDoMes({
    required this.estruturaCents,
    required this.vendasCents,
    required this.vendasNecessariasCents,
    required this.margemDeContribuicao,
    required this.margemDoProprioMes,
    required this.diaEmQuePassou,
    required this.diaPrevisto,
  });

  /// O que este mês custa ter a casa aberta — o alvo a cobrir.
  final int estruturaCents;

  /// O que já se vendeu este mês, pela data do trabalho.
  final int vendasCents;

  /// Quanto tem de ser vendido no mês para o lucro dar zero.
  ///
  /// `null` quando a margem de contribuição é nula ou negativa: aí cada
  /// trabalho a mais afunda mais o mês, e **não há** volume de vendas que o
  /// pague. Dizer «faltam X €» nesse caso era mandar o gestor trabalhar mais
  /// para perder mais.
  final int? vendasNecessariasCents;

  /// Quanto sobra de cada euro vendido para pagar a estrutura, entre 0 e 1.
  final double margemDeContribuicao;

  /// A margem é deste mês (`true`) ou emprestada dos meses anteriores.
  final bool margemDoProprioMes;

  /// O dia em que as vendas acumuladas passaram o break even — exacto, contado
  /// venda a venda. `null` enquanto não passou.
  final int? diaEmQuePassou;

  /// Ao ritmo de vendas deste mês, o dia em que o break even chega. `null` se
  /// já passou, ou se ao ritmo actual **não chega até ao fim do mês** — e essa
  /// é a notícia que interessa dar.
  final int? diaPrevisto;

  /// Quanto falta vender. Negativo depois de passar; `null` sem break even
  /// alcançável.
  int? get faltaCents => vendasNecessariasCents == null
      ? null
      : vendasNecessariasCents! - vendasCents;

  bool get atingido => (faltaCents ?? 1) <= 0;

  /// Parte do caminho já andado, em percentagem. `null` quando não há alvo.
  double? get percorrido {
    final alvo = vendasNecessariasCents;
    if (alvo == null || alvo <= 0) return null;
    return vendasCents / alvo * 100;
  }
}

DateTime _inicioDoMes(DateTime d) => DateTime(d.year, d.month);
DateTime _fimDoMes(DateTime d) => DateTime(d.year, d.month + 1, 0);

Iterable<Booking> _vendasDoMes(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return s.bookings.where(
    (b) =>
        b.status != BookingStatus.cancelled &&
        (b.expectedValueCents ?? 0) > 0 &&
        isInPeriod(b.endsAt, inicio, fim),
  );
}

int _vendasCents(OperationsState s, DateTime mes) =>
    _vendasDoMes(s, mes).fold(0, (t, b) => t + b.expectedValueCents!);

Iterable<Expense> _despesasDoMes(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return s.expenses.where(
    (e) => !e.archived && isInPeriod(e.date, inicio, fim),
  );
}

int _estruturaCents(OperationsState s, DateTime mes) => _despesasDoMes(s, mes)
    .where((e) => eEstrutura(e.category))
    .fold(0, (t, e) => t + e.amountCents);

int _directosCents(OperationsState s, DateTime mes) => _despesasDoMes(s, mes)
    .where((e) => !eEstrutura(e.category))
    .fold(0, (t, e) => t + e.amountCents);

/// A margem de contribuição de um mês, ou `null` se esse mês não vendeu nada.
///
/// Pode vir **negativa**: um mês com poucas vendas e uma compra grande de
/// consumíveis gasta mais a servir do que recebe. Não se trunca a zero — é uma
/// notícia, e quem a lê tem de a poder distinguir de uma margem apertada.
double? _margemDe(OperationsState s, DateTime mes) {
  final vendas = _vendasCents(s, mes);
  if (vendas <= 0) return null;
  return (vendas - _directosCents(s, mes)) / vendas;
}

/// A margem dos meses anteriores, agregada — soma de vendas e soma de custos
/// directos, não uma média de percentagens (que daria peso igual a um mês de
/// 300 € e a um de 4 000 €).
double? _margemDosMesesAnteriores(OperationsState s, DateTime now) {
  var vendas = 0;
  var directos = 0;
  var meses = 0;
  for (var atras = 1; atras <= 12 && meses < _mesesDeRecurso; atras++) {
    final mes = DateTime(now.year, now.month - atras);
    final v = _vendasCents(s, mes);
    if (v <= 0) continue;
    vendas += v;
    directos += _directosCents(s, mes);
    meses++;
  }
  if (vendas <= 0) return null;
  return (vendas - directos) / vendas;
}

/// O dia do mês em que as vendas acumuladas passaram [alvoCents], contado pela
/// ordem em que os trabalhos acabaram. `null` se nunca chegaram lá.
int? _diaEmQuePassou(OperationsState s, DateTime now, int alvoCents) {
  final vendas = _vendasDoMes(s, now).toList()
    ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
  var acumulado = 0;
  for (final venda in vendas) {
    acumulado += venda.expectedValueCents!;
    if (acumulado >= alvoCents) return venda.endsAt.day;
  }
  return null;
}

/// Porque é que não há break even a mostrar — para a célula poder dizer o que
/// falta em vez de um «por apurar» que não ensina nada.
///
/// Vive aqui, ao lado da conta, e não no catálogo: quem decide que faltam dados
/// é quem os foi buscar. Devolve `null` quando **há** break even.
String? motivoSemBreakEven(OperationsState s, DateTime now) {
  if (breakEvenDoMes(s, now) != null) return null;
  if (_estruturaCents(s, now) <= 0) {
    return 'Sem despesas de estrutura lançadas este mês';
  }
  return 'Ainda não há vendas — deste mês nem dos anteriores';
}

/// Quanto falta vender para o mês se pagar.
///
/// `null` quando não há estrutura lançada este mês (não há alvo a cobrir) ou
/// quando não há margem conhecida — nem deste mês nem dos anteriores. Nunca um
/// zero silencioso: sem uma das duas pontas a célula diz o que falta.
BreakEvenDoMes? breakEvenDoMes(OperationsState s, DateTime now) {
  final estrutura = _estruturaCents(s, now);
  if (estrutura <= 0) return null;

  final margemDoMes = _margemDe(s, now);
  final margem = margemDoMes ?? _margemDosMesesAnteriores(s, now);
  if (margem == null) return null;

  final vendas = _vendasCents(s, now);
  final necessarias = margem <= 0 ? null : (estrutura / margem).round();

  int? previsto;
  int? passou;
  if (necessarias != null) {
    passou = _diaEmQuePassou(s, now, necessarias);
    if (passou == null && vendas > 0) {
      // Ao ritmo do que já se vendeu: quantos dias mais são precisos. É uma
      // projecção e não uma promessa — por isso desaparece quando não chega ao
      // fim do mês, em vez de apontar para um dia que não existe.
      final ritmoDiario = vendas / now.day;
      final dia = (necessarias / ritmoDiario).ceil();
      if (dia <= _fimDoMes(now).day) previsto = dia;
    }
  }

  return BreakEvenDoMes(
    estruturaCents: estrutura,
    vendasCents: vendas,
    vendasNecessariasCents: necessarias,
    margemDeContribuicao: margem,
    margemDoProprioMes: margemDoMes != null,
    diaEmQuePassou: passou,
    diaPrevisto: previsto,
  );
}
