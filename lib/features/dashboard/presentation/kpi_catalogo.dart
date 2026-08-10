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
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/arranjo_do_painel.dart';
import '../../../domain/models/finance.dart';
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
    contaVerificada: false,
    desbloqueio: 'Primeira reserva de cada cliente',
  ),
  KpiDefinicao(
    id: 'leads-pipeline',
    titulo: 'Leads em pipeline',
    celula: kpiLeadsPipeline,
    contaVerificada: false,
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
    contaVerificada: false,
    desbloqueio: 'Leads registadas + reservas que delas saíram',
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
  final porContactar = leadsPorContactar(estado);
  final frias = porContactar
      .where((l) => _dia(now).difference(_dia(l.createdAt)).inDays > 5)
      .length;
  final n = porContactar.length;
  return CelulaSemaforo(
    nivel: frias > 0
        ? NivelSemaforo.vermelho
        : n > 0
        ? NivelSemaforo.laranja
        : NivelSemaforo.verde,
    rotulo: 'Leads em pipeline',
    valor: '$n',
    unidade: 'por contactar',
    subtexto: frias > 0
        ? '$frias sem contacto há mais de 5 dias'
        : n == 0
        ? 'Nenhuma lead à espera'
        : 'Todas contactadas nos últimos 5 dias',
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
