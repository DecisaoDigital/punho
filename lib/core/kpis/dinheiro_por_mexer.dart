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
/// No **fim do trabalho**, que é o mesmo sítio onde o irmão põe o «vence hoje».
/// Uma reserva a decorrer não tem dívida atrasada, tem dinheiro a caminho.
/// Conta-se a partir do dia seguinte: o que vence hoje já está pintado de
/// vermelho na outra célula, e um trabalho que acabou esta manhã não é uma
/// cobrança falhada.
///
/// **Não se inventa prazo de pagamento.** «30 dias» ou «60 dias» seriam uma
/// condição comercial que a app ainda não guarda em lado nenhum — escrevê-la
/// aqui era decidir por ele o que ele nunca disse. Quando as condições de
/// pagamento existirem no cliente, é este piso que passa a lê-las.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/kpis.dart';
import '../operations/operations_controller.dart';

/// Um mês inteiro sem pagar já não é um esquecimento.
const diasParaCobrancaGrave = 30;

/// O que já venceu e ainda não entrou.
class CobrancasVencidas {
  const CobrancasVencidas({
    required this.totalCents,
    required this.clientes,
    required this.maisAntiga,
  });

  final int totalCents;

  /// Quantos clientes devem. Um valor grande de um cliente só e o mesmo valor
  /// espalhado por oito são dois problemas diferentes — e resolvem-se com
  /// telefonemas diferentes.
  final int clientes;

  /// A cobrança com mais dias de atraso. É por onde se começa.
  final CobrancaEmAtraso maisAntiga;

  int get diasDoMaisAntigo => maisAntiga.diasDeAtraso;
  bool get grave => diasDoMaisAntigo >= diasParaCobrancaGrave;
}

/// `null` quando não há nada vencido por receber — que é a boa notícia, e não
/// uma falta de dados. Quem distingue as duas coisas é a célula: sem reservas
/// com valor não há pergunta nenhuma a fazer.
CobrancasVencidas? cobrancasVencidas(OperationsState estado, DateTime now) {
  // `minimoDiasAtraso: 1` — venceu **antes** de hoje. Ver a nota da fronteira.
  final vencidas = cobrancasPorReceber(estado, now, minimoDiasAtraso: 1);
  if (vencidas.isEmpty) return null;

  return CobrancasVencidas(
    totalCents: vencidas.fold(0, (t, c) => t + c.emDividaCents),
    clientes: {for (final c in vencidas) c.booking.customerId}.length,
    // A lista vem ordenada do mais atrasado para o menos.
    maisAntiga: vencidas.first,
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
