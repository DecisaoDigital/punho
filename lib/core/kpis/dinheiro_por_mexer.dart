/// **As duas pontas do dinheiro que ainda não mexeu:** o que já devia ter
/// entrado e não entrou, e o que ainda tem de sair.
///
/// A app sabia dizer quanto se vendeu (competência) e quanto entrou na conta
/// (caixa). O que faltava era o **espaço entre os dois**, que é onde vive a
/// tesouraria de qualquer casa pequena: facturas velhas por cobrar de um lado,
/// facturas por pagar do outro.
///
/// ## Porque é que as «Cobranças a vencer (7d)» não chegavam
///
/// Aquela célula olha para a frente — e mistura: o filtro dela é «vence até
/// daqui a 7 dias», sem piso, portanto **o que já venceu há três meses está lá
/// dentro somado ao que vence na sexta**. Um número que junta a conta que se vai
/// cobrar naturalmente com a que já ninguém cobra não diz o que é preciso fazer.
/// Aqui separa-se: isto é só o que passou do prazo.
///
/// ## Onde está a fronteira do atraso
///
/// **No costume da própria casa.** A primeira versão punha-a no dia seguinte ao
/// fim do trabalho — e estava errada, como os dados mostraram assim que a
/// semente foi arrumada: na Depilconcept os clientes pagam com uma mediana de
/// **21 dias**, e um KPI que chama atraso aos 21 dias normais fica sempre aceso.
/// Um número sempre aceso não se lê. Dos 3 165 € que a app tinha por receber,
/// só 1 085 € tinham passado do costume; os outros 2 080 € eram dinheiro a
/// caminho, a horas.
///
/// A régua sai dos recibos que já lá estão: quantos dias, tipicamente, entre o
/// fim do trabalho e o dinheiro entrar. É a mesma ideia da apreciação da caixa —
/// **o padrão é o da empresa, não o do manual**. E diz-se na célula, porque uma
/// régua que não se vê não se pode contestar.
///
/// **Continua a não se inventar prazo de pagamento.** «30 dias» ou «60 dias»
/// seriam uma condição comercial que a app não guarda em lado nenhum. A mediana
/// não é uma condição: é o que aconteceu. Sem recibos que cheguem para a medir,
/// a fronteira volta ao dia seguinte ao fim do trabalho — e aí é o modelo do
/// Punho que manda, onde a cobrança vence quando o trabalho acaba.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/kpis.dart';
import '../operations/operations_controller.dart';

/// Um mês inteiro sem pagar já não é um esquecimento.
const diasParaCobrancaGrave = 30;

/// Abaixo disto não há costume nenhum, há uma coincidência. Com três ou quatro
/// recibos, a mediana é a de um cliente que se lembrou de pagar depressa.
const _recibosParaTerCostume = 8;

/// Tecto da régua. Uma casa que costuma receber a seis meses continua a precisar
/// de saber quem lhe deve — a partir daqui o costume deixa de ser costume e
/// passa a ser o problema.
const tectoDoCostume = 45;

/// Há quantos dias, tipicamente, esta casa recebe depois de acabar o trabalho.
///
/// `null` sem recibos que cheguem para dizer alguma coisa. Mediana e não média:
/// um cliente que pagou ao fim de um ano puxava a média sozinho e desligava o
/// KPI para toda a gente.
int? costumeDeRecebimento(OperationsState estado) {
  final porReserva = {for (final b in estado.bookings) b.id: b};
  final atrasos = <int>[];
  for (final recibo in estado.receipts) {
    if (recibo.archived) continue;
    final reserva = porReserva[recibo.bookingId];
    if (reserva == null) continue;
    final dias = _dia(recibo.date).difference(_dia(reserva.endsAt)).inDays;
    if (dias >= 0) atrasos.add(dias);
  }
  if (atrasos.length < _recibosParaTerCostume) return null;
  atrasos.sort();
  return atrasos[atrasos.length ~/ 2];
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// O que já venceu e ainda não entrou.
class CobrancasVencidas {
  const CobrancasVencidas({
    required this.totalCents,
    required this.clientes,
    required this.maisAntiga,
    required this.costumeDias,
  });

  final int totalCents;

  /// Quantos clientes devem. Um valor grande de um cliente só e o mesmo valor
  /// espalhado por oito são dois problemas diferentes — e resolvem-se com
  /// telefonemas diferentes.
  final int clientes;

  /// A cobrança com mais dias de atraso. É por onde se começa.
  final CobrancaEmAtraso maisAntiga;

  /// A régua que se usou: o costume da casa, ou `null` quando ainda não há
  /// recibos que cheguem e a fronteira é o dia seguinte ao fim do trabalho.
  final int? costumeDias;

  int get diasDoMaisAntigo => maisAntiga.diasDeAtraso;
  bool get grave => diasDoMaisAntigo >= diasParaCobrancaGrave;
}

/// `null` quando não há nada vencido por receber — que é a boa notícia, e não
/// uma falta de dados. Quem distingue as duas coisas é a célula: sem reservas
/// com valor não há pergunta nenhuma a fazer.
CobrancasVencidas? cobrancasVencidas(OperationsState estado, DateTime now) {
  final costume = costumeDeRecebimento(estado);
  // Sem costume medido, a fronteira é o dia seguinte ao fim do trabalho — no
  // modelo do Punho é aí que a cobrança vence. Com costume, é ele que manda:
  // o que ainda está dentro do prazo habitual não é uma cobrança falhada.
  final piso = costume == null ? 1 : costume.clamp(0, tectoDoCostume) + 1;
  final vencidas = cobrancasPorReceber(estado, now, minimoDiasAtraso: piso);
  if (vencidas.isEmpty) return null;

  return CobrancasVencidas(
    totalCents: vencidas.fold(0, (t, c) => t + c.emDividaCents),
    clientes: {for (final c in vencidas) c.booking.customerId}.length,
    // A lista vem ordenada do mais atrasado para o menos.
    maisAntiga: vencidas.first,
    costumeDias: costume,
  );
}

/// Há alguma reserva com valor de onde possa vir uma cobrança? Sem isto, a
/// célula não sabe distinguir «não deves nada a ninguém» de «ainda não me
/// disseste quanto valem os teus trabalhos».
bool haCobrancasPossiveis(OperationsState estado) => estado.bookings.any(
  (b) => b.status != BookingStatus.cancelled && (b.expectedValueCents ?? 0) > 0,
);

/// Uma despesa lançada e ainda por pagar há mais tempo do que isto já não é uma
/// factura recente — é uma que ficou para trás.
const diasParaDespesaVelha = 30;

/// O que ainda tem de sair da conta.
class ContasAPagar {
  const ContasAPagar({
    required this.totalCents,
    required this.quantas,
    required this.maisAntiga,
    required this.diasDaMaisAntiga,
  });

  final int totalCents;
  final int quantas;

  /// A despesa por pagar lançada há mais tempo.
  final Expense maisAntiga;
  final int diasDaMaisAntiga;

  bool get velha => diasDaMaisAntiga >= diasParaDespesaVelha;
}

/// Tudo o que está por pagar, **e não só o deste mês**.
///
/// Uma factura de Junho por pagar em Agosto não deixou de sair da conta por o
/// mês ter mudado — é exactamente a que mais interessa ver. Limitá-la ao mês
/// corrente fazia a dívida desaparecer do ecrã no dia 1, que é o oposto do que
/// este número existe para fazer.
///
/// `null` quando não há nada por pagar.
ContasAPagar? contasAPagar(OperationsState estado, DateTime now) {
  final porPagar = [
    for (final e in estado.expenses)
      if (!e.archived && e.status == ExpensePaymentStatus.unpaid) e,
  ];
  if (porPagar.isEmpty) return null;

  var maisAntiga = porPagar.first;
  for (final e in porPagar) {
    if (e.date.isBefore(maisAntiga.date)) maisAntiga = e;
  }
  final dias = DateTime(now.year, now.month, now.day)
      .difference(
        DateTime(
          maisAntiga.date.year,
          maisAntiga.date.month,
          maisAntiga.date.day,
        ),
      )
      .inDays;

  return ContasAPagar(
    totalCents: porPagar.fold(0, (t, e) => t + e.amountCents),
    quantas: porPagar.length,
    maisAntiga: maisAntiga,
    // Uma despesa lançada com data de amanhã não está por pagar há −1 dias.
    diasDaMaisAntiga: dias < 0 ? 0 : dias,
  );
}
