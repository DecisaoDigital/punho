import '../../../core/finance/regime_fiscal.dart';
import '../../../core/guidance/guidance_engine.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/finance.dart';

/// Para onde a acção do dia leva.
enum AccaoDoDia {
  /// Ficha do cliente em dívida (por agora, a área de Clientes — não existe
  /// ecrã de ficha individual).
  fichaCliente,

  /// Slide dos custos, no próprio painel.
  slideCustos,

  /// Slide do pipeline, para ver a conversão.
  slidePipeline,

  /// Lista completa de métricas, onde está a comparação homóloga.
  todasAsMetricas,
}

/// A sugestão do dia: uma frase, uma gravidade e um sítio para onde ir.
class RecomendacaoDoDia {
  const RecomendacaoDoDia({
    required this.regra,
    required this.texto,
    required this.gravidade,
    required this.cta,
    required this.accao,
    this.clienteId,
  });

  /// Identificador da regra que disparou. Serve os testes e o registo.
  final String regra;
  final String texto;
  final GravidadeRecomendacao gravidade;
  final String cta;
  final AccaoDoDia accao;
  final String? clienteId;
}

/// Limiares das regras. Ficam à vista para poderem ser discutidos sem ler
/// código.
const diasDividaUrgente = 30;
const diasDividaAtencao = 15;
const valorMinimoDividaUrgenteCents = 10000; // 100 €
const percentCustosCritica = 80.0;
const percentQuedaHomologa = 60.0;
const receitaHomologaMinimaCents = 50000; // 500 €
const taxaConversaoBoa = 40.0;

/// Escolhe **uma** acção para hoje, por ordem de urgência.
///
/// Substituiu o "Resultado provisório" na quarta célula do slide do dinheiro:
/// aquele número era recebido − pago, que já estava à vista nas duas células
/// acima, e não dizia o que fazer. Este diz.
///
/// Devolve `null` quando nada se aplica — nesse caso o card mostra "Sem
/// sugestão para hoje" em vez de inventar conselho.
RecomendacaoDoDia? recomendacaoDoDia(OperationsState state, DateTime now) {
  final dividas = _dividasPorCliente(state, now);

  // 1. Dinheiro antigo e de valor: é o que aperta mais.
  for (final divida in dividas) {
    if (divida.dias > diasDividaUrgente &&
        divida.totalCents >= valorMinimoDividaUrgenteCents) {
      return RecomendacaoDoDia(
        regra: 'divida-urgente',
        texto:
            'Cobrar ${divida.nome} — ${divida.dias} dias em atraso, '
            '${_euros(divida.totalCents)}',
        gravidade: GravidadeRecomendacao.urgente,
        cta: 'Abrir ficha →',
        accao: AccaoDoDia.fichaCliente,
        clienteId: divida.clienteId,
      );
    }
  }

  // 2. Os custos a levar quase tudo o que entra.
  //
  // O peso é calculado sobre o custo **real** do pessoal, com a carga social
  // incluída (Decisão 12). Isto faz a regra disparar mais cedo do que antes, e
  // é o que se pretende: uma equipa a 82% da receita estava a ler-se como 74%
  // porque faltava a TSU patronal. Não é falso positivo — era falso negativo.
  final custos = custosMesAgregados(
    state,
    now,
    regime: regimeDaFormaJuridica(state.legalForm),
  );
  final peso = custos.percentDaReceita;
  if (peso != null && peso >= percentCustosCritica) {
    return RecomendacaoDoDia(
      regra: 'custos-criticos',
      texto:
          'Custos a comer a receita — ${peso.round()}% do que entrou já saiu',
      gravidade: GravidadeRecomendacao.urgente,
      cta: 'Rever custos →',
      accao: AccaoDoDia.slideCustos,
    );
  }

  // 3. Dívida a caminho de se tornar problema.
  for (final divida in dividas) {
    if (divida.dias >= diasDividaAtencao && divida.dias <= diasDividaUrgente) {
      return RecomendacaoDoDia(
        regra: 'divida-atencao',
        texto: '${divida.nome} — ${divida.dias} dias sem pagar',
        gravidade: GravidadeRecomendacao.atencao,
        cta: 'Abrir ficha →',
        accao: AccaoDoDia.fichaCliente,
        clienteId: divida.clienteId,
      );
    }
  }

  // 4. A facturar bem abaixo do mesmo mês do ano passado.
  final homologa = _receitaHomologa(state, now);
  if (homologa != null && homologa >= receitaHomologaMinimaCents) {
    final esteMes = tesourariaDoMes(state, now).recebidoCents;
    final proporcao = esteMes / homologa * 100;
    if (proporcao < percentQuedaHomologa) {
      return RecomendacaoDoDia(
        regra: 'queda-homologa',
        texto:
            'A facturar ${proporcao.round()}% do que fizeste em '
            '${_mes(now.month)} do ano passado',
        gravidade: GravidadeRecomendacao.atencao,
        cta: 'Ver homóloga →',
        accao: AccaoDoDia.todasAsMetricas,
      );
    }
  }

  // 5. A converter bem: hora de pedir referências.
  final taxa = funilProcura(state, now, 30).taxa;
  if (taxa != null && taxa >= taxaConversaoBoa) {
    return RecomendacaoDoDia(
      regra: 'conversao-boa',
      texto:
          'Conversão a 30 dias em ${taxa.round()}% — pede referências aos '
          'últimos clientes',
      gravidade: GravidadeRecomendacao.oportunidade,
      cta: 'Ver conversão →',
      accao: AccaoDoDia.slidePipeline,
    );
  }

  return null;
}

/// Dívida agregada por cliente: o gestor cobra a uma pessoa, não a uma reserva.
class _DividaDeCliente {
  const _DividaDeCliente({
    required this.clienteId,
    required this.nome,
    required this.totalCents,
    required this.dias,
  });
  final String clienteId, nome;
  final int totalCents;

  /// Dias da dívida mais antiga deste cliente.
  final int dias;
}

List<_DividaDeCliente> _dividasPorCliente(OperationsState state, DateTime now) {
  final porCliente = <String, _DividaDeCliente>{};
  for (final cobranca in cobrancasPorReceber(state, now)) {
    if (cobranca.diasDeAtraso <= 0) continue;
    final id = cobranca.booking.customerId;
    final actual = porCliente[id];
    porCliente[id] = _DividaDeCliente(
      clienteId: id,
      nome: cobranca.clienteNome,
      totalCents: (actual?.totalCents ?? 0) + cobranca.emDividaCents,
      dias: actual == null
          ? cobranca.diasDeAtraso
          : (actual.dias > cobranca.diasDeAtraso
                ? actual.dias
                : cobranca.diasDeAtraso),
    );
  }
  final lista = porCliente.values.toList()
    ..sort((a, b) => b.dias.compareTo(a.dias));
  return lista;
}

/// Receita do mesmo mês do ano passado.
///
/// Prefere os recebimentos registados; se não houver nenhum, usa o valor que o
/// gestor declarou no histórico mensal. `null` quando não há nem um nem outro —
/// sem termo de comparação a regra não se aplica.
int? _receitaHomologa(OperationsState state, DateTime now) {
  final ano = now.year - 1;
  final registado = receiptTotal(
    state.receipts,
    DateTime(ano, now.month),
    DateTime(ano, now.month + 1).subtract(const Duration(days: 1)),
  );
  if (registado > 0) return registado;
  return state.historicalMonth(ano, now.month)?.revenueReceivedCents;
}

String _euros(int cents) =>
    '${(cents / 100).toStringAsFixed(cents.abs() >= 100000 ? 0 : 2).replaceAll('.', ',')} €';

const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String _mes(int mes) => _meses[mes - 1];
