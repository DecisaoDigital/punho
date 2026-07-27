import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../../domain/models/workforce.dart';
import '../finance/regime_fiscal.dart';
import '../finance/retencao_irs.dart';
import '../guidance/guidance_engine.dart';
import 'operations_controller.dart';

/// Leituras derivadas do estado operacional — o que os slides do painel mostram.
///
/// São funções puras sobre [OperationsState] e não métodos do controller, por
/// duas razões: testam-se sem montar um `ProviderContainer`, e recebem o `now`
/// de fora, portanto o resultado não muda com o dia em que os testes correm.
/// Seguem o mesmo padrão de `availableMachines` e `stoppedMachines`, que já
/// viviam assim.
///
/// Regra que atravessa o ficheiro: **zero por falta de dados devolve `null`**,
/// nunca `0`. Um `0` no ecrã diz "não facturaste", e isso é mentira nos
/// primeiros dias do mês ou numa empresa que ainda não registou nada. Quem
/// desenha decide o que fazer com o `null` ("Por apurar").

DateTime _inicioDoMes(DateTime data) => DateTime(data.year, data.month);
DateTime _fimDoMes(DateTime data) =>
    DateTime(data.year, data.month + 1).subtract(const Duration(days: 1));
DateTime _dia(DateTime data) => DateTime(data.year, data.month, data.day);

/// Segunda-feira da semana de [data].
DateTime inicioDaSemana(DateTime data) =>
    _dia(data).subtract(Duration(days: data.weekday - 1));

// ---------------------------------------------------------------------------
// Slide 1 — dinheiro do mês
// ---------------------------------------------------------------------------

/// Recebido e pago de um mês qualquer, com o mês anterior para a tendência.
class TesourariaMes {
  const TesourariaMes({
    required this.mes,
    required this.recebidoCents,
    required this.pagoCents,
    required this.recebidoMesAnteriorCents,
    required this.serieDiariaCents,
  });

  final DateTime mes;
  final int recebidoCents, pagoCents, recebidoMesAnteriorCents;

  /// Um valor por dia do mês, para a sparkline. Índice 0 = dia 1.
  final List<int> serieDiariaCents;

  /// Variação percentual face ao mês anterior. `null` quando o mês anterior foi
  /// zero — dividir por zero não dá "infinito por cento", dá desconhecido.
  double? get variacaoVsMesAnterior => recebidoMesAnteriorCents == 0
      ? null
      : (recebidoCents - recebidoMesAnteriorCents) /
            recebidoMesAnteriorCents *
            100;

  bool get semMovimentos => recebidoCents == 0 && pagoCents == 0;
}

TesourariaMes tesourariaDoMes(OperationsState state, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  final anterior = DateTime(mes.year, mes.month - 1);
  final diasNoMes = fim.day;
  return TesourariaMes(
    mes: inicio,
    recebidoCents: receiptTotal(state.receipts, inicio, fim),
    pagoCents: paidExpenseTotal(state.expenses, inicio, fim),
    recebidoMesAnteriorCents: receiptTotal(
      state.receipts,
      _inicioDoMes(anterior),
      _fimDoMes(anterior),
    ),
    serieDiariaCents: [
      for (var dia = 1; dia <= diasNoMes; dia++)
        receiptTotal(
          state.receipts,
          DateTime(inicio.year, inicio.month, dia),
          DateTime(inicio.year, inicio.month, dia),
        ),
    ],
  );
}

/// Resultado do mês, sem prometer lucro.
///
/// Devolve `null` quando não há movimentos nenhuns: "recebido − pago" com os
/// dois a zero dá zero, e zero lê-se como "estou em equilíbrio" quando a
/// verdade é "ainda não há dados". As despesas por pagar ficam de fora de
/// propósito — quem desenha tem de dizer isso ao lado do número.
int? resultadoMesConservador(OperationsState state, DateTime now) {
  final mes = tesourariaDoMes(state, now);
  if (mes.semMovimentos) return null;
  return simpleOperatingResult(mes.recebidoCents, mes.pagoCents);
}

/// Reserva com dinheiro em atraso.
class CobrancaEmAtraso {
  const CobrancaEmAtraso({
    required this.booking,
    required this.clienteNome,
    required this.emDividaCents,
    required this.diasDeAtraso,
  });
  final Booking booking;
  final String clienteNome;
  final int emDividaCents;
  final int diasDeAtraso;
}

/// Por receber: reservas cujo valor previsto ainda não entrou todo.
///
/// O atraso conta-se do **fim** da reserva: antes disso o cliente ainda está
/// com a máquina e o dinheiro não está atrasado, está a decorrer.
List<CobrancaEmAtraso> cobrancasPorReceber(
  OperationsState state,
  DateTime now, {
  int minimoDiasAtraso = 0,
}) {
  final resultado = <CobrancaEmAtraso>[];
  for (final booking in state.bookings) {
    if (booking.status == BookingStatus.cancelled) continue;
    final divida = bookingPendingCents(
      booking.expectedValueCents ?? 0,
      booking.id,
      state.receipts,
    );
    if (divida <= 0) continue;
    // Reserva que ainda não terminou não tem atraso nenhum — tem zero. Conta
    // para o "por receber" (é dinheiro esperado) e nunca para o "em atraso".
    final decorridos = _dia(now).difference(_dia(booking.endsAt)).inDays;
    final dias = decorridos < 0 ? 0 : decorridos;
    if (dias < minimoDiasAtraso) continue;
    resultado.add(
      CobrancaEmAtraso(
        booking: booking,
        clienteNome: nomeDoCliente(state, booking),
        emDividaCents: divida,
        diasDeAtraso: dias,
      ),
    );
  }
  resultado.sort((a, b) => b.diasDeAtraso.compareTo(a.diasDeAtraso));
  return resultado;
}

String nomeDoCliente(OperationsState state, Booking booking) {
  if (booking.customerNameSnapshot.trim().isNotEmpty) {
    return booking.customerNameSnapshot.trim();
  }
  for (final cliente in state.customers) {
    if (cliente.id == booking.customerId) return cliente.name;
  }
  return 'Cliente';
}

// ---------------------------------------------------------------------------
// Slide 2 — pipeline
// ---------------------------------------------------------------------------

class FunilProcura {
  const FunilProcura({
    required this.leads,
    required this.contactadas,
    required this.convertidas,
    required this.leadsPeriodoAnterior,
    required this.convertidasPeriodoAnterior,
  });

  final int leads, contactadas, convertidas;
  final int leadsPeriodoAnterior, convertidasPeriodoAnterior;

  /// `null` sem leads no período: 0% diria "não converto nada", quando o que se
  /// passa é que não houve procura para converter.
  double? get taxa => leads == 0 ? null : convertidas / leads * 100;

  double? get taxaPeriodoAnterior => leadsPeriodoAnterior == 0
      ? null
      : convertidasPeriodoAnterior / leadsPeriodoAnterior * 100;
}

FunilProcura funilProcura(OperationsState state, DateTime now, int dias) {
  final desde = _dia(now).subtract(Duration(days: dias));
  final anteriorDesde = desde.subtract(Duration(days: dias));
  bool noPeriodo(Lead lead, DateTime de, DateTime a) =>
      !lead.createdAt.isBefore(de) && lead.createdAt.isBefore(a);
  final doPeriodo = state.leads
      .where((lead) => noPeriodo(lead, desde, _dia(now).add(const Duration(days: 1))))
      .toList();
  final anteriores = state.leads
      .where((lead) => noPeriodo(lead, anteriorDesde, desde))
      .toList();
  const jaTocadas = {
    LeadStatus.contacted,
    LeadStatus.proposal,
    LeadStatus.converted,
    LeadStatus.lost,
  };
  return FunilProcura(
    leads: doPeriodo.length,
    contactadas: doPeriodo.where((l) => jaTocadas.contains(l.status)).length,
    convertidas: doPeriodo
        .where((l) => l.status == LeadStatus.converted)
        .length,
    leadsPeriodoAnterior: anteriores.length,
    convertidasPeriodoAnterior: anteriores
        .where((l) => l.status == LeadStatus.converted)
        .length,
  );
}

/// Leads que ninguém tocou, da mais antiga para a mais recente.
List<Lead> leadsPorContactar(OperationsState state) {
  final lista = state.leads
      .where((lead) => lead.status == LeadStatus.newLead)
      .toList();
  lista.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return lista;
}

class CompromissosProximos {
  const CompromissosProximos({
    required this.reservas,
    required this.valorPrevistoCents,
    required this.porDia,
  });
  final List<Booking> reservas;
  final int valorPrevistoCents;

  /// Quantas reservas começam em cada dia da janela. Índice 0 = hoje.
  final List<int> porDia;
}

CompromissosProximos compromissosProximos(
  OperationsState state,
  DateTime now, {
  int dias = 14,
}) {
  final hoje = _dia(now);
  final limite = hoje.add(Duration(days: dias));
  final reservas =
      state.bookings
          .where(
            (b) =>
                (b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.rented) &&
                !b.startsAt.isBefore(hoje) &&
                b.startsAt.isBefore(limite),
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return CompromissosProximos(
    reservas: reservas,
    valorPrevistoCents: reservas.fold(
      0,
      (soma, b) => soma + (b.expectedValueCents ?? 0),
    ),
    porDia: [
      for (var i = 0; i < dias; i++)
        reservas
            .where((b) => _dia(b.startsAt) == hoje.add(Duration(days: i)))
            .length,
    ],
  );
}

/// Próximas reservas, para a lista curta do slide da semana.
List<Booking> proximasReservas(OperationsState state, DateTime now, int n) =>
    compromissosProximos(state, now, dias: 60).reservas.take(n).toList();

// ---------------------------------------------------------------------------
// Slide 3 — rentabilidade das máquinas
// ---------------------------------------------------------------------------

class OcupacaoSemana {
  const OcupacaoSemana({
    required this.percent,
    required this.percentSemanaAnterior,
    required this.alugadas,
    required this.emManutencao,
    required this.disponiveis,
  });

  /// `null` quando não há máquinas identificadas — sem denominador não há
  /// percentagem, e 0% diria que está tudo parado.
  final double? percent;
  final double? percentSemanaAnterior;
  /// `emManutencao` e não `paradas`: o estado "Parada" saiu da app na v0.0.5 —
  /// uma máquina que não está alugada nem em manutenção está disponível.
  final int alugadas, emManutencao, disponiveis;

  double? get tendenciaVsAnterior =>
      percent == null || percentSemanaAnterior == null
      ? null
      : percent! - percentSemanaAnterior!;
}

/// Ocupação das **máquinas** (as que se alugam), não da frota de veículos.
///
/// Conta dias-máquina ocupados sobre dias-máquina possíveis na semana. Uma
/// máquina reservada 3 dos 7 dias conta 3/7.
OcupacaoSemana ocupacaoMaquinasSemana(OperationsState state, DateTime now) {
  final maquinas = state.machines.where((m) => !m.archived).toList();
  double? percentDaSemanaDe(DateTime segunda) {
    if (maquinas.isEmpty) return null;
    final possiveis = maquinas.length * 7;
    var ocupados = 0;
    for (final maquina in maquinas) {
      for (var i = 0; i < 7; i++) {
        final dia = segunda.add(Duration(days: i));
        final ocupada = state.bookings.any(
          (b) =>
              (b.status == BookingStatus.confirmed ||
                  b.status == BookingStatus.rented ||
                  b.status == BookingStatus.completed) &&
              b.machineIds.contains(maquina.id) &&
              !dia.isBefore(_dia(b.startsAt)) &&
              !dia.isAfter(_dia(b.endsAt)),
        );
        if (ocupada) ocupados++;
      }
    }
    return ocupados / possiveis * 100;
  }

  final segunda = inicioDaSemana(now);
  return OcupacaoSemana(
    percent: percentDaSemanaDe(segunda),
    percentSemanaAnterior: percentDaSemanaDe(
      segunda.subtract(const Duration(days: 7)),
    ),
    alugadas: maquinas.where((m) => m.status == MachineStatus.rented).length,
    emManutencao: maquinas
        .where((m) => m.status == MachineStatus.maintenance)
        .length,
    disponiveis: maquinas
        .where((m) => m.status == MachineStatus.available)
        .length,
  );
}

class MaquinaAlugueres {
  const MaquinaAlugueres({required this.maquina, required this.alugueres});
  final Machine maquina;
  final int alugueres;
}

List<MaquinaAlugueres> topMaquinasMaisAlugadas(
  OperationsState state,
  int n, {
  DateTime? desde,
}) {
  final contagem = <String, int>{};
  for (final booking in state.bookings) {
    if (booking.status == BookingStatus.cancelled) continue;
    if (desde != null && booking.startsAt.isBefore(desde)) continue;
    for (final id in booking.machineIds) {
      contagem[id] = (contagem[id] ?? 0) + 1;
    }
  }
  final lista = <MaquinaAlugueres>[];
  for (final maquina in state.machines.where((m) => !m.archived)) {
    final total = contagem[maquina.id] ?? 0;
    if (total == 0) continue;
    lista.add(MaquinaAlugueres(maquina: maquina, alugueres: total));
  }
  lista.sort((a, b) => b.alugueres.compareTo(a.alugueres));
  return lista.take(n).toList();
}

class MaquinaSemAluguer {
  const MaquinaSemAluguer({required this.maquina, required this.diasSemAluguer});
  final Machine maquina;

  /// `null` quando nunca teve aluguer nenhum — não é "há 0 dias", é "nunca".
  final int? diasSemAluguer;
}

/// Máquinas que não trabalham há mais de [dias].
///
/// Mede-se pelo **último aluguer**, e não pela data em que passaram a "parada":
/// o modelo não guarda quando o estado mudou. Uma máquina marcada como parada
/// hoje mas alugada ontem não aparece aqui — e é o correcto: não está parada há
/// tempo, está parada agora.
List<MaquinaSemAluguer> maquinasSemAluguerHaMaisDe(
  OperationsState state,
  int dias,
  DateTime now,
) {
  final resultado = <MaquinaSemAluguer>[];
  for (final maquina in state.machines.where((m) => !m.archived)) {
    if (maquina.status == MachineStatus.rented ||
        maquina.status == MachineStatus.reserved) {
      continue;
    }
    DateTime? ultimo;
    for (final booking in state.bookings) {
      if (booking.status == BookingStatus.cancelled) continue;
      if (!booking.machineIds.contains(maquina.id)) continue;
      if (ultimo == null || booking.endsAt.isAfter(ultimo)) {
        ultimo = booking.endsAt;
      }
    }
    if (ultimo == null) {
      resultado.add(MaquinaSemAluguer(maquina: maquina, diasSemAluguer: null));
      continue;
    }
    final passados = _dia(now).difference(_dia(ultimo)).inDays;
    if (passados > dias) {
      resultado.add(
        MaquinaSemAluguer(maquina: maquina, diasSemAluguer: passados),
      );
    }
  }
  resultado.sort(
    (a, b) => (b.diasSemAluguer ?? 1 << 30).compareTo(a.diasSemAluguer ?? 1 << 30),
  );
  return resultado;
}

/// Valor médio por reserva não cancelada. `null` sem reservas com valor.
int? ticketMedioReserva(OperationsState state, {DateTime? desde}) {
  final valores = state.bookings
      .where(
        (b) =>
            b.status != BookingStatus.cancelled &&
            (b.expectedValueCents ?? 0) > 0 &&
            (desde == null || !b.startsAt.isBefore(desde)),
      )
      .map((b) => b.expectedValueCents!)
      .toList();
  if (valores.isEmpty) return null;
  return valores.reduce((a, b) => a + b) ~/ valores.length;
}

// ---------------------------------------------------------------------------
// Slide 4 — custos
// ---------------------------------------------------------------------------

class CustosMes {
  const CustosMes({
    required this.colaboradoresCents,
    required this.colaboradoresActivos,
    required this.frotaCents,
    required this.manutencaoPagaCents,
    required this.manutencaoMedia6MesesCents,
    required this.outrosCustosCents,
    required this.custosFixosDeclaradosCents,
    required this.receitaMesCents,
  });

  final int colaboradoresCents, frotaCents, manutencaoPagaCents;
  final int outrosCustosCents;
  final int colaboradoresActivos;
  final int? manutencaoMedia6MesesCents;
  final int? custosFixosDeclaradosCents;
  final int receitaMesCents;

  int? get custoMedioPorColaborador => colaboradoresActivos == 0
      ? null
      : colaboradoresCents ~/ colaboradoresActivos;

  int get totalCents => colaboradoresCents + frotaCents + manutencaoPagaCents +
      outrosCustosCents;

  /// Peso dos custos na receita do mês. `null` sem receita — sem denominador a
  /// percentagem não existe (e 0% seria uma boa notícia falsa).
  double? get percentDaReceita =>
      receitaMesCents == 0 ? null : totalCents / receitaMesCents * 100;
}

const _categoriasManutencao = {
  ExpenseCategory.machineMaintenance,
  ExpenseCategory.vehicleMaintenance,
};

CustosMes custosMesAgregados(OperationsState state, DateTime now) {
  final inicio = _inicioDoMes(now);
  final fim = _fimDoMes(now);
  int pagoNoPeriodo(
    bool Function(Expense) filtro,
    DateTime de,
    DateTime a,
  ) => state.expenses
      .where(
        (e) =>
            !e.archived &&
            e.status == ExpensePaymentStatus.paid &&
            isInPeriod(e.date, de, a) &&
            filtro(e),
      )
      .fold(0, (soma, e) => soma + e.amountCents);

  final activos = state.collaborators
      .where((c) => !c.archived && c.status == CollaboratorStatus.active)
      .toList();
  // Custo dos colaboradores: o declarado nas fichas, não o que está pago em
  // despesas. É o que o gestor precisa para saber quanto lhe custa a equipa.
  final colaboradores = activos.fold(
    0,
    (soma, c) => soma + (monthlyCollaboratorCost(c) ?? 0),
  );
  final frota = state.vehicles
      .where((v) => !v.archived && v.status != VehicleStatus.inactive)
      .fold(0, (soma, v) => soma + monthlyFleetCost(v));
  final manutencao = pagoNoPeriodo(
    (e) => _categoriasManutencao.contains(e.category),
    inicio,
    fim,
  );

  int? media6Meses() {
    var total = 0;
    var meses = 0;
    for (var i = 1; i <= 6; i++) {
      final mes = DateTime(now.year, now.month - i);
      final temDespesas = state.expenses.any(
        (e) =>
            !e.archived && isInPeriod(e.date, _inicioDoMes(mes), _fimDoMes(mes)),
      );
      if (!temDespesas) continue;
      total += pagoNoPeriodo(
        (e) => _categoriasManutencao.contains(e.category),
        _inicioDoMes(mes),
        _fimDoMes(mes),
      );
      meses++;
    }
    return meses == 0 ? null : total ~/ meses;
  }

  return CustosMes(
    colaboradoresCents: colaboradores,
    colaboradoresActivos: activos.length,
    frotaCents: frota,
    manutencaoPagaCents: manutencao,
    manutencaoMedia6MesesCents: media6Meses(),
    // Tudo o que foi pago no mês e não é manutenção nem salários: os salários
    // já entram pelo custo declarado da equipa e contá-los duas vezes inflava
    // o total.
    outrosCustosCents: pagoNoPeriodo(
      (e) =>
          !_categoriasManutencao.contains(e.category) &&
          e.category != ExpenseCategory.salaries,
      inicio,
      fim,
    ),
    custosFixosDeclaradosCents: state.fixedMonthlyCostsCents,
    receitaMesCents: receiptTotal(state.receipts, inicio, fim),
  );
}

/// Repartição do custo de frota por rubrica, para a sub-linha do card.
class RubricasFrota {
  const RubricasFrota({
    required this.segurosCents,
    required this.prestacoesCents,
    required this.combustivelCents,
    required this.alugueresCents,
  });
  final int segurosCents, prestacoesCents, combustivelCents, alugueresCents;
}

RubricasFrota rubricasFrota(OperationsState state, DateTime now) {
  final activos = state.vehicles
      .where((v) => !v.archived && v.status != VehicleStatus.inactive)
      .toList();
  int pagoDoMes(ExpenseCategory categoria) => state.expenses
      .where(
        (e) =>
            !e.archived &&
            e.status == ExpensePaymentStatus.paid &&
            e.category == categoria &&
            isInPeriod(e.date, _inicioDoMes(now), _fimDoMes(now)),
      )
      .fold(0, (soma, e) => soma + e.amountCents);
  return RubricasFrota(
    segurosCents: activos.fold(
      0,
      (soma, v) => soma + (monthlyInsuranceCost(v) ?? 0),
    ),
    prestacoesCents: activos.fold(
      0,
      (soma, v) => soma + (v.monthlyPaymentCents ?? 0),
    ),
    combustivelCents: pagoDoMes(ExpenseCategory.fuel),
    alugueresCents: pagoDoMes(ExpenseCategory.rent),
  );
}

// ---------------------------------------------------------------------------
// Slide 5 — a semana
// ---------------------------------------------------------------------------

/// A recomendação a mostrar: **uma**, não uma pilha.
///
/// Ordena por gravidade (urgente primeiro) e salta as que foram adiadas e ainda
/// não voltaram. Devolve `null` quando não há nada a dizer — melhor calar-se do
/// que encher o ecrã com conselho genérico.
Recommendation? recomendacaoDaSemana(
  OperationsState state,
  DateTime now, {
  Map<String, DateTime> adiadasAte = const {},
}) {
  final todas = GuidanceEngine().evaluate(
    GuidanceInput(
      bookings: state.bookings,
      machines: state.machines,
      receipts: state.receipts,
      expenses: state.expenses,
      now: now,
    ),
  );
  final elegiveis = todas.where((r) {
    final ate = adiadasAte[r.id];
    return ate == null || !now.isBefore(ate);
  }).toList();
  if (elegiveis.isEmpty) return null;
  elegiveis.sort(
    (a, b) => b.gravidade.prioridade.compareTo(a.gravidade.prioridade),
  );
  return elegiveis.first;
}

/// Quanto é que este colaborador trouxe para dentro no mês de [mes].
///
/// Conta as reservas de que ele é responsável e que chegaram a valer dinheiro:
/// confirmadas, alugadas ou concluídas. Pedidos e propostas ficam de fora — uma
/// proposta enviada não é uma venda, e contá-la dava a quem só envia propostas
/// os mesmos números de quem fecha negócio. Canceladas idem.
///
/// A data que manda é o início da reserva: é aí que o trabalho foi colocado.
///
/// `valorCents` é `null` quando nenhuma das reservas do mês tem valor esperado
/// preenchido — não é zero. Zero significaria "vendeu e não rendeu nada", e o
/// que se passa é que não se sabe. Se algumas tiverem valor e outras não, soma
/// as que têm: é a melhor estimativa disponível, e a contagem ao lado diz
/// quantas reservas estão por trás do número.
({int contagem, int? valorCents}) vendasDoMesDoColaborador(
  OperationsState state,
  String collaboratorId,
  DateTime mes,
) {
  const contam = {
    BookingStatus.confirmed,
    BookingStatus.rented,
    BookingStatus.completed,
  };
  final doMes = state.bookings.where(
    (b) =>
        b.collaboratorResponsibleId == collaboratorId &&
        contam.contains(b.status) &&
        b.startsAt.year == mes.year &&
        b.startsAt.month == mes.month,
  );
  var contagem = 0;
  int? valor;
  for (final booking in doMes) {
    contagem++;
    final esperado = booking.expectedValueCents;
    if (esperado != null) valor = (valor ?? 0) + esperado;
  }
  return (contagem: contagem, valorCents: valor);
}

/// O que sai *mesmo* da empresa em pessoal, num mês.
///
/// O `colaboradoresCents` do [CustosMes] é a soma dos brutos. Para quem tem
/// gente com contrato, isso subestima o custo em quase um quarto: a TSU da
/// entidade patronal não aparece no vencimento e é o que mais se esquece.
///
/// `bruto` soma todos os vínculos; `tsuPatronal` só incide sobre os contratos,
/// porque em recibos verdes o valor pago é o custo total. `total` é a soma dos
/// dois — o número que o gestor precisa de ver.
///
/// O `regime` entra porque o cálculo de cada pessoa passa pelo
/// [estimarSalarial], que o exige. Em [RegimeFiscal.outro] não há estimativa
/// aplicável e as três parcelas vêm a `null`: a UI esconde o KPI em vez de
/// mostrar 0 €, como manda a Decisão 1 — mostrar KPI irrelevante é ruído pior
/// do que ausência.
///
/// O próprio empresário em nome individual não entra aqui: não é colaborador de
/// si mesmo, desconta como trabalhador independente, e contá-lo era contradição
/// jurídica. Só entram os registos de `state.collaborators`.
({int? bruto, int? tsuPatronal, int? total}) custoRealComPessoalMes(
  OperationsState state, {
  required RegimeFiscal regime,
}) {
  if (regime == RegimeFiscal.outro) {
    return (bruto: null, tsuPatronal: null, total: null);
  }
  var bruto = 0;
  var tsuPatronal = 0;
  for (final colaborador in state.collaborators) {
    // Arquivados fora: um colaborador eliminado não custa dinheiro este mês.
    if (colaborador.archived) continue;
    if (colaborador.status != CollaboratorStatus.active) continue;
    final mensal = monthlyCollaboratorCost(colaborador);
    if (mensal == null) continue;
    final estimativa = estimarSalarial(
      regime: regime,
      tipo: colaborador.employmentType,
      estado: colaborador.maritalStatus,
      dependentes: colaborador.dependents,
      brutoMensalCents: mensal,
    );
    if (estimativa == null) continue;
    bruto += mensal;
    tsuPatronal += estimativa.tsuEntidadePatronalCents;
  }
  return (bruto: bruto, tsuPatronal: tsuPatronal, total: bruto + tsuPatronal);
}
