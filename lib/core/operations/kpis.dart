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
    required this.entradasPrevistasCents,
    required this.pagoCents,
    required this.encargosFixosVencidosCents,
    required this.recebidoMesAnteriorCents,
    required this.recebidoMesHomologoCents,
    required this.serieDiariaCents,
  });

  final DateTime mes;

  /// Só o que foi lançado como despesa paga. **Não é o que sai da conta**: a
  /// prestação da carrinha e a renda não se lançam à mão, declaram-se uma vez.
  /// Quem mostra saídas ao gestor mostra [saidasCents].
  final int recebidoCents, pagoCents, recebidoMesAnteriorCents;

  /// Encargos declarados com dia marcado cuja data já passou este mês.
  ///
  /// Isto era o buraco de canalização do painel: duas viaturas com prestação a
  /// 2 e a 3 saíam mesmo da conta antes do dia 4, e o card dizia "Saídas 0"
  /// porque ninguém as tinha lançado como despesa — nem tinha de as lançar.
  final int encargosFixosVencidosCents;

  /// O mesmo mês do ano passado. Zero quando não há histórico que lá chegue.
  final int recebidoMesHomologoCents;

  /// O que o mês está **previsto** faturar: o já recebido mais o valor das
  /// reservas já na agenda até ao fim do mês que ainda não entrou. É este — e
  /// não o recebido — que a tendência compara com o mês de referência.
  ///
  /// Porquê: a dia 5 o recebido ainda não conta o trabalho já marcado para o
  /// resto do mês. Se o mês passado faturou 10.000 €, hoje só entraram 1.000 €
  /// mas há reservas de 5.000 € até ao fim, o previsto são 6.000 € — 40% abaixo
  /// do mês passado. O gestor lê a seta e sabe que tem de converter mais leads
  /// para lá chegar, em vez de ver um −90% falso que só dizia "o mês agora
  /// começou". A tendência é direccional, não é um número exacto — por isso
  /// conta o que está previsto. Ver [_variacao].
  final int entradasPrevistasCents;

  /// Um valor por dia do mês, para a sparkline. Índice 0 = dia 1.
  final List<int> serieDiariaCents;

  /// Variação percentual face ao mês anterior. `null` quando o mês anterior foi
  /// zero — dividir por zero não dá "infinito por cento", dá desconhecido.
  double? get variacaoVsMesAnterior => _variacao(recebidoMesAnteriorCents);

  /// Variação face ao mesmo mês do ano passado.
  double? get variacaoVsHomologo => _variacao(recebidoMesHomologoCents);

  /// A comparação a mostrar, e contra o quê.
  ///
  /// **Homólogo primeiro, quando existe.** Num negócio de aluguer de máquinas o
  /// mês passado e este mês não são comparáveis: Agosto contra Julho mistura
  /// variação de negócio com estação do ano. O mesmo mês do ano passado é a
  /// única comparação que isola o que mudou na empresa.
  ///
  /// No primeiro ano não há homólogo nenhum, e aí o mês anterior é melhor do que
  /// nada — desde que se diga contra o que se está a comparar, senão o gestor lê
  /// uma percentagem sem saber de onde vem.
  ({double variacao, bool homologo})? get comparacao {
    final vsHomologo = variacaoVsHomologo;
    if (vsHomologo != null) return (variacao: vsHomologo, homologo: true);
    final vsAnterior = variacaoVsMesAnterior;
    if (vsAnterior != null) return (variacao: vsAnterior, homologo: false);
    return null;
  }

  /// Compara o **previsto** deste mês com um mês de referência já fechado. O
  /// numerador é [entradasPrevistasCents], não [recebidoCents]: a tendência
  /// mede o rumo do mês inteiro, não a foto de hoje.
  double? _variacao(int base) =>
      base == 0 ? null : (entradasPrevistasCents - base) / base * 100;

  /// Tudo o que saiu: o lançado à mão mais os encargos declarados já vencidos.
  int get saidasCents => pagoCents + encargosFixosVencidosCents;

  bool get semMovimentos => recebidoCents == 0 && saidasCents == 0;
}

/// Um encargo declarado para o dia [dia] de [mes] já venceu à data [hoje]?
///
/// Três casos, e o do meio é o que interessa: mês por vir — nada venceu; mês a
/// decorrer — venceu o que tem dia até hoje, com o dia de hoje a contar (uma
/// prestação debitada hoje de manhã já saiu da conta); mês fechado — venceu
/// tudo, não interessa em que dia.
bool encargoJaVenceu(int? dia, DateTime mes, DateTime hoje) {
  if (dia == null) return false;
  if (hoje.isBefore(_inicioDoMes(mes))) return false;
  final mesmoMes = hoje.year == mes.year && hoje.month == mes.month;
  return mesmoMes ? dia <= hoje.day : true;
}

/// Encargos declarados com dia marcado que já saíram da conta em [mes].
///
/// Prestações de viaturas e rubricas de custo fixo. Nenhuma delas se lança
/// como despesa — declaram-se uma vez e saem sozinhas todos os meses —, e era
/// por isso que o painel não as via.
///
/// O que **não** tem dia declarado fica de fora de propósito: sem data não há
/// como saber se já saiu, e inventar um dia 1 punha o mês inteiro a pesar logo
/// no primeiro dia. Esse custo continua a entrar repartido pelos dias, em
/// [CustosMes.custoAteAgoraCents].
int encargosFixosVencidosCents(
  OperationsState state,
  DateTime mes,
  DateTime hoje,
) {
  final prestacoes = state.vehicles
      .where(
        (v) =>
            !v.archived &&
            v.status != VehicleStatus.inactive &&
            v.monthlyPaymentCents != null &&
            encargoJaVenceu(v.paymentDayOfMonth, mes, hoje),
      )
      .fold<int>(0, (soma, v) => soma + v.monthlyPaymentCents!);
  final rubricas = state.custosFixos
      .where((c) => encargoJaVenceu(c.diaDoMes, mes, hoje))
      .fold<int>(0, (soma, c) => soma + c.valorCents);
  return prestacoes + rubricas;
}

/// Categorias cobertas por uma rubrica fixa com data. Uma despesa paga desta
/// categoria não volta a contar: já entrou pelo valor declarado.
Set<ExpenseCategory> categoriasComRubricaDatada(OperationsState state) => state
    .custosFixos
    .where((c) => c.diaDoMes != null)
    .map((c) => c.categoria)
    .toSet();

/// Recebido e pago de [mes], com [hoje] a decidir que encargos já venceram.
///
/// [hoje] existe porque um mês fechado e o mês a decorrer não se lêem da mesma
/// maneira: em Julho todas as prestações de Julho já saíram, a 4 de Agosto só
/// saíram as dos dias 1 a 4. Por omissão vale [mes], que é o que serve para
/// pedir um mês inteiro — quem quer o mês a decorrer passa a data de hoje.
TesourariaMes tesourariaDoMes(
  OperationsState state,
  DateTime mes, {
  DateTime? hoje,
}) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  final referencia = hoje ?? mes;
  final anterior = DateTime(mes.year, mes.month - 1);
  final homologo = DateTime(mes.year - 1, mes.month);
  final diasNoMes = fim.day;
  return TesourariaMes(
    mes: inicio,
    recebidoCents: receiptTotal(state.receipts, inicio, fim),
    // O previsto do mês: o recebido mais o valor das reservas já na agenda que
    // ainda não entrou. Mesma conta que a previsão do mês (`previsaoDoMes`),
    // aqui só para a tendência da célula de entradas.
    entradasPrevistasCents:
        receiptTotal(state.receipts, inicio, fim) +
        _porReceberDeReservasDoMes(state, mes),
    // As categorias que já têm rubrica fixa declarada com data ficam de fora:
    // entram pelo valor declarado, e contá-las dos dois lados duplicava a
    // saída. É a mesma regra que já valia para os salários em
    // `custosMesAgregados` — a fonte declarada manda.
    pagoCents: paidExpenseTotal(
      state.expenses.where(
        (e) => !categoriasComRubricaDatada(state).contains(e.category),
      ),
      inicio,
      fim,
    ),
    encargosFixosVencidosCents: encargosFixosVencidosCents(
      state,
      mes,
      referencia,
    ),
    // Mesma rede de segurança que o homólogo: recebimentos reais primeiro, e o
    // histórico mensal preenchido quando não os há. Sem isto, uma empresa nova
    // — sem homólogo nenhum — via "sem histórico para comparar" mesmo com o mês
    // anterior declarado, porque só este ramo é que olhava para os recibos crus.
    recebidoMesAnteriorCents: _recebidoDoMesComHistorico(state, anterior),
    recebidoMesHomologoCents: _recebidoDoMesComHistorico(state, homologo),
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

/// Recebido de um mês de referência (homólogo **ou** mês anterior), com o
/// histórico mensal como rede de segurança.
///
/// **Prefere sempre os recebimentos registados.** Só quando não há nenhum é
/// que cai para o valor que o gestor preencheu à mão no histórico mensal
/// (ecrã de Definições da Empresa) — o mesmo tomba-prioridades já
/// usado em `_receitaHomologa`, mais abaixo neste ficheiro, para a
/// recomendação da semana. Antes desta função, `tesourariaDoMes` só olhava
/// para os recebimentos e ignorava por completo o histórico mensal: um
/// gestor que preenchesse o mês
/// de Agosto do ano passado continuava a ver "Por apurar" no painel, porque a
/// comparação nunca ia lá buscar o número. As **duas** referências da tendência
/// passam por aqui — homólogo e mês anterior —, senão a empresa nova ficava sem
/// nenhuma comparação possível.
///
/// **Nunca inventa.** Sem recebimentos e sem histórico preenchido, devolve
/// zero — e é esse zero que faz `variacaoVsHomologo` sair `null` em vez de uma
/// percentagem fabricada (regra do ficheiro, ver comentário no topo).
int _recebidoDoMesComHistorico(OperationsState state, DateTime mes) {
  final registado = receiptTotal(
    state.receipts,
    _inicioDoMes(mes),
    _fimDoMes(mes),
  );
  if (registado > 0) return registado;
  return state.historicalMonth(mes.year, mes.month)?.revenueReceivedCents ?? 0;
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
  return simpleOperatingResult(mes.recebidoCents, mes.saidasCents);
}

/// Previsão de como vai fechar o mês — diferente do "Encontro de contas".
///
/// **O "Encontro de contas" é real**: o que já entrou contra o que já saiu,
/// até hoje. Não inclui despesas por pagar nem reservas por realizar — dizer
/// isso seria inventar movimento que ainda não aconteceu.
///
/// A previsão é outra pergunta, complementar: "como vai ficar o mês, no
/// final?". Aqui sim entram coisas que ainda não aconteceram, mas que já se
/// sabem:
/// - **entradas previstas** = o que já entrou + o valor ainda por receber das
///   reservas já na agenda deste mês (não inventa clientes novos, só conta
///   compromissos que já existem);
/// - **saídas previstas** = os custos fixos declarados (exactos, não é média)
///   + a média das despesas variáveis do mês anterior e do mês homólogo —
///   a melhor estimativa que não exige adivinhar o futuro.
class PrevisaoDoMes {
  const PrevisaoDoMes({
    required this.mes,
    required this.entradasPrevistasCents,
    required this.saidasPrevistasCents,
  });

  final DateTime mes;
  final int entradasPrevistasCents;

  /// `null` quando não há custos fixos declarados — sem eles a previsão de
  /// saídas seria só a média das variáveis, o que sub-representa o mês.
  final int? saidasPrevistasCents;

  int? get saldoPrevistoCents => saidasPrevistasCents == null
      ? null
      : entradasPrevistasCents - saidasPrevistasCents!;
}

/// Despesas pagas de um mês que não correspondem a nenhuma rubrica de custo
/// fixo declarada — a parte "variável" do que se gastou.
///
/// Exclui por categoria, não por registo: se "Renda" é uma rubrica de custo
/// fixo, uma despesa paga com essa categoria não entra aqui, para não contar
/// a renda duas vezes (uma nos custos fixos, outra na média das variáveis).
int _despesasVariaveisDoMes(OperationsState state, DateTime mes) {
  final categoriasFixas = state.custosFixos.map((c) => c.categoria).toSet();
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return state.expenses
      .where(
        (x) =>
            !x.archived &&
            x.status == ExpensePaymentStatus.paid &&
            isInPeriod(x.date, inicio, fim) &&
            !categoriasFixas.contains(x.category),
      )
      .fold(0, (sum, x) => sum + x.amountCents);
}

/// Houve alguma despesa lançada neste mês?
///
/// Distingue "gastou zero em variáveis" (dado real, um mês que só teve custos
/// fixos) de "não há registo nenhum" (mês em falta — o negócio ainda não
/// existia, ou nada foi lançado). Sem esta distinção, a previsão do mês dividia
/// a média por dois mesmo quando só um mês de referência tinha dados.
bool _temDespesasNoMes(OperationsState state, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return state.expenses.any(
    (x) =>
        !x.archived &&
        x.status == ExpensePaymentStatus.paid &&
        isInPeriod(x.date, inicio, fim),
  );
}

/// Valor ainda por receber das reservas deste mês que ainda não foi cobrado.
///
/// Só reservas já na agenda (confirmadas, alugadas ou concluídas — nunca
/// canceladas): a previsão não inventa clientes que ainda não existem.
int _porReceberDeReservasDoMes(OperationsState state, DateTime mes) {
  final inicio = _inicioDoMes(mes);
  final fim = _fimDoMes(mes);
  return state.bookings
      .where(
        (b) =>
            b.status != BookingStatus.cancelled &&
            !b.startsAt.isAfter(fim) &&
            !b.endsAt.isBefore(inicio),
      )
      .fold(
        0,
        (sum, b) =>
            sum +
            bookingPendingCents(
              b.expectedValueCents ?? 0,
              b.id,
              state.receipts,
            ),
      );
}

PrevisaoDoMes previsaoDoMes(OperationsState state, DateTime now) {
  final inicio = _inicioDoMes(now);
  final fim = _fimDoMes(now);
  final anterior = DateTime(now.year, now.month - 1);
  final homologo = DateTime(now.year - 1, now.month);

  final entradas =
      receiptTotal(state.receipts, inicio, fim) +
      _porReceberDeReservasDoMes(state, now);

  final custosFixos = state.custoFixoMensalCents;
  int? saidas;
  if (custosFixos != null) {
    // Média das despesas variáveis, mas só sobre os meses de referência que
    // *têm* despesas registadas. Um mês sem lançamento nenhum (o negócio ainda
    // não existia, ou nada foi lançado) não é uma despesa de zero euros — é
    // ausência de dados. Dividir sempre por dois arrastava a estimativa para
    // metade quando só um dos meses tinha histórico.
    final variaveis = [anterior, homologo]
        .where((m) => _temDespesasNoMes(state, m))
        .map((m) => _despesasVariaveisDoMes(state, m))
        .toList();
    final mediaVariavel = variaveis.isEmpty
        ? 0
        : variaveis.reduce((a, b) => a + b) ~/ variaveis.length;
    saidas = custosFixos + mediaVariavel;
  }

  return PrevisaoDoMes(
    mes: inicio,
    entradasPrevistasCents: entradas,
    saidasPrevistasCents: saidas,
  );
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
      .where(
        (lead) =>
            noPeriodo(lead, desde, _dia(now).add(const Duration(days: 1))),
      )
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
/// Clientes que entraram nos últimos [dias].
///
/// **Inferido da primeira reserva, não de uma data de criação.** O `Customer`
/// não guarda quando foi criado, e acrescentar o campo agora só serviria para a
/// frente: todos os clientes já registados ficariam sem data e a métrica nascia
/// a mentir durante um mês. A data da primeira reserva é o momento em que a
/// pessoa passou a ser cliente de facto — que é, no fundo, o que a pergunta
/// quer saber.
///
/// Consequência assumida: um cliente registado mas que ainda não alugou nada
/// não conta. É defensável — ainda não comprou — e evita inflar a conversão com
/// contactos que nunca deram dinheiro.
///
/// Devolve `null` quando não há reservas nenhumas: sem elas não há como inferir
/// data alguma, e `0` diria "não angariaste ninguém" em vez de "não sei".
int? clientesNovos(OperationsState state, DateTime now, {int dias = 30}) {
  if (state.bookings.isEmpty) return null;
  final desde = _dia(now).subtract(Duration(days: dias));
  final primeiraReserva = <String, DateTime>{};
  for (final booking in state.bookings) {
    if (booking.status == BookingStatus.cancelled) continue;
    final actual = primeiraReserva[booking.customerId];
    if (actual == null || booking.startsAt.isBefore(actual)) {
      primeiraReserva[booking.customerId] = booking.startsAt;
    }
  }
  return primeiraReserva.values
      .where(
        (data) => !_dia(data).isBefore(desde) && !_dia(data).isAfter(_dia(now)),
      )
      .length;
}

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
// Slide 2 — o pulso do dia (operacional)
// ---------------------------------------------------------------------------

/// O que há para fazer hoje e nas próximas 48 horas.
///
/// **Recolhas, não devoluções.** A máquina é alugada e tem de ser *recuperada*
/// para voltar a estar disponível — é trabalho da empresa, com deslocação e com
/// atraso possível, não um acto do cliente.
///
/// **Limite conhecido:** enquanto não existir o evento de recolha (ver
/// `docs/LIGACAO_PERGUNTAS_SCREENS.md`), "recolha por fazer" é inferida do
/// estado da reserva — uma reserva que continua `rented` depois de `endsAt` é
/// uma máquina que ninguém deu por recolhida. É uma aproximação honesta, e
/// deixa de ser aproximação no dia em que o colaborador tiver o botão.
class PulsoOperacional {
  const PulsoOperacional({
    required this.semDados,
    required this.reservasActivas,
    required this.reservasATerminar48h,
    required this.entregasHoje,
    required this.entregasPorFazer,
    required this.recolhasHoje,
    required this.recolhasProximas48h,
    required this.recolhasEmAtraso,
    required this.diasDaRecolhaMaisAtrasada,
    required this.cobrancasAVencerCents,
    required this.clientesACobrar,
    required this.venceHojeCents,
  });

  /// Não há reservas nenhumas registadas. Diferente de "hoje não há nada a
  /// fazer": um é falta de dados, o outro é uma boa notícia. Quem desenha tem
  /// de os separar, senão a app diz "0 entregas" a quem nunca registou nada e
  /// parece que perdeu a informação.
  final bool semDados;

  final int reservasActivas, reservasATerminar48h;
  final int entregasHoje, entregasPorFazer;
  final int recolhasHoje, recolhasProximas48h, recolhasEmAtraso;

  /// Dias de atraso da recolha mais antiga por fazer. `null` quando não há
  /// nenhuma em atraso.
  final int? diasDaRecolhaMaisAtrasada;

  final int cobrancasAVencerCents, clientesACobrar, venceHojeCents;

  /// A linha de rodapé: só o que exige acção, pela ordem em que dói.
  ///
  /// Devolve `null` quando não há nada a assinalar — em vez de "0 alertas", que
  /// ocupa uma linha para não dizer nada.
  String? get alertas {
    final partes = <String>[
      if (recolhasEmAtraso > 0)
        recolhasEmAtraso == 1
            ? '1 recolha em atraso'
            : '$recolhasEmAtraso recolhas em atraso',
      if (entregasPorFazer > 0)
        entregasPorFazer == 1
            ? '1 entrega por fazer'
            : '$entregasPorFazer entregas por fazer',
      if (venceHojeCents > 0)
        'cobrança de ${_euros(venceHojeCents)} vence hoje',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }
}

String _euros(int cents) => '${(cents / 100).round()} €';

/// Uma passagem pelas reservas, todas as contagens do slide 2.
PulsoOperacional pulsoOperacional(OperationsState state, DateTime now) {
  final hoje = _dia(now);
  final daquiA48h = hoje.add(const Duration(days: 2));

  var reservasActivas = 0, reservasATerminar48h = 0;
  var entregasHoje = 0, entregasPorFazer = 0;
  var recolhasHoje = 0, recolhasProximas48h = 0, recolhasEmAtraso = 0;
  int? maiorAtraso;

  for (final booking in state.bookings) {
    // Canceladas e concluídas não geram trabalho nenhum.
    if (booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.completed) {
      continue;
    }
    // Tudo o resto — pedido, proposta, confirmada, alugada — é agenda ocupada:
    // conta para o pulso do dia mesmo antes de confirmada, porque a máquina já
    // está prometida. "Alugada" é só o marco de a máquina ter mesmo saído.
    final entregue = booking.status == BookingStatus.rented;

    final inicio = _dia(booking.startsAt);
    final fim = _dia(booking.endsAt);

    if (!inicio.isAfter(hoje) && !fim.isBefore(hoje)) {
      reservasActivas++;
      if (!fim.isAfter(daquiA48h)) reservasATerminar48h++;
    }

    if (inicio == hoje) {
      entregasHoje++;
      // Só deixa de estar "por fazer" quando a máquina foi mesmo entregue.
      if (!entregue) entregasPorFazer++;
    }

    if (fim.isBefore(hoje)) {
      // Passou do fim e continua alugada — ninguém deu a máquina por recolhida.
      if (entregue) {
        recolhasEmAtraso++;
        final dias = hoje.difference(fim).inDays;
        if (maiorAtraso == null || dias > maiorAtraso) maiorAtraso = dias;
      }
    } else {
      if (fim == hoje) recolhasHoje++;
      if (!fim.isAfter(daquiA48h)) recolhasProximas48h++;
    }
  }

  // Cobranças: o que já está por receber mais o que vence dentro de 7 dias.
  final limiteCobranca = hoje.add(const Duration(days: 7));
  var cobrancasCents = 0, venceHojeCents = 0;
  final clientes = <String>{};
  for (final cobranca in cobrancasPorReceber(state, now)) {
    if (_dia(cobranca.booking.endsAt).isAfter(limiteCobranca)) continue;
    cobrancasCents += cobranca.emDividaCents;
    clientes.add(cobranca.booking.customerId);
    if (_dia(cobranca.booking.endsAt) == hoje) {
      venceHojeCents += cobranca.emDividaCents;
    }
  }

  return PulsoOperacional(
    semDados: state.bookings.isEmpty,
    reservasActivas: reservasActivas,
    reservasATerminar48h: reservasATerminar48h,
    entregasHoje: entregasHoje,
    entregasPorFazer: entregasPorFazer,
    recolhasHoje: recolhasHoje,
    recolhasProximas48h: recolhasProximas48h,
    recolhasEmAtraso: recolhasEmAtraso,
    diasDaRecolhaMaisAtrasada: maiorAtraso,
    cobrancasAVencerCents: cobrancasCents,
    clientesACobrar: clientes.length,
    venceHojeCents: venceHojeCents,
  );
}

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

class UtilizacaoERentabilidade {
  const UtilizacaoERentabilidade({
    required this.ocupacaoPercent,
    required this.percentInvestimentoRecuperado,
    required this.maquinasComValorDeCompra,
    required this.totalMaquinas,
  });

  /// Ocupação da semana corrente — a mesma leitura de [ocupacaoMaquinasSemana].
  final double? ocupacaoPercent;

  /// `null` enquanto nenhuma máquina tiver valor de compra registado — sem
  /// isso não há denominador. Conta só as máquinas que o têm: dividir pela
  /// frota toda subestimaria o retorno das que o gestor ainda não registou.
  final double? percentInvestimentoRecuperado;

  final int maquinasComValorDeCompra;
  final int totalMaquinas;
}

/// Junta ocupação e retorno do investido: uma máquina sempre ocupada ainda
/// não recuperou o que custou se o preço/dia for baixo, e uma máquina parada
/// nunca recupera nada por muito caro que tenha sido o preço/dia — as duas
/// leituras têm de andar juntas, não sozinhas.
///
/// A receita de cada reserva reparte-se por igual entre as máquinas dessa
/// reserva (reservas com várias máquinas não têm o valor discriminado por
/// máquina no modelo).
UtilizacaoERentabilidade utilizacaoERentabilidade(
  OperationsState state,
  DateTime now,
) {
  final maquinas = state.machines.where((m) => !m.archived).toList();
  final comValorDeCompra = maquinas
      .where((m) => m.purchasePriceCents != null)
      .toList();

  final receitaPorMaquina = <String, int>{};
  for (final booking in state.bookings) {
    if (booking.status == BookingStatus.cancelled) continue;
    final valor = booking.expectedValueCents;
    if (valor == null || booking.machineIds.isEmpty) continue;
    final porMaquina = valor ~/ booking.machineIds.length;
    for (final id in booking.machineIds) {
      receitaPorMaquina[id] = (receitaPorMaquina[id] ?? 0) + porMaquina;
    }
  }

  double? percentRecuperado;
  if (comValorDeCompra.isNotEmpty) {
    final investido = comValorDeCompra.fold<int>(
      0,
      (soma, m) => soma + m.purchasePriceCents!,
    );
    if (investido > 0) {
      final recuperado = comValorDeCompra.fold<int>(
        0,
        (soma, m) => soma + (receitaPorMaquina[m.id] ?? 0),
      );
      percentRecuperado = recuperado / investido * 100;
    }
  }

  return UtilizacaoERentabilidade(
    ocupacaoPercent: ocupacaoMaquinasSemana(state, now).percent,
    percentInvestimentoRecuperado: percentRecuperado,
    maquinasComValorDeCompra: comValorDeCompra.length,
    totalMaquinas: maquinas.length,
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
  const MaquinaSemAluguer({
    required this.maquina,
    required this.diasSemAluguer,
  });
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
    (a, b) =>
        (b.diasSemAluguer ?? 1 << 30).compareTo(a.diasSemAluguer ?? 1 << 30),
  );
  return resultado;
}

/// Valor médio por reserva não cancelada. `null` sem reservas com valor.
/// O ticket médio do mês, à maneira do Cesar (9 Ago 2026): o **valor total
/// comprado no mês** a dividir pelo **número de empresas distintas que
/// compraram** nesse mês. Não é média por reserva — uma empresa com três
/// reservas conta **uma** vez, e o que pesa é quanto cada cliente vale, não
/// quantas linhas abriu.
///
/// O mês é o de [now], e uma reserva conta no mês em que **começa**
/// (`startsAt`): é o mês em que a máquina sai, o negócio desse mês. Canceladas e
/// reservas sem valor ficam de fora — sem valor não há compra que se saiba medir.
class TicketMedioMes {
  const TicketMedioMes({
    required this.porEmpresaCents,
    required this.empresas,
    required this.totalCents,
    required this.transacoes,
  });

  /// O número grande: total do mês dividido pelas empresas distintas.
  final int porEmpresaCents;

  /// Quantas empresas distintas compraram no mês — o denominador.
  final int empresas;

  /// O que foi comprado (previsto) no mês, somadas todas as empresas.
  final int totalCents;

  /// Quantas transacções (compras/reservas) houve no mês, contando todas — uma
  /// empresa pode ter várias. É o numerador do número médio de transacções.
  final int transacoes;

  /// Número médio de transacções por empresa: quantas vezes, em média, cada
  /// cliente comprou este mês. Pode ser fraccionário (7 compras, 2 empresas →
  /// 3,5). O Cesar quis este número ao lado do ticket (9 Ago).
  double get transacoesMediasPorEmpresa => transacoes / empresas;
}

TicketMedioMes? ticketMedioDoMes(OperationsState state, DateTime now) {
  var total = 0;
  var transacoes = 0;
  final empresas = <String>{};
  for (final b in state.bookings) {
    if (b.status == BookingStatus.cancelled) continue;
    final valor = b.expectedValueCents ?? 0;
    if (valor <= 0) continue;
    if (b.startsAt.year != now.year || b.startsAt.month != now.month) continue;
    total += valor;
    transacoes++;
    empresas.add(b.customerId);
  }
  if (empresas.isEmpty) return null;
  return TicketMedioMes(
    porEmpresaCents: total ~/ empresas.length,
    empresas: empresas.length,
    totalCents: total,
    transacoes: transacoes,
  );
}

// ---------------------------------------------------------------------------
// Slide 4 — custos
// ---------------------------------------------------------------------------

class CustosMes {
  const CustosMes({
    required this.custoRealPessoalCents,
    required this.pessoalBrutoCents,
    required this.tsuPatronalCents,
    required this.colaboradoresActivos,
    required this.frotaCents,
    required this.manutencaoPagaCents,
    required this.manutencaoMedia6MesesCents,
    required this.outrosCustosCents,
    required this.custosFixosDeclaradosCents,
    required this.receitaMesCents,
    required this.fracaoDoMesDecorrida,
    required this.prestacoesComDataCents,
    required this.prestacoesVencidasCents,
  });

  /// Bruto **mais** a carga social da entidade patronal — o que sai mesmo da
  /// empresa. Chamava-se `colaboradoresCents` e era só a soma dos brutos; o
  /// nome mudou para o compilador apanhar todos os leitores, porque o
  /// significado mudou (Decisão 12 do guião).
  final int custoRealPessoalCents;

  /// A parcela que aparece nos vencimentos.
  final int pessoalBrutoCents;

  /// A parcela que não aparece em vencimento nenhum. `null` quando o regime
  /// fiscal não é modelado — e aí o [custoRealPessoalCents] cai para o bruto,
  /// portanto o total **subestima**. Quem mostra o número tem de o dizer.
  final int? tsuPatronalCents;

  final int frotaCents, manutencaoPagaCents;
  final int outrosCustosCents;
  final int colaboradoresActivos;
  final int? manutencaoMedia6MesesCents;
  final int? custosFixosDeclaradosCents;
  final int receitaMesCents;

  /// Quanto do mês já passou, de 0 a 1 — dia 4 de Agosto dá 4/31.
  ///
  /// Existe porque as duas metades da conta não andam ao mesmo ritmo: salários
  /// e frota são encargos do **mês inteiro** desde o dia 1, e a receita vai
  /// entrando. Dividir um pelo outro no dia 4 compara 31 dias de custo com 4
  /// dias de receita, e dá números absurdos — 2149% num telemóvel real, com o
  /// card do lado a dizer "Saídas 0" (achado no teste de campo, 04-08-2026).
  final double fracaoDoMesDecorrida;

  /// A parte de [frotaCents] que tem dia de débito declarado, e a parte dessa
  /// que já venceu. Servem para tirar as prestações datadas da conta repartida
  /// e pô-las onde elas de facto caem: inteiras, no dia em que saem.
  final int prestacoesComDataCents, prestacoesVencidasCents;

  /// Média sobre o custo real: é o que a pessoa custa à empresa, não o que
  /// recebe.
  int? get custoMedioPorColaborador => colaboradoresActivos == 0
      ? null
      : custoRealPessoalCents ~/ colaboradoresActivos;

  /// O custo do mês fechado: tudo o que este mês vai custar.
  int get totalCents =>
      custoRealPessoalCents +
      frotaCents +
      manutencaoPagaCents +
      outrosCustosCents;

  /// O custo já incorrido à data.
  ///
  /// Três ritmos diferentes, e é por isso que a conta não é uma só:
  /// - o que tem **data declarada** (prestações) conta inteiro a partir do dia
  ///   em que sai, e não conta nada antes disso;
  /// - o que **não tem data** (salários, seguros e manutenção diluídos ao mês)
  ///   entra repartido pelos dias decorridos — é o mais honesto que se diz sem
  ///   saber o dia;
  /// - manutenção paga e restantes despesas já são dinheiro saído, entram
  ///   inteiras.
  int get custoAteAgoraCents =>
      ((custoRealPessoalCents + frotaCents - prestacoesComDataCents) *
              fracaoDoMesDecorrida)
          .round() +
      prestacoesVencidasCents +
      manutencaoPagaCents +
      outrosCustosCents;

  /// Peso dos custos na receita do mês. `null` sem receita — sem denominador a
  /// percentagem não existe (e 0% seria uma boa notícia falsa).
  ///
  /// Compara [custoAteAgoraCents] e não [totalCents]: os dois lados têm de
  /// cobrir o mesmo pedaço de calendário, senão a percentagem mede o dia do
  /// mês em vez de medir o negócio.
  double? get percentDaReceita =>
      receitaMesCents == 0 ? null : custoAteAgoraCents / receitaMesCents * 100;
}

const _categoriasManutencao = {
  ExpenseCategory.machineMaintenance,
  ExpenseCategory.vehicleMaintenance,
};

/// Custos do mês, já com o pessoal ao custo real.
///
/// O `regime` é obrigatório porque a carga social da entidade patronal entra no
/// total (Decisão 12 do guião): dois cards no mesmo ecrã a dar números
/// diferentes para a mesma pessoa é a app a contradizer-se, e o gestor perde a
/// confiança nos dois de uma vez. A TSU patronal é dinheiro que sai da empresa,
/// portanto conta em qualquer agregação de custo.
///
/// Consequência assumida: a recomendação "custos críticos" (≥80% da receita)
/// passa a disparar mais cedo. Não é regressão — antes estava a mascarar.
CustosMes custosMesAgregados(
  OperationsState state,
  DateTime now, {
  required RegimeFiscal regime,
}) {
  final inicio = _inicioDoMes(now);
  final fim = _fimDoMes(now);
  int pagoNoPeriodo(bool Function(Expense) filtro, DateTime de, DateTime a) =>
      state.expenses
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
  // Custo do pessoal: o declarado nas fichas mais a carga social, não o que
  // está pago em despesas. É o que o gestor precisa para saber quanto lhe custa
  // a equipa. Uma fonte só — o mesmo cálculo que alimenta o KPI do slide.
  final pessoal = custoRealComPessoalMes(state, regime: regime);
  // Regime não modelado: o `custoRealComPessoalMes` devolve tudo a `null`, e o
  // bruto calcula-se aqui à mão. O total fica a subestimar — é o preço de não
  // saber a que regime a empresa pertence, e o `tsuPatronalCents` a `null` é o
  // sinal para quem mostra o número o poder dizer.
  final bruto =
      pessoal.bruto ??
      activos.fold<int>(
        0,
        (soma, c) => soma + (monthlyCollaboratorCost(c) ?? 0),
      );
  final naEstrada = state.vehicles
      .where((v) => !v.archived && v.status != VehicleStatus.inactive)
      .toList();
  // Mesmo padrão do bruto do pessoal, dez linhas acima: soma-se o que se sabe
  // e o total fica a subestimar. Usa-se a variante `Known` de propósito — a
  // `monthlyFleetCost` devolve `null` quando falta uma parcela, e aqui isso
  // deitaria fora a prestação que É conhecida. Quem mostra o número é que tem
  // de dizer que há veículos por apurar — ver `VehiclesPage`.
  final frota = naEstrada.fold(0, (soma, v) => soma + monthlyFleetCostKnown(v));
  final comData = naEstrada.where(
    (v) => v.monthlyPaymentCents != null && v.paymentDayOfMonth != null,
  );
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
            !e.archived &&
            isInPeriod(e.date, _inicioDoMes(mes), _fimDoMes(mes)),
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
    custoRealPessoalCents: pessoal.total ?? bruto,
    pessoalBrutoCents: bruto,
    tsuPatronalCents: pessoal.tsuPatronal,
    colaboradoresActivos: activos.length,
    frotaCents: frota,
    prestacoesComDataCents: comData.fold(
      0,
      (soma, v) => soma + v.monthlyPaymentCents!,
    ),
    prestacoesVencidasCents: comData
        .where((v) => encargoJaVenceu(v.paymentDayOfMonth, now, now))
        .fold(0, (soma, v) => soma + v.monthlyPaymentCents!),
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
    // Pelas rubricas quando existem — o total redondo antigo fica para quem
    // ainda não as preencheu.
    custosFixosDeclaradosCents: state.custoFixoMensalCents,
    receitaMesCents: receiptTotal(state.receipts, inicio, fim),
    // O dia de hoje conta por inteiro: quem trabalhou hoje já custou hoje.
    // Arredondar para baixo faria a app subestimar custos, e um aviso de
    // custos que peca por defeito não serve para nada.
    //
    // O dia 0 do mês seguinte é o último dia deste — sem aritmética de
    // durações, que numa mudança de hora legal daria 30 onde devia dar 31.
    fracaoDoMesDecorrida: now.day / DateTime(now.year, now.month + 1, 0).day,
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

/// Limiares das regras específicas. Ficam à vista para poderem ser discutidos
/// sem ler código.
const diasDividaUrgente = 30;
const diasDividaAtencao = 15;
const valorMinimoDividaUrgenteCents = 10000; // 100 €
const percentCustosCritica = 80.0;
const percentQuedaHomologa = 60.0;
const receitaHomologaMinimaCents = 50000; // 500 €
const taxaConversaoBoa = 40.0;

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

const _nomesDosMeses = [
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

/// Regras concretas, ligadas ao estado real da empresa — dívida por cliente,
/// custos a comer a receita, queda homóloga, boa conversão. Cada uma dispara
/// no máximo uma [Recommendation]; várias podem disparar ao mesmo tempo, e é
/// [recomendacaoDaSemana] que escolhe qual mostrar.
List<Recommendation> _recomendacoesEspecificas(
  OperationsState state,
  DateTime now,
) {
  final resultado = <Recommendation>[];
  final dividas = _dividasPorCliente(state, now);

  // Dinheiro antigo e de valor: é o que aperta mais.
  for (final divida in dividas) {
    if (divida.dias > diasDividaUrgente &&
        divida.totalCents >= valorMinimoDividaUrgenteCents) {
      resultado.add(
        Recommendation(
          id: 'divida-urgente',
          title:
              'Cobrar ${divida.nome} — ${divida.dias} dias em atraso, '
              '${_euros(divida.totalCents)}',
          explanation:
              'Tens dinheiro à espera há muito tempo e o valor já pesa.',
          impact:
              'Cobrar agora traz para trás dinheiro que já é teu; deixar '
              'correr só faz crescer.',
          quality: 'Calculado a partir das reservas e recebimentos',
          action: 'Abrir ficha →',
          measure: 'Confirma se o valor em dívida desceu depois de agires.',
          lever: GuidanceLever.cash,
          gravidade: GravidadeRecomendacao.urgente,
        ),
      );
      break;
    }
  }

  // Os custos a levar quase tudo o que entra.
  //
  // O peso é calculado sobre o custo **real** do pessoal, com a carga social
  // incluída (Decisão 12) — dispara mais cedo do que um cálculo sem TSU
  // patronal, e é o que se pretende.
  final custos = custosMesAgregados(
    state,
    now,
    regime: regimeDaFormaJuridica(state.legalForm),
  );
  final peso = custos.percentDaReceita;
  if (peso != null && peso >= percentCustosCritica) {
    resultado.add(
      Recommendation(
        id: 'custos-criticos',
        // "já saiu" era mentira e via-se no mesmo ecrã: o card do encontro de
        // contas dizia "Saídas 0" ao lado deste. Salários e frota são custo
        // incorrido, não dinheiro movimentado — e a diferença nota-se.
        title:
            'Custos a comer a receita — já vão em ${peso.round()}% do que entrou',
        explanation:
            'Os custos reais (com a carga social incluída) contados até hoje '
            'estão a levar quase tudo o que entrou este mês.',
        impact: 'Rever custos agora evita fechar o mês no vermelho.',
        quality: 'Custo do pessoal com TSU patronal, repartido pelos dias',
        action: 'Rever custos →',
        measure: 'Compara a percentagem de custos no fim do mês.',
        lever: GuidanceLever.margin,
        gravidade: GravidadeRecomendacao.urgente,
      ),
    );
  }

  // Dívida a caminho de se tornar problema.
  for (final divida in dividas) {
    if (divida.dias >= diasDividaAtencao && divida.dias <= diasDividaUrgente) {
      resultado.add(
        Recommendation(
          id: 'divida-atencao',
          title: '${divida.nome} — ${divida.dias} dias sem pagar',
          explanation: 'Ainda não é urgente, mas a dívida está a envelhecer.',
          impact: 'Um lembrete agora evita que isto chegue a atraso grave.',
          quality: 'Calculado a partir das reservas e recebimentos',
          action: 'Abrir ficha →',
          measure: 'Confirma se o valor em dívida desceu depois de agires.',
          lever: GuidanceLever.cash,
          gravidade: GravidadeRecomendacao.atencao,
        ),
      );
      break;
    }
  }

  // A facturar bem abaixo do mesmo mês do ano passado.
  final homologa = _receitaHomologa(state, now);
  if (homologa != null && homologa >= receitaHomologaMinimaCents) {
    final esteMes = tesourariaDoMes(state, now).recebidoCents;
    final proporcao = esteMes / homologa * 100;
    if (proporcao < percentQuedaHomologa) {
      resultado.add(
        Recommendation(
          id: 'queda-homologa',
          title:
              'A facturar ${proporcao.round()}% do que fizeste em '
              '${_nomesDosMeses[now.month - 1]} do ano passado',
          explanation:
              'A faturação deste mês está bem abaixo do mesmo mês do ano '
              'passado.',
          impact:
              'Perceber a causa agora — menos leads, menos máquinas '
              'disponíveis, preço — evita repetir o mês.',
          quality: 'Comparação com recebimentos ou histórico declarado',
          action: 'Ver homóloga →',
          measure:
              'Compara a faturação deste mês com o mesmo mês, no fim do mês.',
          lever: GuidanceLever.demand,
          gravidade: GravidadeRecomendacao.atencao,
        ),
      );
    }
  }

  // A converter bem: hora de pedir referências.
  final taxa = funilProcura(state, now, 30).taxa;
  if (taxa != null && taxa >= taxaConversaoBoa) {
    resultado.add(
      Recommendation(
        id: 'conversao-boa',
        title:
            'Conversão a 30 dias em ${taxa.round()}% — pede referências aos '
            'últimos clientes',
        explanation: 'Estás a converter bem as leads em clientes.',
        impact:
            'É boa altura para pedir referências: quem ficou satisfeito '
            'agora lembra-se.',
        quality: 'Calculado sobre as leads e conversões dos últimos 30 dias',
        action: 'Ver conversão →',
        measure: 'Compara a taxa de conversão no próximo mês.',
        lever: GuidanceLever.demand,
        gravidade: GravidadeRecomendacao.oportunidade,
      ),
    );
  }

  return resultado;
}

/// A recomendação a mostrar: **uma**, não uma pilha.
///
/// Junta as regras genéricas ([GuidanceEngine]) com as específicas — dívida
/// por cliente, custos críticos, queda homóloga, boa conversão — salta as
/// que foram adiadas e ainda não voltaram, e escolhe a mais grave. Em
/// empate ganha quem vier primeiro na lista: por isso as específicas entram
/// antes das genéricas, e são elas que decidem quando as duas dizem a mesma
/// coisa com gravidades iguais.
///
/// Devolve `null` quando não há nada a dizer — melhor calar-se do que encher
/// o ecrã com conselho genérico.
Recommendation? recomendacaoDaSemana(
  OperationsState state,
  DateTime now, {
  Map<String, DateTime> adiadasAte = const {},
}) {
  final todas = <Recommendation>[
    ..._recomendacoesEspecificas(state, now),
    // 'pending' fica de fora: dispara sempre que há um cêntimo por receber,
    // sem olhar a dias nem a valor — 'divida-urgente' e 'divida-atencao'
    // fazem o mesmo trabalho com limiares a sério, e sem o filtro o genérico
    // ganhava sempre por ser sempre "urgente".
    ...GuidanceEngine()
        .evaluate(
          GuidanceInput(
            bookings: state.bookings,
            machines: state.machines,
            receipts: state.receipts,
            expenses: state.expenses,
            now: now,
          ),
        )
        .where((r) => r.id != 'pending'),
  ];
  Recommendation? melhor;
  for (final r in todas) {
    final ate = adiadasAte[r.id];
    if (ate != null && now.isBefore(ate)) continue;
    if (melhor == null ||
        r.gravidade.prioridade > melhor.gravidade.prioridade) {
      melhor = r;
    }
  }
  return melhor;
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
