import 'package:flutter/material.dart';

import '../../../core/kpis/series_para_graficos.dart';
import '../../../core/operations/operations_controller.dart';
import 'widgets/celula_semaforo.dart';
import 'widgets/grafico_de_barras.dart';
import 'widgets/grelha_com_graficos.dart';

/// Os gráficos dos ecrãs Dinheiro a mexer, Clientes, Máquinas e Despesas
/// (11 Out 2026). Os números vêm de `series_para_graficos.dart`.

typedef _Serie = List<PontoDeSerie> Function(OperationsState, DateTime);

Widget _barras(
  OperationsState s,
  DateTime now, {
  required _Serie serie,
  required String titulo,
  required String legenda,
  required Color cor,
  required String vazio,
}) => CartaoDeGrafico(
  child: GraficoDeBarras(
    titulo: titulo,
    legenda: legenda,
    cor: cor,
    vazio: vazio,
    barras: [
      for (final p in serie(s, now))
        BarraDoGrafico(p.nome, p.valor, p.texto ?? p.valor.round().toString()),
    ],
  ),
);

/// O resumo do gráfico na lista dos KPIs: informativo, ou «aguarda» sem dados.
CelulaSemaforo _resumo(
  OperationsState s,
  DateTime now,
  _Serie serie, {
  required String rotulo,
  required String vazio,
  required String Function(List<PontoDeSerie>) texto,
  required String subtexto,
}) {
  final pontos = serie(s, now);
  if (pontos.every((p) => p.valor <= 0)) {
    return CelulaSemaforo(
      nivel: NivelSemaforo.aguarda,
      rotulo: 'Gráfico · $rotulo',
      texto: 'Ainda sem dados para desenhar',
      subtexto: vazio,
    );
  }
  return CelulaSemaforo(
    nivel: NivelSemaforo.informativo,
    rotulo: 'Gráfico · $rotulo',
    texto: texto(pontos),
    subtexto: subtexto,
  );
}

PontoDeSerie _maior(List<PontoDeSerie> p) =>
    p.reduce((a, b) => b.valor > a.valor ? b : a);

// --- Entrou vs saiu --------------------------------------------------------

List<PontoDeSerie> _serieEntrouSaiu(OperationsState s, DateTime now) => [
  for (final m in entrouVsSaiu(s, now))
    PontoDeSerie(
      nomeDoMes(m.mes),
      m.entrou.toDouble(),
      'entrou ${euros(m.entrou)} · saiu ${euros(m.saiu)}',
    ),
];

Widget graficoEntrouVsSaiu(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: _serieEntrouSaiu,
  titulo: 'Entrou vs saiu · últimos 6 meses',
  legenda: 'a barra é o que entrou',
  cor: const Color(0xFF4DA3FF),
  vazio: 'Ainda sem recebimentos.',
);

CelulaSemaforo kpiGraficoEntrouVsSaiu(OperationsState s, DateTime now) =>
    _resumo(
      s,
      now,
      _serieEntrouSaiu,
      rotulo: 'Entrou vs saiu',
      vazio: 'Regista recebimentos e despesas.',
      texto: (_) => 'Seis meses lado a lado',
      subtexto: 'O que entrou e o que já saiu, mês a mês.',
    );

// --- A receber por antiguidade ----------------------------------------------

Widget graficoAReceberPorAntiguidade(OperationsState s, DateTime now) =>
    _barras(
      s,
      now,
      serie: aReceberPorAntiguidade,
      titulo: 'A receber · por antiguidade',
      legenda: 'euros por receber',
      cor: const Color(0xFFE08A00),
      vazio: 'Nada por receber.',
    );

CelulaSemaforo kpiGraficoAReceber(OperationsState s, DateTime now) => _resumo(
  s,
  now,
  aReceberPorAntiguidade,
  rotulo: 'A receber por antiguidade',
  vazio: 'Quando houver dívidas, vês há quanto tempo estão.',
  texto: (p) => 'O maior: ${_maior(p).nome}',
  subtexto: 'Quanto mais antigo, mais difícil de cobrar.',
);

// --- Receita por cliente ------------------------------------------------------

Widget graficoReceitaPorCliente(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: receitaPorCliente,
  titulo: 'Quem mais pagou · ${now.year}',
  legenda: 'euros recebidos',
  cor: const Color(0xFF639922),
  vazio: 'Ainda sem recebimentos este ano.',
);

CelulaSemaforo kpiGraficoReceitaCliente(OperationsState s, DateTime now) =>
    _resumo(
      s,
      now,
      receitaPorCliente,
      rotulo: 'Receita por cliente',
      vazio: 'Regista recebimentos de clientes.',
      texto: (p) => 'O maior: ${_maior(p).nome}',
      subtexto: 'Os 5 clientes que mais pagaram este ano.',
    );

// --- Clientes novos por mês ----------------------------------------------------

Widget graficoClientesNovos(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: clientesNovosPorMes,
  titulo: 'Clientes novos · últimos 6 meses',
  legenda: 'clientes registados',
  cor: const Color(0xFF1D9A8C),
  vazio: 'Ainda sem clientes registados.',
);

CelulaSemaforo kpiGraficoClientesNovos(OperationsState s, DateTime now) =>
    _resumo(
      s,
      now,
      clientesNovosPorMes,
      rotulo: 'Clientes novos por mês',
      vazio: 'Regista clientes e as barras aparecem.',
      texto: (p) => 'Melhor mês: ${_maior(p).nome}',
      subtexto: 'Quantos clientes entraram em cada mês.',
    );

// --- Máquinas --------------------------------------------------------------------

Widget graficoOcupacaoPorMaquina(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: ocupacaoPorMaquina,
  titulo: 'Ocupação por máquina · este mês',
  legenda: '% dos dias reservada',
  cor: const Color(0xFF639922),
  vazio: 'Ainda sem reservas este mês.',
);

CelulaSemaforo kpiGraficoOcupacao(OperationsState s, DateTime now) => _resumo(
  s,
  now,
  ocupacaoPorMaquina,
  rotulo: 'Ocupação por máquina',
  vazio: 'Marca reservas e vês quanto cada máquina trabalha.',
  texto: (p) => 'Mais ocupada: ${_maior(p).nome}',
  subtexto: 'Dias reservados no mês, por máquina.',
);

Widget graficoReservasPorDia(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: reservasPorDiaDaSemana,
  titulo: 'Reservas por dia da semana · 90 dias',
  legenda: 'reservas que começam nesse dia',
  cor: const Color(0xFF4DA3FF),
  vazio: 'Ainda sem reservas.',
);

CelulaSemaforo kpiGraficoReservasDia(OperationsState s, DateTime now) =>
    _resumo(
      s,
      now,
      reservasPorDiaDaSemana,
      rotulo: 'Reservas por dia da semana',
      vazio: 'Marca reservas e vês que dias pesam mais.',
      texto: (p) => 'Dia mais forte: ${_maior(p).nome}',
      subtexto: 'Em que dias da semana começam mais reservas.',
    );

// --- Despesas --------------------------------------------------------------------

Widget graficoDespesasPorCategoria(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: despesasPorCategoria,
  titulo: 'Despesas por categoria · este mês',
  legenda: 'euros já pagos',
  cor: const Color(0xFFD9534F),
  vazio: 'Ainda sem despesas pagas este mês.',
);

CelulaSemaforo kpiGraficoDespesasCategoria(OperationsState s, DateTime now) =>
    _resumo(
      s,
      now,
      despesasPorCategoria,
      rotulo: 'Despesas por categoria',
      vazio: 'Regista despesas e vês para onde vai o dinheiro.',
      texto: (p) => 'A maior: ${_maior(p).nome}',
      subtexto: 'O que já saiu este mês, por categoria.',
    );

Widget graficoDespesaPorMes(OperationsState s, DateTime now) => _barras(
  s,
  now,
  serie: despesaPorMes,
  titulo: 'Despesa por mês · últimos 6 meses',
  legenda: 'euros pagos',
  cor: const Color(0xFFD9534F),
  vazio: 'Ainda sem despesas pagas.',
);

CelulaSemaforo kpiGraficoDespesaMes(OperationsState s, DateTime now) => _resumo(
  s,
  now,
  despesaPorMes,
  rotulo: 'Despesa por mês',
  vazio: 'Regista despesas e vês a evolução.',
  texto: (p) => 'Mais cara: ${_maior(p).nome}',
  subtexto: 'O que se gastou em cada mês.',
);
