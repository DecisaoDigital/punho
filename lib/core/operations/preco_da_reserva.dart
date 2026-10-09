/// **Quanto vale uma reserva à tabela.**
///
/// O preço/dia da máquina é perguntado no cadastro e depois não servia para
/// nada: o campo "Valor previsto" da reserva nascia em branco e cada marcação
/// obrigava a fazer a conta de cabeça. O César, a 10 de Agosto de 2026: «se o
/// valor diário de aluguer foi perguntado e preenchido, porque é que na reserva
/// aparece Valor previsto?? ainda por cima em branco, quando podia vir já com a
/// conta feita mesmo podendo ser editado!».
///
/// Isto é a conta feita. Continua a ser uma **proposta** — o campo é editável e
/// quem fecha o preço é quem vende.
library;

import '../../domain/models/operations.dart';

/// Quantos dias de aluguer há entre [startsAt] e [endsAt].
///
/// Não é `inDays`. O formulário de reserva trabalha em meios-dias — a manhã vai
/// das 00:00 às 12:00, a tarde das 12:00 às 00:00 do dia seguinte — e `inDays`
/// arredonda meio dia para zero, que daria uma reserva de manhã a valer nada.
/// A unidade é o dia de 24 horas, e meio dia é meio.
double diasDeAluguer(DateTime startsAt, DateTime endsAt) {
  final minutos = endsAt.difference(startsAt).inMinutes;
  return minutos <= 0 ? 0 : minutos / (60 * 24);
}

/// Quanto custa alugar [dias] dias com esta tabela: o conjunto de pacotes mais
/// barato que **cobre** esses dias (pode sobrar). `null` sem tabela.
///
/// Ex.: com 1 dia 80 €, 3 dias 140 € e 30 dias 500 €, 2 dias custam 140 € (um
/// pacote de 3, mais barato que dois de 1) e 31 dias custam 580 € (mês + dia).
int? precoDaTabelaPorPeriodo(List<Tarifa> tabela, int dias) {
  final validas = tabela.where((t) => t.dias > 0 && t.cents > 0).toList();
  if (validas.isEmpty || dias <= 0) return null;
  final custo = List<int>.filled(dias + 1, 0);
  for (var i = 1; i <= dias; i++) {
    var melhor = 1 << 60;
    for (final t in validas) {
      final resto = i - t.dias;
      final c = t.cents + custo[resto < 0 ? 0 : resto];
      if (c < melhor) melhor = c;
    }
    custo[i] = melhor;
  }
  return custo[dias];
}

/// O valor à tabela de [maquinas] no período, ou `null` quando não há tabela.
///
/// `null` quer dizer «não sei», e é o que deixa o campo em branco: uma máquina
/// sem preço/dia não pode ser transformada num zero, que passaria por um preço
/// combinado. Basta uma das máquinas não ter preço para o total deixar de ser
/// de confiar — o que se dissesse seria menos do que a verdade.
int? valorPrevistoDaTabela(
  Iterable<Machine> maquinas,
  DateTime startsAt,
  DateTime endsAt,
) {
  final lista = maquinas.toList();
  if (lista.isEmpty) return null;
  final dias = diasDeAluguer(startsAt, endsAt);
  if (dias <= 0) return null;
  var total = 0.0;
  for (final maquina in lista) {
    // Tabela por período manda; sem ela vale o preço diário.
    final porPeriodo = precoDaTabelaPorPeriodo(maquina.tarifas, dias.ceil());
    if (porPeriodo != null) {
      total += porPeriodo;
      continue;
    }
    final preco = maquina.dailyRateCents;
    if (preco == null || preco <= 0) return null;
    total += preco * dias;
  }
  return total.round();
}

/// O mesmo valor já escrito como o campo o quer: `1500.00`, ponto decimal,
/// porque é isso que o [TextEditingController] do formulário recebe e o
/// `centsDeTexto` volta a ler. Vazio quando não há tabela.
String textoDoValorPrevisto(
  Iterable<Machine> maquinas,
  DateTime startsAt,
  DateTime endsAt,
) {
  final cents = valorPrevistoDaTabela(maquinas, startsAt, endsAt);
  return cents == null ? '' : (cents / 100).toStringAsFixed(2);
}
