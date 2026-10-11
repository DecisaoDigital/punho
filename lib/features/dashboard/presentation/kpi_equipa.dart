import 'package:flutter/material.dart';

import '../../../core/kpis/desempenho_da_equipa.dart';
import '../../../core/operations/operations_controller.dart';
import 'widgets/celula_semaforo.dart';
import 'widgets/grafico_de_barras.dart';
import 'widgets/grelha_com_graficos.dart';

/// **O ecrã «Colaboradores»**: quem cobra e quem angaria. Os números vêm de
/// [desempenhoDaEquipa]; aqui só se desenham.

String _euros(int cents) => (cents / 100).round().toString();

String _primeiroNome(String nome) => nome.trim().split(' ').first;

CelulaSemaforo kpiQuemMaisCobrou(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  final c = e.quemMaisCobrou;
  if (c == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Quem mais cobrou',
      texto: 'Ainda ninguém cobrou este mês',
      subtexto: 'Cada recebimento guarda quem o registou',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Quem mais cobrou',
    valor: c.nome,
    valorEmDestaque: true,
    subtexto:
        '${_euros(c.cobradoCents)} € cobrados · '
        '${(c.cobradoCents * 100 / e.cobradoCents).round()}% do total',
  );
}

CelulaSemaforo kpiQuemMaisAngariou(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  final c = e.quemMaisAngariou;
  if (c == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Quem mais angariou',
      texto: 'Ainda ninguém angariou este mês',
      subtexto: 'Os contactos criados por um colaborador ficam no nome dele',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Quem mais angariou',
    valor: c.nome,
    valorEmDestaque: true,
    subtexto:
        '${c.contactos} ${c.contactos == 1 ? 'contacto' : 'contactos'}, '
        '${c.clientes} ${c.clientes == 1 ? 'virou cliente' : 'viraram clientes'}',
  );
}

CelulaSemaforo kpiCobradoPorColaborador(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  final media = e.mediaCobradaCents;
  if (media == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Cobrado por colaborador',
      texto: 'Ainda ninguém cobrou este mês',
      subtexto: 'Cada recebimento guarda quem o registou',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Cobrado por colaborador',
    valor: _euros(media),
    unidade: '€ em média',
    valorEmDestaque: true,
    subtexto: 'Entre ${e.porCobrado.length} colaboradores com movimento',
  );
}

Widget graficoCobradoPorColaborador(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  return CartaoDeGrafico(
    child: GraficoDeBarras(
      titulo: 'Dinheiro cobrado por colaborador',
      legenda: 'euros cobrados este mês',
      cor: const Color(0xFF639922),
      vazio: 'Ainda ninguém cobrou este mês.',
      barras: [
        for (final c in e.porCobrado.take(6))
          BarraDoGrafico(
            _primeiroNome(c.nome),
            c.cobradoCents.toDouble(),
            '${_euros(c.cobradoCents)} €',
          ),
      ],
    ),
  );
}

Widget graficoAngariadosPorColaborador(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  return CartaoDeGrafico(
    child: GraficoDeBarras(
      titulo: 'Contactos angariados por colaborador',
      legenda: 'contactos este mês',
      cor: const Color(0xFF1D9A8C),
      vazio: 'Ainda ninguém angariou este mês.',
      barras: [
        for (final c in e.porAngariado.take(6))
          BarraDoGrafico(
            _primeiroNome(c.nome),
            c.contactos.toDouble(),
            '${c.contactos}',
          ),
      ],
    ),
  );
}

CelulaSemaforo kpiGraficoCobrado(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  if (e.porCobrado.isEmpty) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gráfico · Cobrado por colaborador',
      texto: 'Ainda sem cobranças para desenhar',
      subtexto: 'Cada recebimento guarda quem o registou.',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Gráfico · Cobrado por colaborador',
    texto: '${e.porCobrado.length} colaboradores a cobrar',
    subtexto: 'O primeiro: ${e.porCobrado.first.nome}',
  );
}

CelulaSemaforo kpiGraficoAngariados(OperationsState estado, DateTime now) {
  final e = desempenhoDaEquipa(estado, now);
  if (e.porAngariado.isEmpty) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gráfico · Contactos por colaborador',
      texto: 'Ainda sem contactos para desenhar',
      subtexto: 'Os contactos criados por um colaborador ficam no nome dele.',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Gráfico · Contactos por colaborador',
    texto: '${e.porAngariado.length} colaboradores a angariar',
    subtexto: 'O primeiro: ${e.porAngariado.first.nome}',
  );
}
