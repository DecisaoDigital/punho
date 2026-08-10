/// **As contas de saúde da empresa** — as que a auditoria
/// (`docs/AUDITORIA_KPIS_EMPRESA.md`) apontou como em falta e as duas que se
/// perderam quando o painel deixou de ser slides.
///
/// Vivem aqui e não em `kpis.dart` porque aquele ficheiro já tem 1665 linhas.
/// A regra é a mesma: **funções puras de `(estado, agora)`**, sem ler relógio
/// nem disco, para o catálogo as poder chamar e os testes as poderem fixar num
/// dia.
///
/// ## O que é medido e o que é aproximado
///
/// Nenhuma destas contas tem a fonte ideal — a app não fala com o banco, não
/// tem contas a pagar com prazo, e não pergunta nada ao cliente. **Aproximado
/// e rotulado vale mais do que vazio**, mas a aproximação tem de estar dita no
/// próprio número, e não escondida no código. Cada classe abaixo diz de onde
/// veio o que devolve.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import 'kpis.dart';
import 'operations_controller.dart';

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _inicioDoMes(DateTime d) => DateTime(d.year, d.month);
DateTime _fimDoMes(DateTime d) =>
    DateTime(d.year, d.month + 1).subtract(const Duration(days: 1));

/// Quantas semanas tem um mês, em média. 365 ÷ 12 ÷ 7.
const _semanasPorMes = 4.348;

// ---------------------------------------------------------------------------
// Custos directos vs custos de estrutura
// ---------------------------------------------------------------------------

/// **O que custa servir o aluguer**, por oposição ao que custa ter a empresa
/// aberta. É esta linha que separa a margem bruta da margem operacional, e não
/// há nada nos dados que a trace sozinha — é uma decisão declarada.
///
/// Para um negócio de aluguer de máquinas: a manutenção da máquina que saiu, o
/// combustível de a levar e trazer, a manutenção da carrinha que a leva e os
/// consumíveis. A renda, a electricidade, a água, a limpeza, os salários, os
/// seguros e a publicidade são estrutura: pagam-se com a máquina parada.
///
/// Fica visível de propósito. No dia em que alguém discordar, discorda-se disto
/// e não de um número que apareceu do nada.
const custosDirectosDoAluguer = <ExpenseCategory>{
  ExpenseCategory.machineMaintenance,
  ExpenseCategory.fuel,
  ExpenseCategory.vehicleMaintenance,
  ExpenseCategory.supplies,
};

Iterable<Expense> _despesas(
  OperationsState s, {
  required DateTime de,
  required DateTime ate,
  bool Function(Expense)? onde,
}) => s.expenses.where(
  (e) =>
      !e.archived && isInPeriod(e.date, de, ate) && (onde == null || onde(e)),
);

int _soma(Iterable<LedgerMovement> movimentos) =>
    movimentos.fold(0, (t, m) => t + m.amountCents);

// ---------------------------------------------------------------------------
// 1 — Saldo de tesouraria e autonomia (runway)
// ---------------------------------------------------------------------------

/// Quanto há, e para quantas semanas dá.
///
/// **O saldo é aproximado e tem de ser dito.** A app não fala com o banco: o
/// que sabe é o que entrou (recebimentos) menos o que saiu (despesas **pagas**)
/// desde que há registo. Quem tinha dinheiro em conta antes de usar o Punho vê
/// aqui menos do que tem; quem começou com a app vê o número certo.
class SaldoEAutonomia {
  const SaldoEAutonomia({
    required this.saldoCents,
    required this.queimaSemanalCents,
    required this.desdeQuando,
  });

  final int saldoCents;

  /// O que a empresa gasta por semana: os custos fixos declarados mais a média
  /// mensal das despesas variáveis dos últimos três meses, tudo dividido pelas
  /// semanas do mês.
  final int queimaSemanalCents;

  /// A data do primeiro movimento registado — é a partir daqui que o saldo
  /// conta, e é isso que o torna aproximado.
  final DateTime desdeQuando;

  /// Para quantas semanas dá o que há. `null` quando não se queima nada — sem
  /// saída nenhuma registada não há autonomia para calcular, há falta de dados.
  double? get semanas =>
      queimaSemanalCents <= 0 ? null : saldoCents / queimaSemanalCents;

  /// Abaixo de seis semanas não se resolve com uma venda — é o limiar em que a
  /// conversa deixa de ser comercial e passa a ser de tesouraria.
  bool get apertado => (semanas ?? double.infinity) < 6;
}

/// `null` quando não há um único movimento registado: aí não é saldo zero, é
/// falta de dados, e são coisas diferentes.
SaldoEAutonomia? saldoEAutonomia(OperationsState s, DateTime now) {
  final recebimentos = s.receipts.where((r) => !r.archived);
  final pagas = s.expenses.where(
    (e) => !e.archived && e.status == ExpensePaymentStatus.paid,
  );
  if (recebimentos.isEmpty && pagas.isEmpty) return null;

  final datas = [
    for (final r in recebimentos) r.date,
    for (final e in pagas) e.date,
  ]..sort();

  // **Três meses completos, e só os que têm registo.**
  //
  // O mês em curso fica de fora: a 3 de Agosto tem três dias de despesas, e
  // dividir por três meses arrastava a média para baixo — numa medida de risco
  // isso é o pior erro possível, porque *aumenta* a autonomia que se anuncia.
  // Um mês sem lançamento nenhum também não conta: não é uma despesa de zero
  // euros, é ausência de dados (a mesma regra de `previsaoDoMes`).
  final categoriasFixas = s.custosFixos.map((c) => c.categoria).toSet();
  var mesesComRegisto = 0;
  var variaveis = 0;
  for (var atras = 1; atras <= 3; atras++) {
    final mes = DateTime(now.year, now.month - atras);
    final doMes = _despesas(
      s,
      de: _inicioDoMes(mes),
      ate: _fimDoMes(mes),
      onde: (e) => e.status == ExpensePaymentStatus.paid,
    ).toList();
    if (doMes.isEmpty) continue;
    mesesComRegisto++;
    variaveis += _soma(
      doMes.where((e) => !categoriasFixas.contains(e.category)),
    );
  }
  final mediaVariavel = mesesComRegisto == 0
      ? 0
      : (variaveis / mesesComRegisto).round();

  // **Sem rubricas, não se soma — escolhe-se.** As rubricas dizem que
  // categorias já estão declaradas, e o que não está nelas soma-se por cima.
  // O total redondo do onboarding não diz categoria nenhuma: somá-lo à média
  // medida contava a renda duas vezes. São duas respostas à mesma pergunta, e
  // fica a maior — que numa medida de risco é a prudente.
  final queimaMensal = s.custosFixos.isNotEmpty
      ? s.custoFixoMensalCents! + mediaVariavel
      : (s.fixedMonthlyCostsCents ?? 0) > mediaVariavel
      ? s.fixedMonthlyCostsCents!
      : mediaVariavel;
  return SaldoEAutonomia(
    saldoCents: _soma(recebimentos) - _soma(pagas),
    queimaSemanalCents: (queimaMensal / _semanasPorMes).round(),
    desdeQuando: datas.first,
  );
}

// ---------------------------------------------------------------------------
// 2 — Margem bruta e a sua trajectória
// ---------------------------------------------------------------------------

/// O que sobra da receita depois de pagar o que custou servi-la.
///
/// **De caixa dos dois lados.** A receita é o que entrou (recebimentos) e os
/// custos são os que se **pagaram** — não os que se lançaram. Misturar receita
/// de caixa com custo lançado dava uma margem que subia sempre que se atrasava
/// um pagamento. Toda a app conta assim, e um KPI que contasse de outra maneira
/// não era comparável com nenhum dos outros.
///
/// Não é o resultado do mês: os custos de estrutura ficam de fora de propósito.
/// É isto que diz se o preço/dia está bem posto — um mês pode fechar negativo
/// com margem bruta boa (estrutura a mais) ou fechar positivo com margem bruta
/// má (a vender abaixo do custo e a safar-se com um mês cheio).
class MargemBruta {
  const MargemBruta({
    required this.receitaCents,
    required this.custosDirectosCents,
    required this.mesAnteriorPercent,
  });

  final int receitaCents;
  final int custosDirectosCents;

  /// A mesma conta no mês passado, para se ver a trajectória. `null` quando não
  /// houve receita nenhuma nesse mês — não há margem de zero.
  final double? mesAnteriorPercent;

  double get percent =>
      (receitaCents - custosDirectosCents) / receitaCents * 100;

  /// Pontos percentuais ganhos ou perdidos face ao mês passado.
  double? get variacao =>
      mesAnteriorPercent == null ? null : percent - mesAnteriorPercent!;
}

double? _margemPercentDoMes(OperationsState s, DateTime mes) {
  final receita = receiptTotal(s.receipts, _inicioDoMes(mes), _fimDoMes(mes));
  if (receita <= 0) return null;
  final directos = _soma(
    _despesas(
      s,
      de: _inicioDoMes(mes),
      ate: _fimDoMes(mes),
      onde: (e) =>
          e.status == ExpensePaymentStatus.paid &&
          custosDirectosDoAluguer.contains(e.category),
    ),
  );
  return (receita - directos) / receita * 100;
}

/// `null` sem receita no mês: sem denominador não há percentagem, e inventar
/// uma era pior do que dizer que falta.
MargemBruta? margemBruta(OperationsState s, DateTime now) {
  final receita = receiptTotal(s.receipts, _inicioDoMes(now), _fimDoMes(now));
  if (receita <= 0) return null;
  return MargemBruta(
    receitaCents: receita,
    custosDirectosCents: _soma(
      _despesas(
        s,
        de: _inicioDoMes(now),
        ate: _fimDoMes(now),
        onde: (e) =>
            e.status == ExpensePaymentStatus.paid &&
            custosDirectosDoAluguer.contains(e.category),
      ),
    ),
    mesAnteriorPercent: _margemPercentDoMes(
      s,
      DateTime(now.year, now.month - 1),
    ),
  );
}

// ---------------------------------------------------------------------------
// 3 — Ciclo de conversão de tesouraria
// ---------------------------------------------------------------------------

/// Quantos dias o dinheiro passa fora do bolso: o que se demora a cobrar, mais
/// o que a máquina passa parada, menos o que se demora a pagar.
///
/// **É a versão simplificada** que a própria auditoria propõe (Parte D, nº 4).
/// O ciclo a sério precisa de contas a pagar com prazo, que a app não tem: o
/// que há é a despesa marcada como por pagar, e é dela que sai o DPO.
class CicloDeTesouraria {
  const CicloDeTesouraria({
    required this.diasACobrar,
    required this.diasParada,
    required this.diasAPagar,
    required this.janelaDias,
  });

  /// DSO — quanto se demora, em média, a receber o que já se facturou.
  final double diasACobrar;

  /// Quantos dias, em média, cada máquina esteve sem sair na janela.
  final double diasParada;

  /// DPO — quanto se demora a pagar a quem nos vende.
  final double diasAPagar;

  final int janelaDias;

  double get dias => diasACobrar + diasParada - diasAPagar;
}

/// `null` sem receita na janela: sem facturação não há ciclo nenhum a medir.
CicloDeTesouraria? cicloDeTesouraria(
  OperationsState s,
  DateTime now, {
  int janelaDias = 90,
}) {
  final ate = _dia(now);
  final de = ate.subtract(Duration(days: janelaDias - 1));
  final receita = receiptTotal(s.receipts, de, ate);
  if (receita <= 0) return null;

  final porCobrar = s.bookings
      .where(
        (b) =>
            b.status != BookingStatus.cancelled &&
            b.expectedValueCents != null &&
            !b.startsAt.isAfter(ate),
      )
      .fold<int>(
        0,
        (t, b) =>
            t + bookingPendingCents(b.expectedValueCents!, b.id, s.receipts),
      );

  final despesasDaJanela = _soma(_despesas(s, de: de, ate: ate));
  final porPagar = _soma(
    _despesas(
      s,
      de: de,
      ate: ate,
      onde: (e) => e.status == ExpensePaymentStatus.unpaid,
    ),
  );

  final activas = s.machines.where((m) => !m.archived).toList();

  // **Uma máquina não está parada antes de existir.** Comprada a meio da
  // janela, contavam-se-lhe como paradas as semanas anteriores à compra — e o
  // ciclo piorava por se ter investido, que é o contrário do que aconteceu.
  final diasNaFrota = <String, int>{
    for (final m in activas)
      m.id: () {
        final entrada = m.acquiredOn == null || _dia(m.acquiredOn!).isBefore(de)
            ? de
            : _dia(m.acquiredOn!);
        return ate.difference(entrada).inDays + 1;
      }(),
  };
  final diasAlugados = <String, int>{for (final m in activas) m.id: 0};
  for (final b in s.bookings) {
    if (b.status == BookingStatus.cancelled) continue;
    final inicio = b.startsAt.isBefore(de) ? de : _dia(b.startsAt);
    final fim = b.endsAt.isAfter(ate) ? ate : _dia(b.endsAt);
    if (fim.isBefore(inicio)) continue;
    final dias = fim.difference(inicio).inDays + 1;
    for (final id in b.machineIds) {
      if (diasAlugados.containsKey(id)) {
        diasAlugados[id] = (diasAlugados[id] ?? 0) + dias;
      }
    }
  }
  final naFrota = activas.where((m) => (diasNaFrota[m.id] ?? 0) > 0).toList();
  final paradas = naFrota.isEmpty
      ? 0.0
      : naFrota
                .map(
                  (m) => (diasNaFrota[m.id]! - (diasAlugados[m.id] ?? 0)).clamp(
                    0,
                    diasNaFrota[m.id]!,
                  ),
                )
                .fold<int>(0, (t, d) => t + d) /
            naFrota.length;

  return CicloDeTesouraria(
    diasACobrar: porCobrar / receita * janelaDias,
    diasParada: paradas,
    diasAPagar: despesasDaJanela <= 0
        ? 0
        : porPagar / despesasDaJanela * janelaDias,
    janelaDias: janelaDias,
  );
}

// ---------------------------------------------------------------------------
// 4 — Fluxo de caixa livre
// ---------------------------------------------------------------------------

/// O que sobra depois de pagar tudo **e** de repor máquina.
///
/// A diferença para o «Encontro de contas» é o investimento: um mês pode fechar
/// com saldo positivo e fluxo livre negativo porque se comprou uma máquina. São
/// coisas diferentes e o empresário precisa das duas — uma diz se o mês correu
/// bem, a outra diz se sobrou dinheiro para crescer.
class FluxoLivre {
  const FluxoLivre({
    required this.operacionalCents,
    required this.investimentoCents,
    required this.maquinasCompradas,
  });

  /// Recebido menos pago, no mês.
  final int operacionalCents;

  /// O que se gastou em máquinas com data de aquisição neste mês.
  final int investimentoCents;

  final int maquinasCompradas;

  int get livreCents => operacionalCents - investimentoCents;
}

/// `null` num mês sem movimento nenhum.
FluxoLivre? fluxoDeCaixaLivre(OperationsState s, DateTime now) {
  final mes = tesourariaDoMes(s, now);
  if (mes.semMovimentos) return null;

  final compradas = s.machines.where(
    (m) =>
        m.acquiredOn != null &&
        m.purchasePriceCents != null &&
        isInPeriod(m.acquiredOn!, _inicioDoMes(now), _fimDoMes(now)),
  );
  return FluxoLivre(
    operacionalCents: mes.recebidoCents - mes.saidasCents,
    investimentoCents: compradas.fold(0, (t, m) => t + m.purchasePriceCents!),
    maquinasCompradas: compradas.length,
  );
}

// ---------------------------------------------------------------------------
// 5 — Custo de aquisição de cliente
// ---------------------------------------------------------------------------

/// Quanto custou, em publicidade, cada cliente novo.
///
/// **A fonte é a categoria «Publicidade» das despesas** — não há campo de
/// marketing nem de comissões. Fica subestimado para quem paga angariação por
/// outra via, e isso diz-se: é um piso, não um custo total.
class CustoDeAquisicao {
  const CustoDeAquisicao({
    required this.investidoCents,
    required this.clientesNovos,
    required this.janelaDias,
  });

  final int investidoCents;

  /// `null` quando não há reserva nenhuma registada — aí não se sabe quem é
  /// cliente novo, o que é diferente de saber que não entrou ninguém.
  final int? clientesNovos;

  final int janelaDias;

  /// Não há como dizer quem entrou: sem reservas, a data em que alguém passou
  /// a cliente não existe em lado nenhum.
  bool get semComoContar => clientesNovos == null;

  /// `null` quando não entrou cliente nenhum — aí o custo não é infinito, é
  /// uma pergunta: gastou-se e não veio ninguém.
  int? get porClienteCents => (clientesNovos ?? 0) == 0
      ? null
      : (investidoCents / clientesNovos!).round();
}

/// `null` quando não há uma única despesa de publicidade na janela: sem
/// investimento não há custo de aquisição, há angariação orgânica.
CustoDeAquisicao? custoDeAquisicao(
  OperationsState s,
  DateTime now, {
  int janelaDias = 90,
}) {
  final ate = _dia(now);
  final de = ate.subtract(Duration(days: janelaDias - 1));
  final investido = _soma(
    _despesas(
      s,
      de: de,
      ate: ate,
      onde: (e) => e.category == ExpenseCategory.advertising,
    ),
  );
  if (investido <= 0) return null;
  return CustoDeAquisicao(
    investidoCents: investido,
    clientesNovos: clientesNovos(s, now, dias: janelaDias),
    janelaDias: janelaDias,
  );
}

// ---------------------------------------------------------------------------
// 6 — Receita de clientes recorrentes
// ---------------------------------------------------------------------------

/// Que fatia do mês veio de quem já cá tinha estado.
///
/// É o indicador mais barato de fidelização que há nestes dados: não precisa de
/// inquérito nenhum, só de contar quem volta. Um negócio de aluguer que viva de
/// clientes de uma vez só está sempre a recomeçar.
class ReceitaRecorrente {
  const ReceitaRecorrente({
    required this.recorrenteCents,
    required this.totalCents,
    required this.clientesRecorrentes,
    required this.clientesDoMes,
  });

  final int recorrenteCents, totalCents;
  final int clientesRecorrentes, clientesDoMes;

  double get percent => recorrenteCents / totalCents * 100;
}

/// `null` num mês sem recebimentos.
ReceitaRecorrente? receitaRecorrente(OperationsState s, DateTime now) {
  final inicio = _inicioDoMes(now);
  final fim = _fimDoMes(now);
  final doMes = s.receipts
      .where((r) => !r.archived && isInPeriod(r.date, inicio, fim))
      .toList();
  final total = _soma(doMes);
  if (total <= 0) return null;

  // Recorrente = já tinha reserva começada antes deste mês. A reserva é o
  // marco, e não o recebimento: quem alugou em Junho e só pagou em Agosto não
  // é cliente novo de Agosto.
  final deAntes = <String>{
    for (final b in s.bookings)
      if (b.status != BookingStatus.cancelled && b.startsAt.isBefore(inicio))
        b.customerId,
  };
  final recorrentes = doMes.where((r) => deAntes.contains(r.customerId));
  return ReceitaRecorrente(
    recorrenteCents: _soma(recorrentes),
    totalCents: total,
    clientesRecorrentes: recorrentes.map((r) => r.customerId).toSet().length,
    clientesDoMes: doMes.map((r) => r.customerId).toSet().length,
  );
}

// ---------------------------------------------------------------------------
// 7 — Leads a arrefecer
// ---------------------------------------------------------------------------

/// As leads que estão paradas há tempo de mais.
///
/// É o card de recomendação lateral que se perdeu quando o painel deixou de ser
/// slides: os números do funil ficaram, a prosa que dizia o que fazer com eles
/// não. Uma lead esquecida não aparece em contagem nenhuma — «leads em
/// pipeline» conta-a como se estivesse viva.
class LeadsFrias {
  const LeadsFrias({
    required this.frias,
    required this.diasDaMaisAntiga,
    required this.limiteDias,
  });

  final int frias;

  /// Há quantos dias está parada a mais antiga. `null` quando não há frias.
  final int? diasDaMaisAntiga;

  final int limiteDias;
}

/// Uma lead está fria se foi registada há mais de [limiteDias] e continua sem
/// sair do estado inicial.
LeadsFrias leadsFrias(OperationsState s, DateTime now, {int limiteDias = 14}) {
  final limite = _dia(now).subtract(Duration(days: limiteDias));
  final frias = s.leads
      .where(
        (l) =>
            (l.status == LeadStatus.newLead ||
                l.status == LeadStatus.contacted) &&
            l.createdAt.isBefore(limite),
      )
      .toList();
  if (frias.isEmpty) {
    return LeadsFrias(frias: 0, diasDaMaisAntiga: null, limiteDias: limiteDias);
  }
  final maisAntiga = frias
      .map((l) => l.createdAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return LeadsFrias(
    frias: frias.length,
    diasDaMaisAntiga: _dia(now).difference(_dia(maisAntiga)).inDays,
    limiteDias: limiteDias,
  );
}
