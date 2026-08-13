/// **Os três mestres da cadeia** — Vendas, Lucro e Caixa.
///
/// O diagrama do plano de KPIs (`docs/kpis/`) põe três números no topo, e todos
/// os outros pendurados neles: um número mau tem de ter um filho que o
/// explique. Dois desses três não existiam no Punho. Havia contas de caixa —
/// `caixaDoMes`, `tesourariaDoMes` — e contas de saúde — `margemBruta`,
/// `fluxoDeCaixaLivre` — mas não havia **Vendas** nem **Lucro**.
///
/// ## Porque é que Vendas não é o mesmo que «dinheiros que entraram»
///
/// São perguntas diferentes e têm de dar números diferentes:
///
/// * **Vendas** é o que se vendeu no mês — o valor dos trabalhos feitos, tenham
///   sido pagos ou não. Responde a «o negócio está a andar?».
/// * **Caixa** é o que entrou menos o que saiu, no mês. Responde a «tenho
///   dinheiro?».
///
/// Uma casa pode vender bem e estar sem dinheiro, e é justamente esse o caso
/// que mata empresas — se os dois números forem o mesmo, a app nunca o mostra.
/// A diferença entre eles é o prazo de recebimento, que é um KPI filho.
///
/// ## De competência, não de caixa
///
/// **Vendas** e **Lucro** contam pela data em que a coisa aconteceu, não pela
/// data em que o dinheiro mexeu: as vendas pela data do trabalho, os custos
/// pela data da despesa, paga ou por pagar. É a única forma de o Lucro de
/// Abril falar de Abril.
///
/// O resto da app conta de caixa dos dois lados, e isso continua certo lá —
/// `margemBruta` di-lo no seu próprio comentário. O que não se pode é misturar:
/// receita de competência com custo de caixa dá uma margem que sobe sempre que
/// se atrasa um pagamento. Aqui os dois lados são de competência; na `caixa`
/// os dois lados são de caixa. Nunca meio e meio.
///
/// ## Nunca um zero silencioso
///
/// Todas as funções deste ficheiro devolvem `null` quando não há uma linha de
/// origem. Zero e «não sei» são coisas diferentes, e quem pinta a célula tem de
/// as poder distinguir para dizer o que falta em vez de mostrar um número
/// inventado.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import 'kpis_de_saude.dart' show custosDirectosDoAluguer;
import 'operations_controller.dart';

DateTime _inicioDoMes(DateTime d) => DateTime(d.year, d.month);
DateTime _fimDoMes(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// As três leituras de um mês, cada uma com o mês anterior e o homólogo ao
/// lado. Sem termo de comparação um número não se sabe ler.
class MesComparado {
  const MesComparado({
    required this.mes,
    required this.valorCents,
    required this.mesAnteriorCents,
    required this.homologoCents,
  });

  /// O primeiro dia do mês a que isto diz respeito.
  final DateTime mes;

  final int valorCents;

  /// `null` quando esse mês não tem uma única linha — não é zero, é ausência.
  final int? mesAnteriorCents;
  final int? homologoCents;

  /// Variação em percentagem face ao mês anterior, ou `null` sem termo (ou com
  /// termo a zero, que daria uma divisão sem significado).
  double? get variacaoMesAnterior => _variacao(mesAnteriorCents);

  /// Variação face ao mesmo mês do ano passado — a que interessa a um negócio
  /// com estações. Um estúdio de depilação a cair 30% de Agosto para Setembro
  /// não tem problema nenhum; a cair 30% face ao Setembro passado, tem.
  double? get variacaoHomologa => _variacao(homologoCents);

  double? _variacao(int? termo) {
    if (termo == null || termo == 0) return null;
    return (valorCents - termo) / termo.abs() * 100;
  }
}

// ---------------------------------------------------------------------------
// Vendas
// ---------------------------------------------------------------------------

/// Uma reserva conta para as vendas do mês em que **acabou** — é aí que o
/// trabalho ficou feito.
///
/// Não conta se foi cancelada, nem se ainda não tem preço: uma reserva sem
/// valor não é uma venda de zero euros, é uma venda por apurar, e é isso que a
/// tarefa «Pôr preço à reserva» existe para resolver.
bool _vendaDoMes(Booking b, DateTime inicio, DateTime fim) =>
    b.status != BookingStatus.cancelled &&
    (b.expectedValueCents ?? 0) > 0 &&
    isInPeriod(b.endsAt, inicio, fim);

int _vendasCents(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return s.bookings
      .where((b) => _vendaDoMes(b, inicio, fim))
      .fold(0, (t, b) => t + b.expectedValueCents!);
}

bool _temVendas(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return s.bookings.any((b) => _vendaDoMes(b, inicio, fim));
}

int? _vendasOuNada(OperationsState s, DateTime mes) =>
    _temVendas(s, mes) ? _vendasCents(s, mes) : null;

/// O que se vendeu este mês, com o mês passado e o homólogo ao lado.
///
/// `null` quando não há uma única reserva com valor neste mês — e aí a célula
/// diz o que falta em vez de mostrar 0 €.
MesComparado? vendasDoMes(OperationsState s, DateTime now) {
  if (!_temVendas(s, now)) return null;
  return MesComparado(
    mes: _inicioDoMes(now),
    valorCents: _vendasCents(s, now),
    mesAnteriorCents: _vendasOuNada(s, DateTime(now.year, now.month - 1)),
    homologoCents: _vendasOuNada(s, DateTime(now.year - 1, now.month)),
  );
}

// ---------------------------------------------------------------------------
// Custos e Estrutura
// ---------------------------------------------------------------------------

/// **O que se paga com a máquina parada.** É a contrapartida de
/// `custosDirectosDoAluguer`, em `kpis_de_saude.dart`: tudo o que não é custo
/// directo de servir o trabalho é estrutura.
///
/// Escreve-se por exclusão de propósito. Uma lista fechada de categorias de
/// estrutura ficava desactualizada em silêncio à primeira categoria nova, e uma
/// despesa que não entrasse em lista nenhuma desaparecia da conta sem ninguém
/// dar por isso.
///
/// A lista das directas vem de `kpis_de_saude.dart` e não se repete aqui: duas
/// cópias da mesma decisão dão dois números diferentes no dia em que alguém
/// mexer numa delas.
bool eEstrutura(ExpenseCategory c) => !custosDirectosDoAluguer.contains(c);

Iterable<Expense> _despesasDoMes(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  // Pagas **e** por pagar: é de competência. Uma despesa lançada em Abril e
  // paga em Junho é um custo de Abril — contá-la em Junho fazia Abril parecer
  // melhor do que foi e Junho pior.
  return s.expenses.where(
    (e) => !e.archived && isInPeriod(e.date, inicio, fim),
  );
}

int _custosCents(OperationsState s, DateTime mes) =>
    _despesasDoMes(s, mes).fold(0, (t, e) => t + e.amountCents);

int _estruturaCents(OperationsState s, DateTime mes) => _despesasDoMes(
  s,
  mes,
).where((e) => eEstrutura(e.category)).fold(0, (t, e) => t + e.amountCents);

bool _temDespesas(OperationsState s, DateTime mes) =>
    _despesasDoMes(s, mes).isNotEmpty;

/// **A Estrutura Compactada** do diagrama: quanto custa ter a casa aberta este
/// mês, seja qual for o trabalho que entre.
///
/// É o filho que explica um Lucro que caiu sem as Vendas caírem.
MesComparado? estruturaDoMes(OperationsState s, DateTime now) {
  if (!_temDespesas(s, now)) return null;
  int? ou(DateTime mes) =>
      _temDespesas(s, mes) ? _estruturaCents(s, mes) : null;
  return MesComparado(
    mes: _inicioDoMes(now),
    valorCents: _estruturaCents(s, now),
    mesAnteriorCents: ou(DateTime(now.year, now.month - 1)),
    homologoCents: ou(DateTime(now.year - 1, now.month)),
  );
}

// ---------------------------------------------------------------------------
// Lucro
// ---------------------------------------------------------------------------

int _lucroCents(OperationsState s, DateTime mes) =>
    _vendasCents(s, mes) - _custosCents(s, mes);

/// **Vendas menos tudo o que custou o mês.** Os dois lados de competência.
///
/// `null` só quando não há nem vendas nem despesas: com um dos lados a conta
/// já diz alguma coisa — um mês só com custos dá prejuízo, e é verdade.
MesComparado? lucroDoMes(OperationsState s, DateTime now) {
  bool ha(DateTime mes) => _temVendas(s, mes) || _temDespesas(s, mes);
  if (!ha(now)) return null;
  int? ou(DateTime mes) => ha(mes) ? _lucroCents(s, mes) : null;
  return MesComparado(
    mes: _inicioDoMes(now),
    valorCents: _lucroCents(s, now),
    mesAnteriorCents: ou(DateTime(now.year, now.month - 1)),
    homologoCents: ou(DateTime(now.year - 1, now.month)),
  );
}

/// **O lucro do mês passado** — o último mês inteiro, com o seu próprio mês
/// anterior e o seu homólogo ao lado.
///
/// Pedido do César (13 Ago 2026). Não é um duplicado do [lucroDoMes]: aquele é
/// o mês a decorrer, que a dia 13 tem a estrutura toda lá dentro e as vendas a
/// meio. Este é o **único mês fechado**, e por isso o único que se compara sem
/// ressalvas — é a régua contra a qual se lê o mês que está a acontecer.
MesComparado? lucroDoMesAnterior(OperationsState s, DateTime now) =>
    lucroDoMes(s, DateTime(now.year, now.month - 1));

/// A leitura mensal de um dos três mestres, pelo id do catálogo. `null` para
/// qualquer outro KPI.
///
/// Existe para o ecrã da cadeia poder mostrar os termos da comparação sem
/// repetir o mapa de ids em mais um sítio. Os ids vivem no catálogo, mas já são
/// referidos aqui ao lado, em `atencao.dart`, quando uma parcela diz a que KPI
/// corresponde — e duas listas do mesmo mapa desalinham-se à primeira mudança.
MesComparado? comparadoDoKpi(String kpiId, OperationsState s, DateTime now) =>
    switch (kpiId) {
      'vendas-mes' => vendasDoMes(s, now),
      'lucro-mes' => lucroDoMes(s, now),
      'estrutura-mes' => estruturaDoMes(s, now),
      _ => null,
    };

/// Margem do mês em percentagem das vendas. `null` sem vendas — sem
/// denominador não há percentagem, e 0% seria uma boa notícia falsa.
double? margemDoMes(OperationsState s, DateTime now) {
  final vendas = _vendasCents(s, now);
  if (vendas <= 0) return null;
  return _lucroCents(s, now) / vendas * 100;
}
