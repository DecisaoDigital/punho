import '../../domain/models/finance.dart';
import 'kpis.dart';
import 'operations_controller.dart';

/// **Caixa** — o que entrou menos o que saiu, do dia 1 até hoje.
///
/// A pergunta é a mais simples que há e é a que o painel não respondia de forma
/// isolada: *este mês, até agora, o dinheiro deu ou tirou?*
///
/// Duas regras desenham este número:
///
/// **O mês corrente não se mistura com o passado.** O valor grande é só deste
/// mês. Somar-lhe o que vinha de trás faria um número maior e menos útil: um
/// mês mau escondido por uma almofada antiga lê-se como um mês bom, e é
/// exactamente a leitura que leva alguém a gastar o que não devia.
///
/// **O passado continua a saber-se.** O acumulado até ao fim do mês anterior
/// vai à parte, num número pequeno. Quem quer saber com quanto entrou no mês
/// tem lá; quem só quer saber como corre o mês não tropeça nele.
class CaixaDoMes {
  const CaixaDoMes({
    required this.mes,
    required this.ate,
    required this.entradasCents,
    required this.saidasCents,
    required this.acumuladoAnteriorCents,
  });

  /// Dia 1 do mês a que esta leitura diz respeito.
  final DateTime mes;

  /// O último dia contado — hoje, quando o mês é o corrente.
  final DateTime ate;

  /// Recebimentos entre o dia 1 e [ate], inclusive.
  final int entradasCents;

  /// Despesas pagas no mesmo intervalo, mais os encargos declarados que já
  /// venceram — prestações de viaturas e rubricas de custo fixo com dia
  /// marcado. Não se lançam como despesa e é por isso que entram por aqui.
  final int saidasCents;

  /// O que ficou de trás, até ao fim do mês anterior, ou `null` quando não há
  /// movimento nenhum registado antes deste mês.
  ///
  /// **Só conta o que está registado.** Os custos fixos declarados não são
  /// projectados para os meses passados: declarar hoje uma renda não prova que
  /// ela foi paga nos doze meses anteriores, e inventar isso faria o acumulado
  /// mergulhar por causa de um formulário preenchido esta manhã.
  final int? acumuladoAnteriorCents;

  int get saldoCents => entradasCents - saidasCents;

  /// Nem entradas nem saídas: não há nada para ler, e um "0 €" mentiria.
  bool get semMovimentos => entradasCents == 0 && saidasCents == 0;
}

DateTime _inicioDoMes(DateTime data) => DateTime(data.year, data.month);
DateTime _dia(DateTime data) => DateTime(data.year, data.month, data.day);

/// A caixa do mês de [hoje], contada do dia 1 até [hoje].
///
/// O limite superior é o dia de hoje e não o fim do mês de propósito: um
/// recebimento lançado com data futura — acontece a quem regista uma
/// transferência agendada — inflaria o mês antes de o dinheiro existir.
CaixaDoMes caixaDoMes(OperationsState state, DateTime hoje) =>
    _caixaAte(state, _inicioDoMes(hoje), _dia(hoje));

/// A média do saldo dos meses anteriores **no mesmo ponto do mês**, ou `null`
/// se não houver nenhum mês anterior com movimento.
///
/// Existe para o cartão poder dizer se este mês está acima ou abaixo do
/// costume. Duas decisões que a tornam uma comparação e não um número bonito:
///
/// **Janela igual dos dois lados.** Comparar cinco dias deste mês com meses
/// inteiros dava sempre "estás muito abaixo" no dia 5 e "recuperaste" no 30 —
/// um sobe-e-desce que não diz nada sobre o negócio. Cada mês anterior é
/// contado do dia 1 ao mesmo dia (ou ao último, nos meses mais curtos).
///
/// **Contas feitas pelo mesmo caminho.** É a mesma função que calcula o número
/// grande, com outra janela — incluindo os encargos fixos declarados. Aplicá-los
/// só ao mês corrente fazia o presente parecer sistematicamente pior do que o
/// passado, e não há erro de leitura mais caro do que esse.
///
/// Meses sem movimento nenhum não entram na média: são meses sem informação, e
/// contá-los como zero puxava a média para baixo por causa de um mês em que a
/// empresa esteve fechada.
int? mediaDosMesesAnteriores(
  OperationsState state,
  DateTime hoje, {
  int meses = 6,
}) {
  final saldos = <int>[];
  for (var atras = 1; atras <= meses; atras++) {
    final mes = DateTime(hoje.year, hoje.month - atras);
    final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
    final caixa = _caixaAte(
      state,
      mes,
      DateTime(mes.year, mes.month, hoje.day.clamp(1, ultimoDia)),
    );
    if (!caixa.semMovimentos) saldos.add(caixa.saldoCents);
  }
  if (saldos.isEmpty) return null;
  return (saldos.reduce((a, b) => a + b) / saldos.length).round();
}

CaixaDoMes _caixaAte(OperationsState state, DateTime inicio, DateTime ate) {
  final entradas = receiptTotal(state.receipts, inicio, ate);

  // As categorias que já têm rubrica fixa declarada com data ficam de fora das
  // despesas: entram pelo valor declarado, e contá-las dos dois lados duplica
  // a saída. É a mesma regra de `tesourariaDoMes` — a fonte declarada manda.
  final pagas = paidExpenseTotal(
    state.expenses.where(
      (e) => !categoriasComRubricaDatada(state).contains(e.category),
    ),
    inicio,
    ate,
  );
  final encargos = encargosFixosVencidosCents(state, inicio, ate);

  return CaixaDoMes(
    mes: inicio,
    ate: ate,
    entradasCents: entradas,
    saidasCents: pagas + encargos,
    acumuladoAnteriorCents: _acumuladoAte(
      state,
      inicio.subtract(const Duration(days: 1)),
    ),
  );
}

/// Entradas menos saídas registadas até [fim], inclusive.
///
/// `null` quando não há um único movimento antes dessa data: um zero aqui
/// leria-se como "estava a zero", quando a verdade é "não há registo nenhum".
int? _acumuladoAte(OperationsState state, DateTime fim) {
  // Bem antes de qualquer registo possível. Não é uma data mágica: é só o
  // limite inferior de um intervalo que quer dizer "desde sempre".
  final principio = DateTime(2000);

  final houveMovimento =
      state.receipts.any(
        (r) => !r.archived && isInPeriod(r.date, principio, fim),
      ) ||
      state.expenses.any(
        (e) =>
            !e.archived &&
            e.status == ExpensePaymentStatus.paid &&
            isInPeriod(e.date, principio, fim),
      );
  if (!houveMovimento) return null;

  // Sem exclusão de categorias com rubrica datada: aqui não se somam encargos
  // declarados nenhuns, portanto excluir as despesas correspondentes deixaria
  // um buraco em vez de evitar uma duplicação.
  return receiptTotal(state.receipts, principio, fim) -
      paidExpenseTotal(state.expenses, principio, fim);
}
