/// **O break even do mês** — quanto é preciso vender para manter a casa a
/// andar.
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
///   alvo             = o que a casa gasta num mês
///   vendas em falta  = alvo − o que já se vendeu
/// ```
///
/// E é só isto. **A despesa é a despesa** — a definição é dele, a 13 de Agosto,
/// a corrigir uma primeira versão em que eu separava custos de estrutura de
/// custos de servir o trabalho e dividia o alvo por uma margem de contribuição:
///
/// > como assim, a despeza é a despesa. daí a media de gastos dos meses
/// > anteriores. entre a renda fixa e a media de electicidade variavel e agua
/// > variavel e outros consumos e despesas, fazem parte das despesas do mes, é
/// > natural que todos os custos se repitam em media durantes todos os meses no
/// > futuro e presente. o breack even é o valor para manter a empresa em
/// > operaçao. temos de contabilizar todas as tabelas
///
/// A separação entre fixo e variável tinha uma vantagem teórica — vender mais
/// também custa mais a servir — e três defeitos práticos: obrigava a classificar
/// bem cada despesa, dava um número que ninguém consegue conferir de cabeça, e
/// respondia a uma pergunta que ele não fez. A pergunta é **«quanto tenho de
/// vender este mês para não estar a perder dinheiro?»**, e a resposta é o que a
/// casa gasta. A luz e a água variam, mas variam à volta de uma média — e é
/// essa média que se paga todos os meses.
///
/// ## De onde vem o alvo
///
/// O maior de três, porque nenhum deles sozinho serve o mês todo:
///
/// 1. **A despesa já lançada este mês.** Exacta, mas a dia 2 ainda é quase nada.
/// 2. **A média dos três meses anteriores.** É a ideia dele: os custos repetem-se
///    em média, portanto o que se gastou é a melhor previsão do que se vai
///    gastar.
/// 3. **Os custos fixos declarados** em Empresa › Custos fixos, para quem os
///    preencheu e ainda não tem histórico que chegue.
///
/// O maior dos três, e não uma soma: são três respostas à **mesma** pergunta, e
/// somá-las era contar a renda três vezes. Nunca abaixo do que já está lançado —
/// um mês com uma despesa extraordinária já registada não se lê pela média dos
/// meses normais.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/operations_controller.dart';

/// Quantos meses para trás entram na média. Três chegam para diluir um mês
/// estranho sem ir buscar uma realidade que já não é a da casa.
const _mesesDeRecurso = 3;

/// De onde saiu o alvo — o que a célula tem de dizer para o número não parecer
/// mais exacto do que é.
enum OrigemDoAlvo {
  /// Do que já está lançado neste mês. É o único que não é estimativa.
  lancado,

  /// Da média dos meses anteriores.
  media,

  /// Dos custos fixos declarados pelo gestor, por não haver histórico maior.
  declarado,
}

/// O mês a pagar-se a si próprio.
class BreakEvenDoMes {
  const BreakEvenDoMes({
    required this.alvoCents,
    required this.despesaLancadaCents,
    required this.origem,
    required this.vendasCents,
    required this.diaEmQuePassou,
    required this.diaPrevisto,
  });

  /// Quanto é preciso vender este mês para a casa se pagar.
  final int alvoCents;

  /// O que **já** está lançado este mês, sem estimativa nenhuma. Fica à mão
  /// para se poder mostrar a distância entre o que se sabe e o que se prevê.
  final int despesaLancadaCents;

  final OrigemDoAlvo origem;

  /// O que já se vendeu este mês, pela data do trabalho.
  final int vendasCents;

  /// O dia em que as vendas acumuladas passaram o alvo — exacto, contado venda
  /// a venda. `null` enquanto não passou.
  final int? diaEmQuePassou;

  /// Ao ritmo de vendas deste mês, o dia em que o alvo chega. `null` se já
  /// passou, ou se ao ritmo actual **não chega até ao fim do mês** — e essa é a
  /// notícia que interessa dar.
  final int? diaPrevisto;

  /// Quanto falta vender. Negativo depois de passar.
  int get faltaCents => alvoCents - vendasCents;

  bool get atingido => faltaCents <= 0;

  /// O alvo é uma previsão, e não o que já está lançado.
  bool get estimado => origem != OrigemDoAlvo.lancado;

  /// Parte do caminho já andado, em percentagem.
  double? get percorrido =>
      alvoCents <= 0 ? null : vendasCents / alvoCents * 100;
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

/// **Todas as despesas do mês, sem excepção de categoria.**
///
/// Pagas e por pagar, porque é de competência: uma despesa lançada em Abril e
/// paga em Junho é um custo de Abril. Arquivadas fora — arquivar é a forma de
/// dizer que aquilo não conta.
Iterable<Expense> _despesasDoMes(OperationsState s, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return s.expenses.where(
    (e) => !e.archived && isInPeriod(e.date, inicio, fim),
  );
}

int _despesaCents(OperationsState s, DateTime mes) =>
    _despesasDoMes(s, mes).fold(0, (t, e) => t + e.amountCents);

/// A média da despesa dos meses anteriores que têm registo.
///
/// Só entram meses **com** despesas: um mês em branco no meio do histórico não
/// é um mês de 0 € de renda, é um mês por preencher, e metê-lo na média puxava
/// o alvo para baixo em silêncio.
int? _mediaDaDespesa(OperationsState s, DateTime now) {
  var total = 0;
  var meses = 0;
  for (var atras = 1; atras <= 12 && meses < _mesesDeRecurso; atras++) {
    final mes = DateTime(now.year, now.month - atras);
    if (_despesasDoMes(s, mes).isEmpty) continue;
    total += _despesaCents(s, mes);
    meses++;
  }
  return meses == 0 ? null : total ~/ meses;
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
String? motivoSemBreakEven(OperationsState s, DateTime now) =>
    breakEvenDoMes(s, now) == null
    ? 'Sem despesas registadas — neste mês nem nos anteriores'
    : null;

/// Quanto falta vender para o mês se pagar.
///
/// `null` só quando não há de onde tirar o que a casa custa: nem despesas neste
/// mês, nem nos anteriores, nem custos fixos declarados. Nunca um zero
/// silencioso — sem saber o custo, a célula diz o que falta preencher.
BreakEvenDoMes? breakEvenDoMes(OperationsState s, DateTime now) {
  final lancada = _despesaCents(s, now);
  final media = _mediaDaDespesa(s, now);
  final declarado = s.custoFixoMensalCents;

  // O maior de três respostas à mesma pergunta. Somá-las era contar a renda
  // três vezes; ficar pela primeira era dizer, a dia 2, que o mês não custa
  // nada.
  var alvo = lancada;
  var origem = OrigemDoAlvo.lancado;
  if (media != null && media > alvo) {
    alvo = media;
    origem = OrigemDoAlvo.media;
  }
  if (declarado != null && declarado > alvo) {
    alvo = declarado;
    origem = OrigemDoAlvo.declarado;
  }
  if (alvo <= 0) return null;

  final vendas = _vendasCents(s, now);
  final passou = _diaEmQuePassou(s, now, alvo);

  int? previsto;
  if (passou == null && vendas > 0) {
    // Ao ritmo do que já se vendeu: quantos dias mais são precisos. É uma
    // projecção e não uma promessa — por isso desaparece quando não chega ao
    // fim do mês, em vez de apontar para um dia que não existe.
    final ritmoDiario = vendas / now.day;
    final dia = (alvo / ritmoDiario).ceil();
    if (dia <= _fimDoMes(now).day) previsto = dia;
  }

  return BreakEvenDoMes(
    alvoCents: alvo,
    despesaLancadaCents: lancada,
    origem: origem,
    vendasCents: vendas,
    diaEmQuePassou: passou,
    diaPrevisto: previsto,
  );
}
