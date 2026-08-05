/// O motor do ciclo: dado um trabalho e uma data, qual é o **próximo passo**.
///
/// **Porque existe.** O Punho tinha o ciclo todo escrito nos estados —
/// `request → proposalSent → confirmed → rented → completed` — e nenhum ecrã o
/// usava para nada. Os estados eram uma etiqueta colorida no calendário: diziam
/// onde o trabalho está, nunca o que falta fazer. Quem sabia o que fazer a
/// seguir era o gestor, de cabeça, e por isso era ele o sítio onde as coisas se
/// perdiam.
///
/// **A regra que este ficheiro serve** (regra 3 do `docs/PLANO_DO_CICLO.md`):
/// nunca existe um trabalho sem próximo passo visível. Se algum estado não
/// souber dizer o que fazer a seguir, o estado está mal desenhado — e é aqui
/// que isso aparece, porque é aqui que o `switch` fica sem resposta.
///
/// É Dart puro, sem Flutter: o ciclo é uma regra de negócio, não um ecrã.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../format/campos.dart';
import '../operations/operations_controller.dart';

/// Quão em cima é o passo. É por aqui que a lista se ordena — não por data.
///
/// Ordenar por data punha um pedido para daqui a três semanas por cima de uma
/// máquina que devia ter sido entregue ontem.
enum Urgencia {
  /// Devia ter acontecido e não aconteceu.
  atrasado,

  /// É para hoje.
  hoje,

  /// Está a chegar, dentro do horizonte da semana.
  aCaminho,
}

/// O que o botão faz quando é tocado.
enum AccaoDoPasso {
  /// Move o trabalho para [ProximoPasso.estadoSeguinte].
  avancarEstado,

  /// Abre o formulário para dizer quanto valeu o trabalho.
  declararValor,

  /// Abre o registo de recebimento, já apontado a este trabalho.
  registarRecebimento,
}

class ProximoPasso {
  const ProximoPasso({
    required this.verbo,
    required this.porque,
    required this.urgencia,
    required this.accao,
    this.estadoSeguinte,
    this.valorEmFaltaCents,
  });

  /// O botão. Começa sempre por um verbo — "Enviar orçamento", não
  /// "Orçamento". Um substantivo obriga a adivinhar o que vai acontecer.
  final String verbo;

  /// A linha por baixo do nome do cliente: porque é que isto está na lista
  /// hoje. Sem ela, a lista é uma acusação sem prova.
  final String porque;

  final Urgencia urgencia;
  final AccaoDoPasso accao;
  final BookingStatus? estadoSeguinte;

  /// Quanto falta receber, quando [accao] é [AccaoDoPasso.registarRecebimento].
  final int? valorEmFaltaCents;
}

/// Um trabalho e o que fazer com ele. É o que a lista mostra.
class TrabalhoComPasso {
  const TrabalhoComPasso(this.trabalho, this.passo, this.dataRelevante);
  final Booking trabalho;
  final ProximoPasso passo;

  /// A data por que este trabalho se ordena dentro da mesma urgência: a de
  /// início enquanto não arrancou, a de fim depois de arrancar.
  final DateTime dataRelevante;
}

DateTime _dia(DateTime valor) => DateTime(valor.year, valor.month, valor.day);

int _diasAte(DateTime alvo, DateTime hoje) =>
    _dia(alvo).difference(_dia(hoje)).inDays;

String _euros(int cents) => '${textoDeCents(cents)} €';

/// Quantos dias para diante ainda cabem em "a minha semana".
const horizonteDaSemana = 7;

/// A urgência de uma data que devia estar cumprida: passou, é hoje, ou vem aí.
Urgencia _urgenciaDe(DateTime alvo, DateTime hoje) {
  final dias = _diasAte(alvo, hoje);
  if (dias < 0) return Urgencia.atrasado;
  if (dias == 0) return Urgencia.hoje;
  return Urgencia.aCaminho;
}

/// "1 dia", "3 dias". Um plural mal feito num ecrã que se lê todos os dias
/// desgasta a confiança em tudo o resto que lá está escrito.
String _dias(int quantos) => quantos == 1 ? '1 dia' : '$quantos dias';

String _quando(DateTime data, DateTime hoje) {
  final dias = _diasAte(data, hoje);
  if (dias == 0) return 'hoje';
  if (dias == 1) return 'amanhã';
  if (dias == -1) return 'ontem';
  if (dias < 0) return 'há ${_dias(dias.abs())}';
  return 'daqui a ${_dias(dias)}';
}

/// O próximo passo de um trabalho — ou `null` quando não há nada a fazer.
///
/// `null` quer dizer duas coisas, ambas legítimas: o trabalho foi cancelado, ou
/// está fechado e pago. Nos dois casos sai da lista, que é o objectivo — uma
/// lista que nunca esvazia deixa de se ler.
ProximoPasso? proximoPassoDe(
  Booking trabalho, {
  required DateTime hoje,
  required Iterable<Receipt> recebimentos,
}) {
  switch (trabalho.status) {
    case BookingStatus.cancelled:
      return null;

    case BookingStatus.request:
      return ProximoPasso(
        verbo: 'Enviar orçamento',
        porque:
            'Pedido para ${_quando(trabalho.startsAt, hoje)}, ainda sem '
            'orçamento.',
        urgencia: _urgenciaDe(trabalho.startsAt, hoje),
        accao: AccaoDoPasso.avancarEstado,
        estadoSeguinte: BookingStatus.proposalSent,
      );

    case BookingStatus.proposalSent:
      return ProximoPasso(
        verbo: 'Confirmar',
        porque:
            'Orçamento enviado, resposta por dar. Começa '
            '${_quando(trabalho.startsAt, hoje)}.',
        urgencia: _urgenciaDe(trabalho.startsAt, hoje),
        accao: AccaoDoPasso.avancarEstado,
        estadoSeguinte: BookingStatus.confirmed,
      );

    case BookingStatus.confirmed:
      return ProximoPasso(
        verbo: 'Entregar',
        porque: 'Confirmado. Entrega ${_quando(trabalho.startsAt, hoje)}.',
        urgencia: _urgenciaDe(trabalho.startsAt, hoje),
        accao: AccaoDoPasso.avancarEstado,
        estadoSeguinte: BookingStatus.rented,
      );

    case BookingStatus.rented:
      // Aqui a data que manda é a do fim: a máquina está fora, e o que falta é
      // trazê-la de volta.
      return ProximoPasso(
        verbo: 'Fechar trabalho',
        porque: 'Em curso. Devolução ${_quando(trabalho.endsAt, hoje)}.',
        urgencia: _urgenciaDe(trabalho.endsAt, hoje),
        accao: AccaoDoPasso.avancarEstado,
        estadoSeguinte: BookingStatus.completed,
      );

    case BookingStatus.completed:
      final esperado = trabalho.expectedValueCents;
      // Um trabalho fechado sem valor é o buraco mais caro que a app tem: não
      // entra na receita, não entra na margem, e ninguém dá por isso porque o
      // trabalho parece arrumado. Perguntar aqui é o momento certo — acabou de
      // acontecer e a memória ainda é fresca.
      if (esperado == null || esperado <= 0) {
        return const ProximoPasso(
          verbo: 'Dizer quanto valeu',
          porque:
              'Trabalho fechado sem valor. Sem ele não conta para a '
              'receita nem para a margem.',
          urgencia: Urgencia.hoje,
          accao: AccaoDoPasso.declararValor,
        );
      }
      final falta = bookingPendingCents(esperado, trabalho.id, recebimentos);
      if (falta <= 0) return null;
      final dias = -_diasAte(trabalho.endsAt, hoje);
      return ProximoPasso(
        verbo: 'Registar recebimento',
        porque: dias > 0
            ? 'Faltam ${_euros(falta)} de ${_euros(esperado)}, fechado há '
                  '${_dias(dias)}.'
            : 'Faltam ${_euros(falta)} de ${_euros(esperado)}.',
        // Dívida com mais de 30 dias deixa de ser "a receber" e passa a ser um
        // problema: é o intervalo a partir do qual a probabilidade de cobrança
        // começa a cair depressa.
        urgencia: dias > 30 ? Urgencia.atrasado : Urgencia.hoje,
        accao: AccaoDoPasso.registarRecebimento,
        valorEmFaltaCents: falta,
      );
  }
}

/// Tudo o que precisa do gestor, pela ordem por que precisa.
///
/// **O que entra e o que não entra.** O que ainda não está resolvido — pedidos
/// e orçamentos — entra sempre, seja a data que for: um pedido para o mês que
/// vem precisa de orçamento hoje. O que está confirmado só entra dentro do
/// [horizonteDaSemana], senão a lista enche-se de trabalho que não é para já. O
/// que está em curso entra sempre, porque há uma máquina fora de casa. E o que
/// está fechado entra enquanto faltar valor ou dinheiro.
List<TrabalhoComPasso> aMinhaSemana(OperationsState state, DateTime hoje) {
  final lista = <TrabalhoComPasso>[];
  for (final trabalho in state.bookings) {
    final passo = proximoPassoDe(
      trabalho,
      hoje: hoje,
      recebimentos: state.receipts,
    );
    if (passo == null) continue;
    final dataRelevante = switch (trabalho.status) {
      BookingStatus.rented || BookingStatus.completed => trabalho.endsAt,
      _ => trabalho.startsAt,
    };
    final foraDoHorizonte =
        trabalho.status == BookingStatus.confirmed &&
        _diasAte(trabalho.startsAt, hoje) > horizonteDaSemana;
    if (foraDoHorizonte) continue;
    lista.add(TrabalhoComPasso(trabalho, passo, dataRelevante));
  }
  lista.sort((a, b) {
    final porUrgencia = a.passo.urgencia.index.compareTo(
      b.passo.urgencia.index,
    );
    if (porUrgencia != 0) return porUrgencia;
    return a.dataRelevante.compareTo(b.dataRelevante);
  });
  return lista;
}

/// Quantos trabalhos estão atrasados. É o número que vai ao emblema da barra.
int atrasadosNaSemana(OperationsState state, DateTime hoje) => aMinhaSemana(
  state,
  hoje,
).where((item) => item.passo.urgencia == Urgencia.atrasado).length;
