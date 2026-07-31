import '../../domain/models/workforce.dart';
import 'regime_fiscal.dart';

/// TSU do trabalhador dependente. Constante, não depende de escalão.
const double taxaTsuTrabalhador = 0.11;

/// TSU da entidade patronal — o "custo carregado" que não aparece no
/// vencimento. 1 000 € de bruto custam 1 237,50 € à empresa.
const double taxaTsuEntidadePatronal = 0.2375;

/// Quanto abate cada dependente à taxa de IRS, em pontos percentuais.
///
/// Simplificação grosseira: a lei faz deduções fixas por dependente, não
/// pontos de taxa. Está assim de propósito — a alternativa era uma tabela de
/// três dimensões que ninguém mantém. Ver `references/tabelas_irs_2026.md`.
const double abatimentoPorDependente = 0.008;

/// O que sai da empresa e o que entra no bolso do trabalhador.
///
/// Nunca é guardada: recalcula-se sempre a partir do estado. Um valor destes em
/// base de dados envelhece em silêncio quando as taxas mudam de ano.
class EstimativaSalarial {
  const EstimativaSalarial({
    required this.regime,
    required this.tipo,
    required this.brutoCents,
    required this.tsuTrabalhadorCents,
    required this.irsRetencaoCents,
    required this.liquidoTrabalhadorCents,
    required this.tsuEntidadePatronalCents,
    required this.custoEmpresaCents,
    required this.descricao,
    required this.estimativaConservadora,
  });

  final RegimeFiscal regime;
  final EmploymentType tipo;

  /// `null` quando não foi declarado nenhum bruto. Zero seria uma afirmação —
  /// "não paga nada" — e o que se passa é que não se sabe.
  final int? brutoCents;

  /// A zero em recibos verdes: os descontos do prestador são dele.
  final int tsuTrabalhadorCents;

  /// `null` quando não há bruto para escalonar, ou em recibos verdes, onde a
  /// retenção é decisão de quem emite o recibo e não da empresa.
  final int? irsRetencaoCents;

  /// `null` sempre que o IRS for `null`: bruto − TSU − IRS não se calcula sem
  /// as três parcelas.
  final int? liquidoTrabalhadorCents;

  /// A zero em recibos verdes: não há carga social da entidade patronal.
  final int tsuEntidadePatronalCents;

  /// O número que o gestor precisa. `null` só quando não há bruto declarado.
  final int? custoEmpresaCents;

  /// Legível, para a UI não ter de recompor a partir dos enums.
  final String descricao;

  /// `true` quando algum valor foi calculado pelo lado seguro — hoje só o
  /// `MaritalStatus.other`, que usa a coluna de solteiro (a mais pesada), pelo
  /// que o líquido estimado sai por baixo em vez de por cima.
  final bool estimativaConservadora;
}

/// Estima o custo com uma pessoa, à luz do regime fiscal da empresa.
///
/// O `regime` é **obrigatório e não assumido**: em ENI o próprio empresário não
/// é colaborador de si mesmo, um regime simplificado presume custos por
/// coeficiente, e há formas jurídicas que a app ainda não sabe tratar. Assumir
/// um regime por omissão dentro desta função era esconder a decisão no sítio
/// onde ninguém a vê. Ver Decisão 1 do guião do percurso.
///
/// Devolve `null` quando **não há cálculo aplicável** ao par regime × tipo — o
/// caso de [RegimeFiscal.outro]. A UI mostra "Estimativa não disponível para
/// este regime × contrato; edita manualmente" em vez de um número inventado.
///
/// Nota sobre a assinatura pedida: `null` não pode transportar
/// `estimativaConservadora: false`, porque não há objecto onde o pôr. Ausência
/// de estimativa e estimativa conservadora são coisas diferentes, e o `null`
/// diz a primeira sem ambiguidade.
EstimativaSalarial? estimarSalarial({
  required RegimeFiscal regime,
  required EmploymentType tipo,
  MaritalStatus estado = MaritalStatus.unmarried,
  int dependentes = 0,
  int? brutoMensalCents,
}) {
  // Regime não modelado: não há cálculo, e inventar um genérico seria dar
  // aparência de certeza a um palpite.
  if (regime == RegimeFiscal.outro) return null;

  final bruto = brutoMensalCents != null && brutoMensalCents > 0
      ? brutoMensalCents
      : null;

  if (tipo == EmploymentType.recibosVerdes) {
    // O valor pago é o custo total. A retenção de IRS, quando existe, sai do
    // que se paga ao prestador em vez de acrescer — logo não é custo da
    // empresa e não se estima aqui.
    return EstimativaSalarial(
      regime: regime,
      tipo: tipo,
      brutoCents: bruto,
      tsuTrabalhadorCents: 0,
      irsRetencaoCents: null,
      liquidoTrabalhadorCents: null,
      tsuEntidadePatronalCents: 0,
      custoEmpresaCents: bruto,
      descricao: 'Recibos verdes · ${rotuloDeRegime(regime)}',
      estimativaConservadora: false,
    );
  }

  final tsuTrabalhador = bruto == null
      ? 0
      : (bruto * taxaTsuTrabalhador).round();
  final tsuPatronal = bruto == null
      ? 0
      : (bruto * taxaTsuEntidadePatronal).round();
  final taxaIrs = bruto == null ? null : _taxaDeIrs(bruto, estado, dependentes);
  final irs = bruto == null || taxaIrs == null
      ? null
      : (bruto * taxaIrs).round();

  return EstimativaSalarial(
    regime: regime,
    tipo: tipo,
    brutoCents: bruto,
    tsuTrabalhadorCents: tsuTrabalhador,
    irsRetencaoCents: irs,
    liquidoTrabalhadorCents: bruto == null || irs == null
        ? null
        : bruto - tsuTrabalhador - irs,
    tsuEntidadePatronalCents: tsuPatronal,
    // O custo da empresa calcula-se sem saber nada do trabalhador: é bruto mais
    // TSU patronal. Por isso existe mesmo quando o líquido não.
    custoEmpresaCents: bruto == null ? null : bruto + tsuPatronal,
    descricao: [
      'Contrato',
      rotuloDeEstadoCivil(estado),
      if (dependentes > 0)
        '$dependentes ${dependentes == 1 ? 'dependente' : 'dependentes'}',
    ].join(' · '),
    // "Outro" estado civil lê-se pela coluna de solteiro, a mais pesada.
    estimativaConservadora: estado == MaritalStatus.other,
  );
}

/// Taxa marginal aproximada de IRS sobre o bruto mensal.
///
/// Aproximação por escalão: as tabelas reais têm parcela a abater e são
/// progressivas. Ver `references/tabelas_irs_2026.md`, que é o sítio a
/// actualizar quando o ano mudar.
double _taxaDeIrs(int brutoCents, MaritalStatus estado, int dependentes) {
  final euros = brutoCents / 100;
  final coluna = switch (estado) {
    MaritalStatus.unmarried => 0,
    MaritalStatus.married1Holder => 1,
    MaritalStatus.married2Holders => 2,
    // Coluna de solteiro: a mais conservadora das três.
    MaritalStatus.other => 0,
  };
  const escaloes = <({double ate, List<double> taxas})>[
    (ate: 870, taxas: [0.0, 0.0, 0.0]),
    (ate: 1000, taxas: [0.043, 0.0, 0.022]),
    (ate: 1200, taxas: [0.086, 0.019, 0.061]),
    (ate: 1500, taxas: [0.124, 0.054, 0.096]),
    (ate: 2000, taxas: [0.168, 0.099, 0.140]),
    (ate: 2700, taxas: [0.215, 0.146, 0.187]),
    (ate: 4000, taxas: [0.265, 0.198, 0.238]),
    (ate: 6000, taxas: [0.313, 0.252, 0.289]),
    (ate: double.infinity, taxas: [0.350, 0.300, 0.330]),
  ];
  final base = escaloes
      .firstWhere((escalao) => euros <= escalao.ate)
      .taxas[coluna];
  // Nunca abaixo de zero: dez dependentes não geram IRS negativo.
  final comDependentes = base - dependentes * abatimentoPorDependente;
  return comDependentes < 0 ? 0 : comDependentes;
}
