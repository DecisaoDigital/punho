// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'package:flutter/material.dart';

import '../../../core/kpis/origem_dos_clientes.dart';
import '../../../core/operations/operations_controller.dart';
import 'widgets/celula_semaforo.dart';
import 'widgets/grafico_de_barras.dart';
import 'widgets/grelha_com_graficos.dart';

/// **O ecrã «Origem dos clientes»**: de onde vêm os contactos e quantos fecham.
/// Os números vêm de [origemDosClientes]; aqui só se desenham.

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

DateTime _mesAnterior(DateTime d) => DateTime(d.year, d.month - 1);

CelulaSemaforo kpiContactosNovos(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  if (o.contactos == 0) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Contactos novos',
      texto: 'Sem contactos este mês',
      subtexto: 'Regista quem te procura e o número aparece',
    );
  }
  final antes = origemDosClientes(estado, _mesAnterior(now)).contactos;
  final nome = _meses[_mesAnterior(now).month - 1];
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Contactos novos',
    valor: '${o.contactos}',
    unidade: 'este mês',
    valorEmDestaque: true,
    subtexto: antes == 0
        ? 'Pessoas que te procuraram ou que foste procurar'
        : '${o.contactos >= antes ? '▲' : '▼'} '
              '${(o.contactos - antes).abs()} face a $nome ($antes)',
  );
}

CelulaSemaforo kpiViraramClientes(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  final taxa = o.taxa;
  if (taxa == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Viraram clientes',
      texto: 'Sem contactos este mês',
      subtexto: 'Regista quem te procura',
    );
  }
  final antes = origemDosClientes(estado, _mesAnterior(now)).taxa;
  final delta = antes == null ? null : taxa - antes;
  return CelulaSemaforo(
    nivel: taxa >= 40
        ? NivelSemaforo.verde
        : taxa >= 20
        ? NivelSemaforo.laranja
        : NivelSemaforo.vermelho,
    rotulo: 'Viraram clientes',
    valor: '${taxa.round()}%',
    valorEmDestaque: true,
    subtexto: delta == null
        ? '${o.convertidos} de ${o.contactos} contactos'
        : '${o.convertidos} de ${o.contactos} · '
              '${delta >= 0 ? '▲' : '▼'} ${delta.abs().round()} pontos',
  );
}

CelulaSemaforo kpiMelhorCanal(OperationsState estado, DateTime now) {
  final melhor = origemDosClientes(estado, now).melhor;
  if (melhor == null) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Melhor canal',
      texto: 'Ainda nenhum contacto virou cliente',
      subtexto: 'Quando um fechar, vês de onde veio',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.verde,
    rotulo: 'Melhor canal',
    valor: melhor.nome,
    valorEmDestaque: true,
    subtexto:
        '${melhor.contactos} contactos, ${melhor.convertidos} '
        '${melhor.convertidos == 1 ? 'virou cliente' : 'viraram clientes'}',
  );
}

Widget graficoContactosPorOrigem(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  return CartaoDeGrafico(
    child: GraficoDeBarras(
      titulo: 'De onde vêm os contactos · ${_meses[now.month - 1]}',
      legenda: 'número de contactos',
      cor: const Color(0xFF639922),
      vazio: 'Ainda sem contactos este mês.',
      barras: [
        for (final c in o.canais)
          BarraDoGrafico(c.nome, c.contactos.toDouble(), '${c.contactos}'),
      ],
    ),
  );
}

Widget graficoConversaoPorCanal(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  final canais = [...o.canais]
    ..sort((a, b) => (b.taxa ?? 0).compareTo(a.taxa ?? 0));
  return CartaoDeGrafico(
    child: GraficoDeBarras(
      titulo: 'Quantos viram clientes · por canal',
      legenda: '% que fechou',
      cor: const Color(0xFF1D9A8C),
      vazio: 'Ainda sem contactos este mês.',
      barras: [
        for (final c in canais)
          BarraDoGrafico(c.nome, c.taxa ?? 0, '${(c.taxa ?? 0).round()}%'),
      ],
    ),
  );
}

/// O resumo do gráfico na lista dos KPIs.
CelulaSemaforo kpiGraficoContactos(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  if (o.contactos == 0) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gráfico · De onde vêm os contactos',
      texto: 'Ainda sem contactos para desenhar',
      subtexto: 'Regista quem te procura e as barras aparecem.',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Gráfico · De onde vêm os contactos',
    texto: '${o.canais.length} canais este mês',
    subtexto: 'O maior: ${o.canais.first.nome} (${o.canais.first.contactos})',
  );
}

CelulaSemaforo kpiGraficoConversao(OperationsState estado, DateTime now) {
  final o = origemDosClientes(estado, now);
  if (o.contactos == 0) {
    return const CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gráfico · Conversão por canal',
      texto: 'Ainda sem contactos para desenhar',
      subtexto: 'Regista quem te procura e as barras aparecem.',
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Gráfico · Conversão por canal',
    texto: '${o.convertidos} de ${o.contactos} viraram clientes',
    subtexto: 'Por canal, o que fechou',
  );
}
