/// **Qual é a máquina que não está a dar dinheiro.**
///
/// A «Utilização vs Rentabilidade» diz que a frota está a 38% — e depois? O
/// gestor tem de ir à lista das máquinas descobrir sozinho qual delas é que
/// está parada. Uma percentagem não se telefona a ninguém; um nome sim.
///
/// Por isso este KPI é **filho** daquele: é a mesma pergunta, um degrau abaixo,
/// e é onde a cadeia paga o que promete.
///
/// ## O que conta como parada
///
/// Dias desde o fim do último trabalho. Uma máquina que está alugada hoje tem
/// zero e sai da conta — mesmo que o trabalho anterior tenha acabado há meses,
/// porque hoje está a render.
///
/// **A oficina fica de fora.** Uma máquina em manutenção também não rende, mas
/// já se sabe porquê e já está em obra: metê-la aqui era encher o único lugar
/// desta célula com a notícia que o gestor menos precisa. Este número é para as
/// que estão disponíveis e ninguém aluga.
///
/// **Uma máquina que nunca foi alugada só entra se souber quando foi comprada.**
/// Sem `acquiredOn` não há data de onde contar, e um KPI que se mede em dias não
/// pode ter uma linha sem dias — inventar o dia da compra era pintar de vermelho
/// uma ficha que só está incompleta.
library;

import '../../domain/models/operations.dart';
import '../operations/operations_controller.dart';

/// Duas semanas sem sair é o ponto a partir do qual vale a pena olhar.
const diasParaMaquinaParada = 14;

/// Um mês inteiro sem sair já não é uma pausa entre trabalhos.
const diasParaMaquinaMuitoParada = 30;

/// A máquina que está há mais tempo sem trabalhar.
class MaquinaParada {
  const MaquinaParada({
    required this.maquina,
    required this.dias,
    required this.desde,
    required this.nuncaAlugada,
    required this.voltaASair,
    required this.outrasParadas,
  });

  final Machine maquina;
  final int dias;

  /// O fim do último trabalho — ou o dia da compra, se nunca teve nenhum.
  final DateTime desde;
  final bool nuncaAlugada;

  /// A próxima reserva marcada, se já houver. **Muda a leitura**: 20 dias
  /// parada com trabalho marcado para sexta é uma folga; 20 dias parada e a
  /// agenda vazia é um activo a pagar-se a si próprio sem ninguém o usar.
  final DateTime? voltaASair;

  /// Quantas outras estão paradas há pelo menos [diasParaMaquinaParada]. Uma
  /// máquina parada é uma máquina; quatro é uma frota grande de mais.
  final int outrasParadas;

  bool get muitoParada => dias >= diasParaMaquinaMuitoParada;

  /// Ao preço de tabela, o que estes dias não facturaram. `null` sem preço/dia
  /// na ficha.
  ///
  /// **É uma ordem de grandeza, e assume-se que é.** Pressupõe que havia
  /// procura para todos os dias, e nem sempre há. Mas «23 dias × 185 €» é uma
  /// conta que ele confirma de cabeça em dois segundos, e um número aproximado
  /// e marcado como tal vale mais do que um espaço em branco.
  int? get naoFacturadoCents {
    final preco = maquina.dailyRateCents;
    return preco == null ? null : preco * dias;
  }
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Há frota e há operação — ou seja, faz sentido perguntar isto.
///
/// Sem uma reserva sequer, todas as máquinas estão «paradas» desde sempre e o
/// número não diria nada sobre o negócio, só sobre a app estar vazia.
bool haFrotaParaVigiar(OperationsState estado) =>
    estado.bookings.isNotEmpty &&
    estado.machines.any((m) => !m.archived && _rende(m));

/// Máquinas de que se espera receita hoje. A oficina e as retiradas não contam.
bool _rende(Machine m) =>
    m.status != MachineStatus.maintenance && m.status != MachineStatus.stopped;

/// A máquina parada há mais tempo, ou `null` se não houver nenhuma parada — que
/// é a boa notícia, e não uma falta de dados.
MaquinaParada? maquinaMaisParada(OperationsState estado, DateTime now) {
  final hoje = _dia(now);

  final trabalhos = [
    for (final b in estado.bookings)
      if (b.status != BookingStatus.cancelled) b,
  ];

  final paradas = <MaquinaParada>[];
  for (final maquina in estado.machines) {
    if (maquina.archived || !_rende(maquina)) continue;

    final dela = [
      for (final b in trabalhos)
        if (b.machineIds.contains(maquina.id)) b,
    ];

    // A trabalhar hoje: está a render, e é o que se queria.
    final ocupadaHoje = dela.any(
      (b) => !_dia(b.startsAt).isAfter(hoje) && !_dia(b.endsAt).isBefore(hoje),
    );
    if (ocupadaHoje) continue;

    DateTime? ultimoFim;
    DateTime? proximoInicio;
    for (final b in dela) {
      final fim = _dia(b.endsAt);
      if (fim.isBefore(hoje) && (ultimoFim == null || fim.isAfter(ultimoFim))) {
        ultimoFim = fim;
      }
      final inicio = _dia(b.startsAt);
      if (inicio.isAfter(hoje) &&
          (proximoInicio == null || inicio.isBefore(proximoInicio))) {
        proximoInicio = inicio;
      }
    }

    // Nunca trabalhou: conta-se da compra, e só se ela estiver na ficha.
    final desde =
        ultimoFim ??
        (maquina.acquiredOn == null ? null : _dia(maquina.acquiredOn!));
    if (desde == null) continue;

    final dias = hoje.difference(desde).inDays;
    if (dias <= 0) continue;

    paradas.add(
      MaquinaParada(
        maquina: maquina,
        dias: dias,
        desde: desde,
        nuncaAlugada: ultimoFim == null,
        voltaASair: proximoInicio,
        outrasParadas: 0,
      ),
    );
  }
  if (paradas.isEmpty) return null;

  var pior = paradas.first;
  for (final p in paradas) {
    if (p.dias > pior.dias) pior = p;
  }

  final acompanhadas = paradas
      .where((p) => p.maquina.id != pior.maquina.id)
      .where((p) => p.dias >= diasParaMaquinaParada)
      .length;

  return MaquinaParada(
    maquina: pior.maquina,
    dias: pior.dias,
    desde: pior.desde,
    nuncaAlugada: pior.nuncaAlugada,
    voltaASair: pior.voltaASair,
    outrasParadas: acompanhadas,
  );
}
