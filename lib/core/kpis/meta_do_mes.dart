import '../../domain/models/finance.dart';
import '../operations/kpis.dart';
import '../operations/operations_controller.dart';

/// **A meta do mês**, que é do empresário e não da app.
///
/// A «Tendência do mês» é a app a olhar para trás e a dizer onde o histórico
/// aponta. A meta é o contrário: a cada trimestre o empresário responde a
/// *quanto prevê crescer a empresa*, e a app traduz a resposta em meta para
/// cada um dos três meses — o mesmo mês do ano passado vezes (1 + crescimento).
///
/// Pedido do César (11 Out 2026): é a pergunta que um empresário que gere a
/// empresa a sério faz à equipa no fim de cada período, e a app existe também
/// para ensinar a fazê-la.
class MetaDoMes {
  const MetaDoMes({
    required this.metaCents,
    required this.homologoCents,
    required this.crescimento,
    required this.recebidoCents,
  });

  final int metaCents;

  /// O mesmo mês do ano passado, a base da conta.
  final int homologoCents;

  /// O crescimento que o empresário prometeu para este trimestre (fração).
  final double crescimento;

  /// O que já entrou este mês.
  final int recebidoCents;

  /// Quanto da meta já foi cumprido (1,0 = 100%).
  double get cumprido => metaCents <= 0 ? 0 : recebidoCents / metaCents;
}

/// A chave do trimestre: `2026-T4`.
String chaveDoTrimestre(DateTime d) => '${d.year}-T${(d.month - 1) ~/ 3 + 1}';

/// O trimestre seguinte ao de [d].
DateTime trimestreSeguinte(DateTime d) => DateTime(d.year, d.month + 3);

/// «4.º trimestre de 2026».
String nomeDoTrimestre(DateTime d) =>
    '${(d.month - 1) ~/ 3 + 1}.º trimestre de ${d.year}';

/// A meta deste mês, ou `null` quando o empresário ainda não respondeu ao
/// trimestre — ou não há o mesmo mês do ano passado para lhe aplicar o
/// crescimento. Nunca se inventa um valor.
MetaDoMes? metaDoMes(OperationsState s, DateTime now) {
  final g = s.metasDeCrescimento[chaveDoTrimestre(now)];
  if (g == null) return null;
  final homologo = recebidoNoMes(s, DateTime(now.year - 1, now.month));
  if (homologo <= 0) return null;
  return MetaDoMes(
    metaCents: (homologo * (1 + g)).round(),
    homologoCents: homologo,
    crescimento: g,
    recebidoCents: receiptTotal(
      s.receipts,
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1, 0),
    ),
  );
}

/// O crescimento que a app sugere como ponto de partida da resposta: o
/// crescimento médio que a empresa já teve. `null` sem histórico.
double? crescimentoSugerido(OperationsState s, DateTime now) =>
    previsaoPorCrescimento(s, now)?.crescimentoMedio;
