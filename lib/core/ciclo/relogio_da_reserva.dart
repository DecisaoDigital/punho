import '../../domain/models/operations.dart';

/// **O relógio é que manda no estado de uma marcação, depois de ela começar.**
///
/// Pedido do César a 13 de Agosto de 2026: «o tempo actual é que diz e assume o
/// estado da encomenda. Se não foi editada, nem cancelada, considera-se que
/// avança para entrega, e avança para recolha no fim do período de tempo» — e,
/// a seguir: «só pode ter sido concluída quando foi instalada e recolhida, isso
/// é automático».
///
/// Antes disto, alguém tinha de empurrar a reserva por seis estados à mão. Uma
/// máquina entregue continuava a dizer «Confirmada» porque ninguém carregou no
/// botão, e o calendário mentia sobre o que estava na rua.
///
/// **Antes da entrega o relógio não manda.** Nessa janela ainda se combina o
/// preço e se espera o sim do cliente — «Pedido», «Proposta enviada» e
/// «Confirmada» continuam a valer, e são elas que enchem «A minha semana». O
/// relógio toma conta a partir do dia de início, não antes.
///
/// **Cancelada é intocável.** É a única coisa que uma pessoa decide, e o tempo
/// não a desfaz.
BookingStatus estadoPeloRelogio(Booking reserva, DateTime agora) {
  if (reserva.status == BookingStatus.cancelled) return reserva.status;
  if (!agora.isBefore(reserva.endsAt)) return BookingStatus.completed;
  if (!agora.isBefore(reserva.startsAt)) return BookingStatus.rented;
  return reserva.status;
}

/// As marcações que o relógio tem de mexer — só essas.
///
/// Devolve lista vazia quando não há nada a fazer, que é o caso comum: quem
/// chama isto grava apenas o que vem aqui dentro, e uma lista vazia não gera
/// escrita nenhuma nem operação nenhuma para sincronizar.
List<Booking> reservasAAvancar(Iterable<Booking> reservas, DateTime agora) {
  final mexidas = <Booking>[];
  for (final reserva in reservas) {
    final devido = estadoPeloRelogio(reserva, agora);
    if (devido != reserva.status) {
      mexidas.add(reserva.copyWith(status: devido));
    }
  }
  return mexidas;
}
