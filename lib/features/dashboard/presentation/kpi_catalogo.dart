/// **O catálogo de KPIs** — a fonte única de todas as células.
///
/// Antes, cada célula vivia dentro do seu slide, como método privado, e a "KPIs
/// (todos)" não tinha como as mostrar sem copiar o código. Aqui cada KPI é uma
/// **função pura** `(OperationsState, DateTime) -> CelulaSemaforo`: o painel
/// consome-a para o que o gestor lá pôs e a bancada consome-a para a lista
/// completa. Um número, um sítio para o calcular.
///
/// Os slides desapareceram (Ago 2026) — o painel passou a ser escolhido, quatro
/// por ecrã. Os comentários que abaixo os nomeiam ficam por serem a origem de
/// cada grupo de KPIs, e não por haver ainda algum ecrã com esse nome.
///
/// **O estado de verdade.** O César (9 Ago 2026) quer a app a crescer com o
/// empresário: à medida que ele mete informação, vê KPIs *a chegar*. Por isso
/// cada KPI sabe dizer em que ponto está — falta dado, falta o nosso crivo, ou
/// está pronto a subir ao painel a dizer verdade.
library;

import '../../../core/guidance/guidance_engine.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/kpis/apreciacao.dart';
import '../../../core/operations/caixa.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/kpis_de_saude.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/arranjo_do_painel.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/operations.dart';
import 'widgets/celula_semaforo.dart';
import 'widgets/kpi_grid_2x2.dart';

// ---------------------------------------------------------------------------
// Estado de verdade
// ---------------------------------------------------------------------------

/// Em que ponto está um KPI no caminho até poder subir ao painel.
enum EstadoVerdade {
  /// Falta preencher a fonte — a célula está em "aguarda"/"por definir". É o
  /// que o empresário desbloqueia quando adiciona a informação em falta.
  porDefinir,

  /// Fonte cheia (há número, mesmo que seja um 0 verdadeiro), mas a **conta**
  /// ainda não passou pelo nosso crivo. Chegou, falta confirmar que fala verdade.
  porVerificar,

  /// Fonte cheia **e** conta verificada. Pode subir ao painel.
  pronto,
}

/// Uma entrada do catálogo: o KPI, como se calcula, e o seu estado de verdade.
class KpiDefinicao {
  const KpiDefinicao({
    required this.id,
    required this.titulo,
    required this.celula,
    required this.contaVerificada,
    required this.desbloqueio,
    this.destino,
  });

  /// Estável, kebab-case. Serve de chave para a promoção manual ao painel.
  final String id;

  /// O rótulo humano, o mesmo que a célula mostra.
  final String titulo;

  /// Constrói a célula a partir do estado. Pura em `(state, now)`.
  final CelulaSemaforo Function(OperationsState, DateTime) celula;

  /// Já confirmámos a fórmula? É o crivo humano — não se computa. Vira `true` à
  /// medida que verificamos cada KPI, um a um.
  final bool contaVerificada;

  /// Que dado (ou pergunta) acende este KPI. É o mapa ao contrário que prioriza
  /// a fila de perguntas: KPI → dado que falta → pergunta a fazer.
  final String desbloqueio;

  /// Onde se vai agir sobre esta leitura, se houver sítio para isso.
  ///
  /// É a Decisão 7 do guião — cada número tem de ter caminho para onde se mexe
  /// nele. Vivia dentro do slide da síntese, e por isso desaparecia assim que
  /// a célula fosse mostrada noutro sítio. Aqui anda com o KPI: quem o pinta
  /// não tem de saber para onde ele leva.
  final AppDestination? destino;

  /// Fonte cheia = a célula não está à espera de dados.
  bool fonteCheia(OperationsState s, DateTime now) =>
      celula(s, now).nivel != NivelSemaforo.aguarda;

  /// O estado de verdade neste momento, para este estado da empresa.
  EstadoVerdade estado(OperationsState s, DateTime now) {
    if (!fonteCheia(s, now)) return EstadoVerdade.porDefinir;
    return contaVerificada ? EstadoVerdade.pronto : EstadoVerdade.porVerificar;
  }
}

// ---------------------------------------------------------------------------
// O catálogo
// ---------------------------------------------------------------------------

const catalogoKpis = <KpiDefinicao>[
  // Fora do carrossel — nascidas já na "KPIs (todos)", hoje (9 Ago 2026).
  KpiDefinicao(
    id: 'caixa',
    titulo: 'Caixa',
    celula: kpiCaixa,
    contaVerificada: true,
    desbloqueio: 'Entradas e saídas registadas este mês',
  ),
  KpiDefinicao(
    id: 'tendencia-mes',
    titulo: 'Tendência do mês',
    celula: kpiTendencia,
    contaVerificada: true,
    desbloqueio:
        'Recebimentos/reservas do mês + o mês passado '
        '(recibos ou histórico do contabilista)',
  ),
  // Slide 1 — Síntese
  KpiDefinicao(
    id: 'entradas-mes',
    titulo: 'Dinheiros que entraram',
    celula: kpiEntradas,
    contaVerificada: true,
    desbloqueio: 'Recebimentos registados (ou histórico mensal preenchido)',
    // O valor é do mês, e o toque leva a onde as entradas se vão registando.
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'utilizacao-rentabilidade',
    titulo: 'Utilização vs Rentabilidade',
    celula: kpiUtilizacao,
    contaVerificada: true,
    desbloqueio: 'Preço/dia em todas as máquinas + valor de compra em ≥1',
  ),
  KpiDefinicao(
    id: 'encontro-contas',
    titulo: 'Encontro de contas',
    celula: kpiEncontroContas,
    contaVerificada: true,
    desbloqueio: 'Entradas e saídas do mês registadas',
  ),
  KpiDefinicao(
    id: 'recomendacao-dia',
    titulo: 'Recomendação do dia',
    celula: kpiRecomendacao,
    contaVerificada: false,
    desbloqueio: 'Depende dos sinais das outras alavancas',
  ),
  // Slide 2 — Operacional
  KpiDefinicao(
    id: 'reservas-activas',
    titulo: 'Reservas activas',
    celula: kpiReservasActivas,
    contaVerificada: true,
    desbloqueio: 'Reservas na agenda (contam já em Pedido)',
  ),
  KpiDefinicao(
    id: 'entregas-hoje',
    titulo: 'Entregas hoje',
    celula: kpiEntregasHoje,
    contaVerificada: true,
    desbloqueio: 'Reserva a começar hoje',
  ),
  KpiDefinicao(
    id: 'recolhas-fazer',
    titulo: 'Recolhas a fazer',
    celula: kpiRecolhas,
    contaVerificada: true,
    desbloqueio: 'Reserva a terminar hoje',
  ),
  KpiDefinicao(
    id: 'cobrancas-7d',
    titulo: 'Cobranças a vencer (7d)',
    celula: kpiCobrancas,
    contaVerificada: true,
    desbloqueio: 'Reservas com valor por liquidar nos próximos 7 dias',
  ),
  // Slide 3 — Procura e vendas
  KpiDefinicao(
    id: 'clientes-novos-30d',
    titulo: 'Clientes novos (30d)',
    celula: kpiClientesNovos,
    contaVerificada: true,
    desbloqueio: 'Primeira reserva de cada cliente',
  ),
  KpiDefinicao(
    id: 'leads-pipeline',
    titulo: 'Leads em pipeline',
    celula: kpiLeadsPipeline,
    contaVerificada: true,
    desbloqueio: 'Leads registadas',
  ),
  KpiDefinicao(
    id: 'ticket-medio-mes',
    titulo: 'Ticket médio (mês)',
    celula: kpiTicketMedio,
    contaVerificada: true,
    desbloqueio: 'Reservas do mês com valor previsto',
  ),
  KpiDefinicao(
    id: 'conversao-lead-cliente',
    titulo: 'Conversão lead → cliente',
    celula: kpiConversao,
    contaVerificada: true,
    desbloqueio: 'Leads registadas + reservas que delas saíram',
  ),
  // Saúde da empresa — os sete que `docs/AUDITORIA_KPIS_EMPRESA.md` deu como
  // não cobertos. Nascem todos com a conta por verificar: a fórmula é nossa, o
  // crivo é do César, um a um.
  KpiDefinicao(
    id: 'saldo-e-autonomia',
    titulo: 'Saldo e autonomia',
    celula: kpiSaldoEAutonomia,
    contaVerificada: true,
    desbloqueio: 'Entradas e saídas registadas + custos fixos declarados',
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'margem-bruta',
    titulo: 'Margem bruta',
    celula: kpiMargemBruta,
    contaVerificada: true,
    desbloqueio: 'Recebimentos do mês + despesas com categoria',
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'ciclo-de-tesouraria',
    titulo: 'Ciclo de tesouraria',
    celula: kpiCicloDeTesouraria,
    contaVerificada: true,
    desbloqueio: 'Recebimentos em 90 dias + reservas com valor + despesas',
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'fluxo-de-caixa-livre',
    titulo: 'Fluxo de caixa livre',
    celula: kpiFluxoLivre,
    contaVerificada: true,
    desbloqueio: 'Movimentos do mês + valor de compra e data das máquinas',
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'custo-de-aquisicao',
    titulo: 'Custo de aquisição',
    celula: kpiCustoDeAquisicao,
    contaVerificada: true,
    desbloqueio: 'Despesas de publicidade + primeira reserva de cada cliente',
    destino: AppDestination.finances,
  ),
  KpiDefinicao(
    id: 'receita-recorrente',
    titulo: 'Receita de quem volta',
    celula: kpiReceitaRecorrente,
    contaVerificada: true,
    desbloqueio:
        'Recebimentos do mês + reservas anteriores dos mesmos clientes',
    destino: AppDestination.clients,
  ),
  KpiDefinicao(
    id: 'satisfacao-cliente',
    titulo: 'Satisfação do cliente',
    celula: kpiSatisfacao,
    contaVerificada: false,
    // Não é um dado que falte preencher: é uma pergunta que a app ainda não
    // sabe fazer. Fica dito, em vez de o KPI desaparecer da lista.
    desbloqueio: 'Um inquérito ao cliente no fim da recolha — ainda não existe',
  ),
  // As duas que se perderam quando o painel deixou de ser slides.
  KpiDefinicao(
    id: 'leads-frias',
    titulo: 'Leads a arrefecer',
    celula: kpiLeadsFrias,
    contaVerificada: true,
    desbloqueio: 'Leads registadas há mais de duas semanas',
    destino: AppDestination.clients,
  ),
  KpiDefinicao(
    id: 'alertas-operacionais',
    titulo: 'Alertas operacionais',
    celula: kpiAlertasOperacionais,
    contaVerificada: true,
    desbloqueio: 'Reservas na agenda',
    destino: AppDestination.semana,
  ),
  // Futurologia — o mês por fechar.
  KpiDefinicao(
    id: 'gastos-previstos-mes',
    titulo: 'Gastos previstos do mês',
    celula: kpiGastosPrevistos,
    contaVerificada: true,
    desbloqueio: 'Custos fixos declarados em Empresa › Custos fixos',
    destino: AppDestination.empresa,
  ),
  KpiDefinicao(
    id: 'saldo-previsto-mes',
    titulo: 'Saldo previsto do mês',
    celula: kpiSaldoPrevisto,
    contaVerificada: true,
    desbloqueio: 'Custos fixos declarados + reservas na agenda',
    destino: AppDestination.finances,
  ),
];

/// A entrada do catálogo com este id, ou `null` se não existir.
KpiDefinicao? kpiPorId(String id) {
  for (final k in catalogoKpis) {
    if (k.id == id) return k;
  }
  return null;
}

/// Os KPIs que o painel mostra, já pela ordem do gestor.
///
/// Um id gravado que esta versão da app já não conhece desaparece daqui sem
/// fazer barulho — um painel arrumado numa app mais nova não pode prender o
/// gestor fora do painel numa mais velha, que é a que ele tem à mão quando
/// ainda não actualizou.
List<KpiDefinicao> kpisEscolhidos(ArranjoDoPainel arranjo) => [
  for (final id in arranjo.noPainel)
    if (kpiPorId(id) case final kpi?) kpi,
];

// ---------------------------------------------------------------------------
// Fora do carrossel — Caixa e Tendência do mês (nascem na "KPIs (todos)")
// ---------------------------------------------------------------------------

const _mesesPt = [
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

/// **Caixa** — o que entrou menos o que saiu, do dia 1 até hoje. A cor e a frase
/// saem da mesma regra de apreciação (o costume da própria empresa).
CelulaSemaforo kpiCaixa(OperationsState estado, DateTime now) {
  final caixa = caixaDoMes(estado, now);
  final saldo = caixa.saldoCents;
  final positivo = saldo >= 0;
  final periodo = '1 a ${caixa.ate.day} de ${_mesesPt[caixa.mes.month - 1]}';
  if (caixa.semMovimentos) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Caixa · $periodo',
      texto: 'Sem movimentos este mês',
      subtexto: 'Regista uma entrada ou uma saída e o número aparece.',
    );
  }
  final apreciacao = apreciar(
    valor: saldo,
    referencia: mediaDosMesesAnteriores(estado, now),
    nomeDaReferencia: 'a tua média',
    formatar: (cents) => euros(cents.round()),
    semTermo:
        'É o teu primeiro mês com registos — ainda não há com que comparar.',
  );
  return CelulaSemaforo(
    nivel: !positivo
        ? NivelSemaforo.vermelho
        : switch (apreciacao.tom) {
            TomDaApreciacao.abaixo => NivelSemaforo.laranja,
            TomDaApreciacao.semTermo => NivelSemaforo.aguarda,
            _ => NivelSemaforo.verde,
          },
    rotulo: 'Caixa · $periodo',
    valor: '${positivo ? '+' : '−'} ${euros(saldo.abs())}',
    valorEmDestaque: true,
    subtexto: apreciacao.frase,
  );
}

/// **Tendência do mês** — a futurologia do crescimento, sempre face ao mês
/// passado (momentum mês-a-mês, não o homólogo sazonal). O número grande é o
/// **previsto**: o que já entrou mais o que as reservas na agenda vão trazer.
CelulaSemaforo kpiTendencia(OperationsState estado, DateTime now) {
  final mes = tesourariaDoMes(estado, now);
  final variacao = mes.variacaoVsMesAnterior;
  if (mes.entradasPrevistasCents == 0 && variacao == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Tendência do mês',
      texto: 'Sem entradas nem histórico',
      subtexto:
          'Regista um recebimento ou uma reserva, ou deixa o '
          'contabilista responder o passado — e a tendência aparece.',
    );
  }
  final tendencia = variacao == null
      ? 'Sem mês passado para comparar'
      : '${variacao >= 0 ? '▲' : '▼'} '
            '${variacao.abs().round()}% previsto face ao mês passado';
  return CelulaSemaforo(
    nivel: variacao != null && variacao < 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Tendência do mês',
    valor: _euros(mes.entradasPrevistasCents),
    unidade: '€ previsto este mês',
    subtexto: tendencia,
    valorEmDestaque: true,
  );
}

// ---------------------------------------------------------------------------
// Slide 1 — Síntese
// ---------------------------------------------------------------------------

/// Dinheiro que entrou **no mês**, com o dia na sub-linha.
CelulaSemaforo kpiEntradas(OperationsState estado, DateTime now) {
  final mes = tesourariaDoMes(estado, now);
  final recebidoHoje = receiptTotal(estado.receipts, _dia(now), _dia(now));
  if (mes.recebidoCents == 0 && mes.comparacao == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Dinheiros que entraram',
      texto: 'Regista um recebimento',
      subtexto: 'Toca para abrir Finanças',
    );
  }
  // Homólogo quando há histórico, mês passado só como recurso — e o texto diz
  // sempre contra o quê, senão a percentagem não se sabe ler.
  final comparacao = mes.comparacao;
  final tendencia = comparacao == null
      ? 'Sem histórico para comparar'
      : '${comparacao.variacao >= 0 ? '▲' : '▼'} '
            '${comparacao.variacao.abs().round()}% previsto vs '
            '${comparacao.homologo ? 'mesmo mês do ano passado' : 'mês passado'}';
  return CelulaSemaforo(
    nivel: comparacao != null && comparacao.variacao < 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Dinheiros que entraram',
    valor: _euros(mes.recebidoCents),
    unidade: '€ este mês',
    subtexto: recebidoHoje > 0
        ? 'Hoje: ${_euros(recebidoHoje)} € · $tendencia'
        : tendencia,
    valorEmDestaque: true,
  );
}

/// Ocupação e retorno das máquinas. Diz o que falta enquanto as máquinas não
/// tiverem preço/dia e valor de compra.
CelulaSemaforo kpiUtilizacao(OperationsState estado, DateTime now) {
  final total = estado.machines.where((m) => !m.archived).length;
  if (total == 0) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Utilização vs Rentabilidade',
      texto: 'Identifica as máquinas',
      subtexto: 'Sem elas não há ocupação',
    );
  }
  final comPreco = estado.machines
      .where((m) => !m.archived && m.dailyRateCents != null)
      .length;
  if (comPreco < total) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Utilização vs Rentabilidade',
      texto: comPreco == 0
          ? 'Falta o preço por dia das $total máquinas'
          : 'Falta o preço de ${total - comPreco} de $total máquinas',
      subtexto: 'Com ele, os dias dão euros',
    );
  }
  final dados = utilizacaoERentabilidade(estado, now);
  if (dados.maquinasComValorDeCompra == 0) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Utilização vs Rentabilidade',
      texto: 'Falta o valor de compra',
      subtexto: 'É o que mede o retorno',
    );
  }
  final ocupacao = dados.ocupacaoPercent;
  final recuperado = dados.percentInvestimentoRecuperado;
  return CelulaSemaforo(
    nivel: (ocupacao ?? 0) >= 60
        ? NivelSemaforo.verde
        : (ocupacao ?? 0) >= 30
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Utilização vs Rentabilidade',
    valor: ocupacao == null ? '—' : '${ocupacao.round()}',
    unidade: '% ocupação',
    subtexto: recuperado == null
        ? 'Sem receita registada ainda para medir o retorno'
        : dados.maquinasComValorDeCompra < total
        ? '${recuperado.round()}% do investido recuperado '
              '(${dados.maquinasComValorDeCompra} de $total máquinas)'
        : '${recuperado.round()}% do investido recuperado',
  );
}

/// O saldo do mês: entradas menos saídas.
CelulaSemaforo kpiEncontroContas(OperationsState estado, DateTime now) {
  final mes = tesourariaDoMes(estado, now);
  if (mes.semMovimentos) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Encontro de contas',
      texto: 'Sem movimentos este mês',
      subtexto: 'Regista entradas e saídas',
    );
  }
  final saldo = mes.recebidoCents - mes.saidasCents;
  return CelulaSemaforo(
    nivel: saldo >= 0 ? NivelSemaforo.verde : NivelSemaforo.vermelho,
    rotulo: 'Encontro de contas',
    valor: '${saldo >= 0 ? '+ ' : '− '}${_euros(saldo.abs())}',
    unidade: '€ saldo',
    subtexto:
        'Entradas ${_euros(mes.recebidoCents)} · '
        'Saídas ${_euros(mes.saidasCents)}',
    valorEmDestaque: true,
  );
}

/// A recomendação do dia — não é métrica, é o conselho que os sinais pedem.
CelulaSemaforo kpiRecomendacao(OperationsState estado, DateTime now) {
  final recomendacao = recomendacaoDaSemana(estado, now);
  if (recomendacao == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.verde,
      rotulo: 'Recomendação do dia',
      texto: 'Nada a assinalar',
      subtexto: 'Sem sinais que peçam acção hoje',
    );
  }
  return CelulaSemaforo(
    nivel: switch (recomendacao.gravidade) {
      GravidadeRecomendacao.oportunidade => NivelSemaforo.verde,
      GravidadeRecomendacao.atencao => NivelSemaforo.laranja,
      GravidadeRecomendacao.urgente => NivelSemaforo.vermelho,
    },
    rotulo: 'Recomendação do dia',
    texto: recomendacao.title,
    subtexto: recomendacao.action,
  );
}

// ---------------------------------------------------------------------------
// Slide 2 — Operacional (todas do pulso do dia)
// ---------------------------------------------------------------------------

/// A célula que se mostra enquanto não há reservas nenhumas: o que ocupa o lugar
/// do número é **o que falta fazer**, nunca um "0" que seria informação que não
/// temos.
CelulaSemaforo _aguarda(String rotulo, String falta, String contexto) =>
    CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: rotulo,
      texto: falta,
      subtexto: contexto,
    );

CelulaSemaforo kpiReservasActivas(OperationsState estado, DateTime now) {
  final p = pulsoOperacional(estado, now);
  if (p.semDados) {
    return _aguarda(
      'Reservas activas',
      'Marca a primeira reserva',
      'Põe o pulso do dia a bater',
    );
  }
  return CelulaSemaforo(
    nivel: p.reservasActivas == 0 ? NivelSemaforo.laranja : NivelSemaforo.verde,
    rotulo: 'Reservas activas',
    valor: '${p.reservasActivas}',
    unidade: 'em curso',
    subtexto: p.reservasATerminar48h == 0
        ? 'Nenhuma termina nas próximas 48h'
        : '${p.reservasATerminar48h} terminam em 48h',
  );
}

CelulaSemaforo kpiEntregasHoje(OperationsState estado, DateTime now) {
  final p = pulsoOperacional(estado, now);
  if (p.semDados) {
    return _aguarda(
      'Entregas hoje',
      'Nada para entregar',
      'Vem das reservas marcadas',
    );
  }
  return CelulaSemaforo(
    nivel: p.entregasPorFazer > 0 ? NivelSemaforo.laranja : NivelSemaforo.verde,
    rotulo: 'Entregas hoje',
    valor: '${p.entregasHoje}',
    unidade: p.entregasHoje == 1 ? 'entrega' : 'entregas',
    subtexto: p.entregasHoje == 0
        ? 'Nada para entregar hoje'
        : p.entregasPorFazer == 0
        ? 'Todas já saíram'
        : '${p.entregasPorFazer} por fazer',
  );
}

CelulaSemaforo kpiRecolhas(OperationsState estado, DateTime now) {
  final p = pulsoOperacional(estado, now);
  if (p.semDados) {
    return _aguarda(
      'Recolhas a fazer',
      'Nada para recolher',
      'Vem das reservas a terminar',
    );
  }
  final atrasada = p.recolhasEmAtraso > 0;
  final dias = p.diasDaRecolhaMaisAtrasada;
  final antiguidade = dias == null || dias == 0
      ? ''
      : ' — a mais antiga há $dias dia${dias == 1 ? '' : 's'}';
  return CelulaSemaforo(
    nivel: atrasada
        ? NivelSemaforo.vermelho
        : p.recolhasHoje > 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Recolhas a fazer',
    valor: '${p.recolhasHoje}',
    unidade: 'hoje · ${p.recolhasProximas48h} em 48h',
    subtexto: atrasada
        ? '${p.recolhasEmAtraso} em atraso$antiguidade'
        : 'Nenhuma máquina por recuperar',
  );
}

CelulaSemaforo kpiCobrancas(OperationsState estado, DateTime now) {
  final p = pulsoOperacional(estado, now);
  if (p.semDados) {
    return _aguarda(
      'Cobranças a vencer',
      'Nada por cobrar',
      'Vem das reservas por liquidar',
    );
  }
  return CelulaSemaforo(
    nivel: p.venceHojeCents > 0
        ? NivelSemaforo.vermelho
        : p.cobrancasAVencerCents > 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Cobranças a vencer (7d)',
    valor: '${(p.cobrancasAVencerCents / 100).round()}',
    unidade: p.clientesACobrar == 1
        ? '€ · 1 cliente'
        : '€ · ${p.clientesACobrar} clientes',
    subtexto: p.cobrancasAVencerCents == 0
        ? 'Nada por cobrar nos próximos 7 dias'
        : p.venceHojeCents > 0
        ? 'Vence hoje: ${(p.venceHojeCents / 100).round()} €'
        : 'Nada vence hoje',
  );
}

// ---------------------------------------------------------------------------
// Slide 3 — Procura e vendas
// ---------------------------------------------------------------------------

/// Quantos dias para trás ainda contam como "recente" nas leituras de procura.
const _janelaDias = 30;

CelulaSemaforo kpiClientesNovos(OperationsState estado, DateTime now) {
  final novos = clientesNovos(estado, now, dias: _janelaDias);
  if (novos == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Clientes novos (30d)',
      texto: 'Ainda sem clientes',
      subtexto: 'Contam pela primeira reserva',
    );
  }
  return CelulaSemaforo(
    nivel: novos == 0 ? NivelSemaforo.laranja : NivelSemaforo.verde,
    rotulo: 'Clientes novos (30d)',
    valor: '$novos',
    unidade: novos == 1 ? 'cliente' : 'clientes',
    subtexto: 'Contados pela data da primeira reserva',
    valorEmDestaque: novos > 0,
  );
}

CelulaSemaforo kpiLeadsPipeline(OperationsState estado, DateTime now) {
  // **Zero leads não é «zero por contactar».** Sem uma única lead registada a
  // fonte está vazia, e dizer «0 por contactar · nenhuma lead à espera» em
  // verde era dar por respondida uma pergunta que nunca foi feita — e, desde
  // que este KPI passou a pronto, punha uma empresa acabada de abrir com um
  // indicador «a dizer verdade» no painel.
  if (estado.leads.isEmpty) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Leads em pipeline',
      texto: 'Sem leads registadas',
      subtexto: 'Regista quem te procura e o funil acende',
    );
  }
  final porContactar = leadsPorContactar(estado);
  final frias = porContactar
      .where((l) => _dia(now).difference(_dia(l.createdAt)).inDays > 5)
      .length;
  final n = porContactar.length;
  const abertas = {
    LeadStatus.newLead,
    LeadStatus.contacted,
    LeadStatus.proposal,
  };
  final emAberto = estado.leads.where((l) => abertas.contains(l.status)).length;
  return CelulaSemaforo(
    nivel: frias > 0
        ? NivelSemaforo.vermelho
        : n > 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Leads em pipeline',
    valor: '$n',
    unidade: 'por contactar',
    // **O total em aberto vai no subtexto.** O número grande são as que ainda
    // ninguém tocou, e um gestor com dez leads todas contactadas lia «0» com o
    // rótulo «leads em pipeline» — e podia concluir que não tinha pipeline
    // nenhum. O que está em aberto é o funil todo menos o que fechou.
    subtexto: frias > 0
        ? '$frias sem contacto há mais de 5 dias · $emAberto em aberto'
        : n == 0
        ? (emAberto == 0
              ? 'Nenhuma lead à espera'
              : '$emAberto em aberto, todas já contactadas')
        : 'Todas contactadas nos últimos 5 dias · $emAberto em aberto',
  );
}

CelulaSemaforo kpiTicketMedio(OperationsState estado, DateTime now) {
  final ticket = ticketMedioDoMes(estado, now);
  if (ticket == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Ticket médio (mês)',
      texto: 'Sem reservas com valor',
      subtexto: 'Põe valor nas reservas',
    );
  }
  // O número grande é quanto cada empresa vale em média este mês; o subtexto
  // leva a recorrência — quantas vezes, em média, cada cliente volta a comprar
  // no mês — e sobre quantas empresas a média se faz.
  final nEmpresas = ticket.empresas == 1
      ? '1 empresa'
      : '${ticket.empresas} empresas';
  final recorrencia = _recorrencia(ticket.transacoesMediasPorEmpresa);
  return CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Ticket médio (mês)',
    valor: '${(ticket.porEmpresaCents / 100).round()}',
    unidade: '€',
    subtexto: 'Recorrência $recorrencia×/mês · $nEmpresas',
    valorEmDestaque: true,
  );
}

CelulaSemaforo kpiConversao(OperationsState estado, DateTime now) {
  final funil = funilProcura(estado, now, _janelaDias);
  final taxa = funil.taxa;
  if (taxa == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Conversão lead → cliente',
      texto: 'Sem leads em 30 dias',
      subtexto: 'Regista quem te procura',
    );
  }
  final anterior = funil.taxaPeriodoAnterior;
  final delta = anterior == null ? null : taxa - anterior;
  return CelulaSemaforo(
    nivel: taxa >= 40
        ? NivelSemaforo.verde
        : taxa >= 20
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Conversão lead → cliente',
    valor: '${taxa.round()}',
    unidade: '% · ${funil.convertidas} de ${funil.leads}',
    subtexto: delta == null
        ? 'Sem período anterior para comparar'
        : '${delta >= 0 ? '▲' : '▼'} ${delta.abs().round()}pp '
              'vs 30 dias anteriores',
  );
}

// ---------------------------------------------------------------------------
// Formatação partilhada
// ---------------------------------------------------------------------------

DateTime _dia(DateTime data) => DateTime(data.year, data.month, data.day);

/// Sem casas decimais: o painel é para ler em cinco segundos, e os cêntimos
/// roubam espaço ao que interessa.
String _euros(int cents) => (cents / 100).round().toString();

/// A recorrência sem casas a mais: inteiro quando é redondo (4), uma casa e
/// vírgula quando não (3,5).
String _recorrencia(double v) {
  final arred = (v * 10).round() / 10;
  return arred == arred.roundToDouble()
      ? arred.round().toString()
      : arred.toStringAsFixed(1).replaceAll('.', ',');
}

// ---------------------------------------------------------------------------
// Saúde da empresa — o que a auditoria apontou como em falta
// ---------------------------------------------------------------------------

/// **Saldo e autonomia** — quanto há, e para quantas semanas dá.
///
/// O número grande são as semanas e não os euros, de propósito: o saldo sozinho
/// não diz nada sem se saber o que se queima. É a pergunta que a auditoria pôs
/// em primeiro lugar dos quinze.
CelulaSemaforo kpiSaldoEAutonomia(OperationsState estado, DateTime now) {
  final saude = saldoEAutonomia(estado, now);
  if (saude == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Saldo e autonomia',
      texto: 'Regista entradas e saídas',
      subtexto: 'Sem movimentos não há saldo para contar',
    );
  }
  final desde =
      '${saude.desdeQuando.day}/${saude.desdeQuando.month}/'
      '${saude.desdeQuando.year}';
  final semanas = saude.semanas;
  if (semanas == null) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Saldo e autonomia',
      valor: _euros(saude.saldoCents),
      unidade: '€ em caixa',
      subtexto:
          'Falta o que se gasta por mês para dizer para quanto dá · '
          'aproximado, conta desde $desde',
    );
  }
  return CelulaSemaforo(
    nivel: semanas < 6
        ? NivelSemaforo.vermelho
        : semanas < 12
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Saldo e autonomia',
    valor: _recorrencia(semanas),
    unidade: 'semanas de autonomia',
    valorEmDestaque: true,
    subtexto:
        '${_euros(saude.saldoCents)} € a queimar '
        '${_euros(saude.queimaSemanalCents)} €/semana · '
        'aproximado, conta desde $desde',
  );
}

/// **Margem bruta** — o que sobra depois de pagar o que custou servir.
CelulaSemaforo kpiMargemBruta(OperationsState estado, DateTime now) {
  final margem = margemBruta(estado, now);
  if (margem == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Margem bruta',
      texto: 'Sem receita este mês',
      subtexto: 'Regista os recebimentos e a margem aparece',
    );
  }
  final variacao = margem.variacao;
  return CelulaSemaforo(
    nivel: margem.percent >= 60
        ? NivelSemaforo.verde
        : margem.percent >= 35
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Margem bruta',
    valor: margem.percent.round().toString(),
    unidade: '% este mês',
    valorEmDestaque: true,
    subtexto: variacao == null
        ? '${_euros(margem.custosDirectosCents)} € de custos directos · '
              'sem mês passado para comparar'
        : '${variacao >= 0 ? '▲' : '▼'} ${variacao.abs().round()} pontos face '
              'ao mês passado · ${_euros(margem.custosDirectosCents)} € de '
              'custos directos',
  );
}

/// **Ciclo de tesouraria** — quantos dias o dinheiro passa fora do bolso.
CelulaSemaforo kpiCicloDeTesouraria(OperationsState estado, DateTime now) {
  final ciclo = cicloDeTesouraria(estado, now);
  if (ciclo == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Ciclo de tesouraria',
      texto: 'Sem receita nos últimos 90 dias',
      subtexto: 'Sem facturação não há ciclo a medir',
    );
  }
  return CelulaSemaforo(
    nivel: ciclo.dias <= 30
        ? NivelSemaforo.verde
        : ciclo.dias <= 60
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Ciclo de tesouraria',
    valor: ciclo.dias.round().toString(),
    unidade: 'dias',
    valorEmDestaque: true,
    subtexto:
        '${ciclo.diasACobrar.round()} a cobrar + '
        '${ciclo.diasParada.round()} de máquina parada − '
        '${ciclo.diasAPagar.round()} a pagar',
  );
}

/// **Fluxo de caixa livre** — o que sobra depois de repor máquina.
CelulaSemaforo kpiFluxoLivre(OperationsState estado, DateTime now) {
  final fluxo = fluxoDeCaixaLivre(estado, now);
  if (fluxo == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Fluxo de caixa livre',
      texto: 'Sem movimentos este mês',
      subtexto: 'Regista entradas e saídas',
    );
  }
  final livre = fluxo.livreCents;
  return CelulaSemaforo(
    nivel: livre >= 0 ? NivelSemaforo.verde : NivelSemaforo.vermelho,
    rotulo: 'Fluxo de caixa livre',
    valor: '${livre >= 0 ? '+ ' : '− '}${_euros(livre.abs())}',
    unidade: '€ este mês',
    valorEmDestaque: true,
    subtexto: fluxo.maquinasCompradas == 0
        ? 'Sem compras de máquina este mês'
        : '${_euros(fluxo.operacionalCents)} € de operação − '
              '${_euros(fluxo.investimentoCents)} € em '
              '${fluxo.maquinasCompradas} '
              '${fluxo.maquinasCompradas == 1 ? 'máquina' : 'máquinas'}',
  );
}

/// **Custo de aquisição** — quanto custou, em publicidade, cada cliente novo.
CelulaSemaforo kpiCustoDeAquisicao(OperationsState estado, DateTime now) {
  final cac = custoDeAquisicao(estado, now);
  if (cac == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Custo de aquisição',
      texto: 'Sem despesas de publicidade em 90 dias',
      subtexto: 'Regista-as e vê-se quanto custa cada cliente novo',
    );
  }
  if (cac.semComoContar) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Custo de aquisição',
      texto: 'Sem reservas para saber quem é novo',
      subtexto: 'O cliente conta-se pela primeira reserva',
    );
  }
  final porCliente = cac.porClienteCents;
  if (porCliente == null) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.vermelho,
      rotulo: 'Custo de aquisição',
      valor: _euros(cac.investidoCents),
      unidade: '€ sem cliente novo',
      valorEmDestaque: true,
      subtexto: 'Investiu-se em ${cac.janelaDias} dias e não entrou ninguém',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Custo de aquisição',
    valor: _euros(porCliente),
    unidade: '€ por cliente novo',
    subtexto:
        '${_euros(cac.investidoCents)} € em publicidade · '
        '${cac.clientesNovos} '
        '${cac.clientesNovos == 1 ? 'cliente' : 'clientes'} em '
        '${cac.janelaDias} dias · só publicidade, é um piso',
  );
}

/// **Receita de quem volta** — a fatia do mês que veio de clientes antigos.
CelulaSemaforo kpiReceitaRecorrente(OperationsState estado, DateTime now) {
  final recorrente = receitaRecorrente(estado, now);
  if (recorrente == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Receita de quem volta',
      texto: 'Sem recebimentos este mês',
      subtexto: 'Regista-os e vê-se quem está a voltar',
    );
  }
  return CelulaSemaforo(
    nivel: recorrente.percent >= 50
        ? NivelSemaforo.verde
        : recorrente.percent >= 25
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Receita de quem volta',
    valor: recorrente.percent.round().toString(),
    unidade: '% este mês',
    valorEmDestaque: true,
    subtexto:
        '${recorrente.clientesRecorrentes} de ${recorrente.clientesDoMes} '
        'clientes já cá tinham estado',
  );
}

/// **Satisfação do cliente** — e não há como a medir.
///
/// Fica no catálogo de propósito, em «Por definir». A auditoria pô-la nos
/// quinze essenciais e a app não tem por onde perguntar ao cliente: escondê-la
/// era fingir que a lista está completa. O que aparece aqui é a falta, com o
/// nome dela.
CelulaSemaforo kpiSatisfacao(OperationsState estado, DateTime now) =>
    const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Satisfação do cliente',
      texto: 'Ainda não há como perguntar',
      subtexto: 'Falta o inquérito no fim da recolha',
    );

// ---------------------------------------------------------------------------
// As duas que se perderam quando o painel deixou de ser slides
// ---------------------------------------------------------------------------

/// **Leads a arrefecer** — o card de recomendação lateral do slide de Procura.
///
/// «Leads em pipeline» conta-as todas como se estivessem vivas. Esta conta as
/// que estão paradas há mais de duas semanas, que é outra coisa.
CelulaSemaforo kpiLeadsFrias(OperationsState estado, DateTime now) {
  final frias = leadsFrias(estado, now);
  if (estado.leads.isEmpty) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Leads a arrefecer',
      texto: 'Sem leads registadas',
      subtexto: 'Regista quem pediu orçamento e não fechou',
    );
  }
  if (frias.frias == 0) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.verde,
      rotulo: 'Leads a arrefecer',
      valor: '0',
      unidade: 'paradas',
      subtexto: 'Nenhuma parada há mais de ${frias.limiteDias} dias',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.laranja,
    rotulo: 'Leads a arrefecer',
    valor: '${frias.frias}',
    unidade: frias.frias == 1 ? 'parada' : 'paradas',
    valorEmDestaque: true,
    // «Registada há», e não «parada há»: a lead não guarda quando foi tocada
    // pela última vez, guarda quando entrou. Dizer «parada há 40 dias» era
    // afirmar uma coisa que os dados não sabem.
    subtexto:
        'A mais antiga registada há ${frias.diasDaMaisAntiga} dias e ainda em '
        'aberto · liga antes que esfrie de vez',
  );
}

/// **Alertas operacionais** — a faixa que o slide Operacional tinha em baixo.
///
/// Não é um número: é o que exige acção hoje, pela ordem em que dói. O
/// [PulsoOperacional] já sabia dizê-lo e ninguém lho perguntava desde que os
/// slides desapareceram.
CelulaSemaforo kpiAlertasOperacionais(OperationsState estado, DateTime now) {
  final pulso = pulsoOperacional(estado, now);
  if (pulso.semDados) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Alertas operacionais',
      texto: 'Sem reservas registadas',
      subtexto: 'Não há operação para vigiar',
    );
  }
  final alertas = pulso.alertas;
  if (alertas == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.verde,
      rotulo: 'Alertas operacionais',
      texto: 'Nada por fazer em atraso',
      subtexto: 'Entregas, recolhas e cobranças em dia',
    );
  }
  return CelulaSemaforo(
    nivel: pulso.recolhasEmAtraso > 0
        ? NivelSemaforo.vermelho
        : NivelSemaforo.laranja,
    rotulo: 'Alertas operacionais',
    texto: alertas,
  );
}

// ---------------------------------------------------------------------------
// Futurologia — como o mês vai fechar se a tendência se mantiver
// ---------------------------------------------------------------------------

/// **Gastos previstos do mês** — os custos fixos mais o que já se lançou.
CelulaSemaforo kpiGastosPrevistos(OperationsState estado, DateTime now) {
  final previsao = previsaoDoMes(estado, now);
  final saidas = previsao.saidasPrevistasCents;
  if (saidas == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gastos previstos do mês',
      texto: 'Faltam os custos fixos',
      subtexto: 'Empresa › Custos fixos — sem eles a previsão fica curta',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.laranja,
    rotulo: 'Gastos previstos do mês',
    valor: _euros(saidas),
    unidade: '€ até ao fim do mês',
    // O que a conta faz mesmo: os custos fixos declarados mais a **média** das
    // despesas variáveis dos meses de referência que têm registo. Dizia «mais
    // o que já foi lançado», que é outra conta e não é esta.
    subtexto:
        'Custos fixos declarados mais a média das despesas variáveis dos '
        'meses com registo',
  );
}

/// **Saldo previsto do mês** — como o mês fecha se a tendência se mantiver.
///
/// É a semente do ecrã de futurologia: entradas previstas menos gastos
/// previstos, antes de o mês acabar.
CelulaSemaforo kpiSaldoPrevisto(OperationsState estado, DateTime now) {
  final previsao = previsaoDoMes(estado, now);
  final saldo = previsao.saldoPrevistoCents;
  if (saldo == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Saldo previsto do mês',
      texto: 'Faltam os custos fixos',
      subtexto: 'Sem eles não se prevê como o mês fecha',
    );
  }
  return CelulaSemaforo(
    nivel: saldo >= 0 ? NivelSemaforo.verde : NivelSemaforo.vermelho,
    rotulo: 'Saldo previsto do mês',
    valor: '${saldo >= 0 ? '+ ' : '− '}${_euros(saldo.abs())}',
    unidade: '€ ao fechar',
    valorEmDestaque: true,
    subtexto:
        '${_euros(previsao.entradasPrevistasCents)} € previstos a entrar − '
        '${_euros(previsao.saidasPrevistasCents!)} € a sair',
  );
}
