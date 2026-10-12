// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/kpis.dart';
import '../operations/operations_controller.dart';

/// Um ponto de um gráfico de barras: o nome, o valor e (opcional) o texto.
class PontoDeSerie {
  const PontoDeSerie(this.nome, this.valor, [this.texto]);

  final String nome;
  final double valor;
  final String? texto;
}

const _mesesCurtos = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez', //
];

/// Inteiro com espaço (não separável) a separar os milhares: 12 708.
String inteiroComMilhares(int n) {
  final d = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write('\u00A0');
    b.write(d[i]);
  }
  return b.toString();
}

String euros(int cents) => '${inteiroComMilhares((cents / 100).round())} €';

DateTime _mes(DateTime d, int delta) => DateTime(d.year, d.month + delta);
bool _noMes(DateTime d, DateTime mes) =>
    d.year == mes.year && d.month == mes.month;

/// Os últimos [n] meses, do mais antigo ao mês de [now].
List<DateTime> ultimosMeses(DateTime now, [int n = 6]) => [
  for (var i = n - 1; i >= 0; i--) _mes(now, -i),
];

String nomeDoMes(DateTime m) => _mesesCurtos[m.month - 1];

int _recebidoNoMes(OperationsState s, DateTime mes) => s.receipts
    .where((r) => !r.archived && _noMes(r.date, mes))
    .fold(0, (t, r) => t + r.amountCents);

int _pagoNoMes(OperationsState s, DateTime mes) => s.expenses
    .where(
      (e) =>
          !e.archived &&
          e.status == ExpensePaymentStatus.paid &&
          _noMes(e.date, mes),
    )
    .fold(0, (t, e) => t + e.amountCents);

/// Entrou e saiu em cada um dos últimos 6 meses (o que saiu é o já pago).
List<({DateTime mes, int entrou, int saiu})> entrouVsSaiu(
  OperationsState s,
  DateTime now,
) => [
  for (final m in ultimosMeses(now))
    (mes: m, entrou: _recebidoNoMes(s, m), saiu: _pagoNoMes(s, m)),
];

/// O que está por receber, por idade: ainda não venceu, até 30, 31–60, 61+.
List<PontoDeSerie> aReceberPorAntiguidade(OperationsState s, DateTime now) {
  final faixas = [0, 0, 0, 0];
  for (final c in cobrancasPorReceber(s, now)) {
    final d = c.diasDeAtraso;
    faixas[d == 0 ? 0 : (d <= 30 ? 1 : (d <= 60 ? 2 : 3))] += c.emDividaCents;
  }
  const nomes = ['Em prazo', '1–30 dias', '31–60 dias', '+60 dias'];
  return [
    for (var i = 0; i < 4; i++)
      PontoDeSerie(nomes[i], faixas[i].toDouble(), euros(faixas[i])),
  ];
}

/// Os 5 clientes que mais pagaram no ano de [now].
List<PontoDeSerie> receitaPorCliente(OperationsState s, DateTime now) {
  final por = <String, int>{};
  for (final r in s.receipts) {
    if (r.archived || r.date.year != now.year) continue;
    por[r.customerId] = (por[r.customerId] ?? 0) + r.amountCents;
  }
  final nomes = {for (final c in s.customers) c.id: c.name};
  final ordem = por.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in ordem.take(5))
      PontoDeSerie(
        nomes[e.key] ?? 'Cliente',
        e.value.toDouble(),
        euros(e.value),
      ),
  ];
}

/// Clientes novos em cada um dos últimos 6 meses (pela data de registo).
List<PontoDeSerie> clientesNovosPorMes(OperationsState s, DateTime now) {
  final por = <int, int>{};
  for (final c in s.customers) {
    if (c.archived) continue;
    final d = c.createdAt ?? Customer.dataDoId(c.id);
    if (d == null) continue;
    por[d.year * 12 + d.month] = (por[d.year * 12 + d.month] ?? 0) + 1;
  }
  return [
    for (final m in ultimosMeses(now))
      PontoDeSerie(
        nomeDoMes(m),
        (por[m.year * 12 + m.month] ?? 0).toDouble(),
        '${por[m.year * 12 + m.month] ?? 0}',
      ),
  ];
}

/// Percentagem dos dias do mês (até hoje) em que cada máquina esteve reservada.
List<PontoDeSerie> ocupacaoPorMaquina(OperationsState s, DateTime now) {
  final inicio = DateTime(now.year, now.month);
  final hoje = DateTime(now.year, now.month, now.day);
  final dias = hoje.difference(inicio).inDays + 1;
  final ocupados = <String, Set<int>>{};
  for (final b in s.bookings) {
    if (b.status == BookingStatus.cancelled) continue;
    final a = DateTime(b.startsAt.year, b.startsAt.month, b.startsAt.day);
    final f = DateTime(b.endsAt.year, b.endsAt.month, b.endsAt.day);
    if (f.isBefore(inicio) || a.isAfter(hoje)) continue;
    final de = a.isBefore(inicio) ? inicio : a;
    final ate = f.isAfter(hoje) ? hoje : f;
    for (
      var d = de;
      !d.isAfter(ate);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      for (final m in b.machineIds) {
        (ocupados[m] ??= {}).add(d.day);
      }
    }
  }
  final pontos = [
    for (final m in s.machines)
      if (!m.archived)
        PontoDeSerie(
          m.name,
          (ocupados[m.id]?.length ?? 0) * 100 / dias,
          '${((ocupados[m.id]?.length ?? 0) * 100 / dias).round()}%',
        ),
  ]..sort((a, b) => b.valor.compareTo(a.valor));
  return pontos.take(6).toList();
}

/// Reservas que começaram em cada dia da semana nos últimos 90 dias.
List<PontoDeSerie> reservasPorDiaDaSemana(OperationsState s, DateTime now) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  final desde = now.subtract(const Duration(days: 90));
  final n = List<int>.filled(7, 0);
  for (final b in s.bookings) {
    if (b.status == BookingStatus.cancelled) continue;
    if (b.startsAt.isBefore(desde) || b.startsAt.isAfter(now)) continue;
    n[b.startsAt.weekday - 1]++;
  }
  return [
    for (var i = 0; i < 7; i++)
      PontoDeSerie(nomes[i], n[i].toDouble(), '${n[i]}'),
  ];
}

/// Despesas pagas no mês de [now], por categoria (as 6 maiores).
List<PontoDeSerie> despesasPorCategoria(OperationsState s, DateTime now) {
  final por = <String, int>{};
  for (final e in s.expenses) {
    if (e.archived ||
        e.status != ExpensePaymentStatus.paid ||
        !_noMes(e.date, now)) {
      continue;
    }
    final nome = expenseCategoryLabel(e.category);
    por[nome] = (por[nome] ?? 0) + e.amountCents;
  }
  final ordem = por.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in ordem.take(6))
      PontoDeSerie(e.key, e.value.toDouble(), euros(e.value)),
  ];
}

/// Despesa paga em cada um dos últimos 6 meses.
List<PontoDeSerie> despesaPorMes(OperationsState s, DateTime now) => [
  for (final m in ultimosMeses(now))
    PontoDeSerie(
      nomeDoMes(m),
      _pagoNoMes(s, m).toDouble(),
      euros(_pagoNoMes(s, m)),
    ),
];
